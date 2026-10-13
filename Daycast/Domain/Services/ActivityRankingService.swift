//
//  ActivityRankingService.swift
//  Daycast
//
//  Contract for transforming daily forecasts into ranked activities.
//

import Foundation

protocol ActivityRankingServiceProtocol {
    /// Returns one recommendation per supported activity.
    ///
    /// - Parameter forecast: A 7-day (or shorter) set of daily weather inputs.
    /// - Returns: Ranked recommendations sorted by descending suitability.
    func rankActivities(from forecast: [DailyForecast]) -> [ActivityRecommendation]
}

struct ActivityRankingService: ActivityRankingServiceProtocol {
    func rankActivities(from forecast: [DailyForecast]) -> [ActivityRecommendation] {
        let recommendations = Activity.allCases.map { activity in
            buildRecommendation(for: activity, forecast: forecast)
        }

        return recommendations.sorted(by: recommendationSort)
    }
}

private extension ActivityRankingService {
    struct DayScore {
        let value: Int
        let confidencePenalty: Int
        let limitations: [String]
    }

    enum DayEvaluation {
        case scored(DayScore)
        case unscored(reason: String)
    }

    func buildRecommendation(for activity: Activity, forecast: [DailyForecast]) -> ActivityRecommendation {
        let evaluations = forecast.map { scoreDay(activity: activity, day: $0) }
        let scored = evaluations.compactMap { evaluation -> DayScore? in
            if case let .scored(dayScore) = evaluation {
                return dayScore
            }
            return nil
        }
        let unscoredReasons = evaluations.compactMap { evaluation -> String? in
            if case let .unscored(reason) = evaluation {
                return reason
            }
            return nil
        }

        guard !scored.isEmpty else {
            let fallbackLimitations = uniqueStrings(
                unscoredReasons.isEmpty ? ["No forecast days available."] : unscoredReasons
            )
            return ActivityRecommendation(
                activity: activity,
                score: nil,
                confidence: 0,
                summary: "Not enough forecast inputs to score this activity reliably.",
                limitations: fallbackLimitations
            )
        }

        let weeklyScore = average(scored.map(\.value))
        let confidence = computeConfidence(
            activity: activity,
            scored: scored,
            scoredDayCount: scored.count,
            totalDayCount: forecast.count
        )

        var limitations = scored.flatMap(\.limitations)
        if !unscoredReasons.isEmpty {
            limitations.append("Some days were excluded due to missing required weather inputs.")
            limitations.append(contentsOf: unscoredReasons)
        }

        return ActivityRecommendation(
            activity: activity,
            score: weeklyScore,
            confidence: confidence,
            summary: buildSummary(activity: activity, score: weeklyScore, limitations: limitations),
            limitations: uniqueStrings(limitations)
        )
    }

    func scoreDay(activity: Activity, day: DailyForecast) -> DayEvaluation {
        switch activity {
        case .skiing:
            return scoreSkiing(day)
        case .surfing:
            return scoreSurfing(day)
        case .outdoorSightseeing:
            return scoreOutdoor(day)
        case .indoorSightseeing:
            return scoreIndoor(day)
        }
    }

    func scoreOutdoor(_ day: DailyForecast) -> DayEvaluation {
        guard
            let meanTemp = meanTemperature(for: day),
            let precipitation = day.precipitationMm,
            let wind = day.windMaxKmh
        else {
            return .unscored(reason: "Outdoor sightseeing needs temperature, precipitation, and wind data.")
        }

        let tempScore = bandScore(value: meanTemp, idealMin: 15, idealMax: 26, tolerance: 12)
        let rainPenalty = linearPenalty(value: precipitation, start: 1, end: 15)
        let windPenalty = linearPenalty(value: wind, start: 15, end: 45)
        let severePenalty = weatherSeverityScore(code: day.weatherCode)

        let total =
            (0.40 * tempScore) +
            (0.30 * (100 - rainPenalty)) +
            (0.20 * (100 - windPenalty)) +
            (0.10 * (100 - severePenalty))

        var limitations: [String] = []
        var confidencePenalty = 0
        if day.weatherCode == nil {
            confidencePenalty += 5
            limitations.append("Weather code is missing, so severe-weather impact is estimated.")
        }

        return .scored(
            DayScore(
                value: clampScore(total),
                confidencePenalty: confidencePenalty,
                limitations: limitations
            )
        )
    }

    func scoreIndoor(_ day: DailyForecast) -> DayEvaluation {
        guard
            let meanTemp = meanTemperature(for: day),
            let precipitation = day.precipitationMm
        else {
            return .unscored(reason: "Indoor sightseeing needs temperature and precipitation data.")
        }

        let rainBoost = linearBoost(value: precipitation, start: 0.5, end: 12)
        let comfort = bandScore(value: meanTemp, idealMin: 15, idealMax: 24, tolerance: 12)
        let tempDiscomfortBoost = 100 - comfort
        let windBoost = day.windMaxKmh.map { linearBoost(value: $0, start: 15, end: 45) } ?? 50
        let severeBoost = weatherSeverityScore(code: day.weatherCode)

        let total =
            (0.35 * rainBoost) +
            (0.30 * tempDiscomfortBoost) +
            (0.20 * windBoost) +
            (0.15 * severeBoost)

        var limitations: [String] = []
        var confidencePenalty = 0
        if day.windMaxKmh == nil {
            confidencePenalty += 10
            limitations.append("Wind data is missing, so indoor comfort uses a neutral wind estimate.")
        }
        if day.weatherCode == nil {
            confidencePenalty += 5
            limitations.append("Weather code is missing, so severe-weather impact is estimated.")
        }

        return .scored(
            DayScore(
                value: clampScore(total),
                confidencePenalty: confidencePenalty,
                limitations: limitations
            )
        )
    }

    func scoreSkiing(_ day: DailyForecast) -> DayEvaluation {
        guard let meanTemp = meanTemperature(for: day) else {
            return .unscored(reason: "Skiing needs temperature data.")
        }

        guard day.snowfallCm != nil || day.precipitationMm != nil else {
            return .unscored(reason: "Skiing needs snowfall or precipitation data.")
        }

        let coldScore = bandScore(value: meanTemp, idealMin: -8, idealMax: -1, tolerance: 12)
        let windPenalty = day.windMaxKmh.map { linearPenalty(value: $0, start: 20, end: 60) } ?? 30

        var snowSignal = 0.0
        var confidencePenalty = 0
        var limitations: [String] = []

        if let snowfall = day.snowfallCm {
            snowSignal = linearBoost(value: snowfall, start: 0.2, end: 8)
        } else if let precipitation = day.precipitationMm {
            // Proxy: cold + wet suggests possible snowfall but is less reliable than direct snowfall data.
            let coldPrecipBonus = meanTemp <= 0 ? 100.0 : max(0, 100 - (meanTemp * 20))
            let precipBoost = linearBoost(value: precipitation, start: 0.5, end: 10)
            snowSignal = 0.55 * coldPrecipBonus + 0.45 * precipBoost
            confidencePenalty += 25
            limitations.append("No snowfall data; skiing uses a temperature and precipitation proxy.")
        }

        let total =
            (0.45 * coldScore) +
            (0.35 * snowSignal) +
            (0.20 * (100 - windPenalty))

        if day.windMaxKmh == nil {
            confidencePenalty += 10
            limitations.append("Wind data is missing, so skiing wind impact is estimated.")
        }

        return .scored(
            DayScore(
                value: clampScore(total),
                confidencePenalty: confidencePenalty,
                limitations: limitations
            )
        )
    }

    func scoreSurfing(_ day: DailyForecast) -> DayEvaluation {
        guard
            let meanTemp = meanTemperature(for: day),
            let precipitation = day.precipitationMm,
            let wind = day.windMaxKmh
        else {
            return .unscored(reason: "Surfing needs temperature, precipitation, and wind data.")
        }

        let windSuitability = bandScore(value: wind, idealMin: 12, idealMax: 30, tolerance: 18)
        let tempComfort = bandScore(value: meanTemp, idealMin: 18, idealMax: 28, tolerance: 14)
        let rainPenalty = linearPenalty(value: precipitation, start: 1, end: 15)
        let severePenalty = weatherSeverityScore(code: day.weatherCode)

        let total =
            (0.40 * windSuitability) +
            (0.25 * tempComfort) +
            (0.20 * (100 - rainPenalty)) +
            (0.15 * (100 - severePenalty))

        var limitations = ["No marine swell, tide, or current data is available for surfing quality."]
        var confidencePenalty = 35
        if day.weatherCode == nil {
            confidencePenalty += 5
            limitations.append("Weather code is missing, so severe-weather impact is estimated.")
        }

        return .scored(
            DayScore(
                value: clampScore(total),
                confidencePenalty: confidencePenalty,
                limitations: limitations
            )
        )
    }

    func computeConfidence(
        activity: Activity,
        scored: [DayScore],
        scoredDayCount: Int,
        totalDayCount: Int
    ) -> Int {
        guard scoredDayCount > 0, totalDayCount > 0 else { return 0 }

        let averagePenalty = Double(scored.map(\.confidencePenalty).reduce(0, +)) / Double(scoredDayCount)
        let coverageFactor = Double(scoredDayCount) / Double(totalDayCount)
        var confidence = (100 - averagePenalty) * coverageFactor

        if activity == .surfing {
            confidence = min(confidence, 45)
        }

        return clampScore(confidence)
    }

    func buildSummary(activity: Activity, score: Int, limitations: [String]) -> String {
        switch activity {
        case .outdoorSightseeing:
            if score >= 70 {
                return "Mild temperatures and generally dry conditions favor outdoor sightseeing this week."
            }
            if score >= 40 {
                return "Weather is mixed, so outdoor sightseeing is suitable on only some days."
            }
            return "Rain, wind, or uncomfortable temperatures reduce outdoor sightseeing suitability."

        case .indoorSightseeing:
            if score >= 70 {
                return "Frequent rain or less comfortable outdoor weather makes indoor sightseeing a strong option."
            }
            if score >= 40 {
                return "Indoor sightseeing is a reasonable option for part of the week."
            }
            return "Weather is often pleasant outside, so indoor sightseeing is less preferred this week."

        case .skiing:
            if limitations.joined(separator: " ").localizedCaseInsensitiveContains("no snowfall data") {
                return "Cold and wet conditions support skiing potential, but snowfall is inferred from proxy data."
            }
            if score >= 70 {
                return "Cold temperatures and snowfall signals make skiing favorable this week."
            }
            return "Skiing conditions look limited from available weather signals this week."

        case .surfing:
            if score >= 60 {
                return "Wind and weather look fairly suitable, but surfing confidence is limited without marine data."
            }
            return "Surfing suitability appears limited, and confidence is low without marine-condition data."
        }
    }

    func average(_ values: [Int]) -> Int {
        guard !values.isEmpty else { return 0 }
        let total = values.reduce(0, +)
        return clampScore(Double(total) / Double(values.count))
    }

    func meanTemperature(for day: DailyForecast) -> Double? {
        switch (day.tempMinC, day.tempMaxC) {
        case let (min?, max?):
            return (min + max) / 2
        case let (min?, nil):
            return min
        case let (nil, max?):
            return max
        case (nil, nil):
            return nil
        }
    }

    func bandScore(value: Double, idealMin: Double, idealMax: Double, tolerance: Double) -> Double {
        if value >= idealMin && value <= idealMax {
            return 100
        }

        if value < idealMin {
            return max(0, 100 - ((idealMin - value) / tolerance) * 100)
        }

        return max(0, 100 - ((value - idealMax) / tolerance) * 100)
    }

    func linearPenalty(value: Double, start: Double, end: Double) -> Double {
        guard end > start else { return value > start ? 100 : 0 }
        if value <= start { return 0 }
        if value >= end { return 100 }
        return ((value - start) / (end - start)) * 100
    }

    func linearBoost(value: Double, start: Double, end: Double) -> Double {
        guard end > start else { return value >= end ? 100 : 0 }
        if value <= start { return 0 }
        if value >= end { return 100 }
        return ((value - start) / (end - start)) * 100
    }

    func weatherSeverityScore(code: Int?) -> Double {
        guard let code else { return 35 }

        switch code {
        case 0 ... 2: return 0
        case 3: return 10
        case 45, 48: return 25
        case 51, 53, 55: return 30
        case 56, 57: return 45
        case 61: return 40
        case 63: return 55
        case 65: return 70
        case 66, 67: return 75
        case 71: return 50
        case 73: return 65
        case 75: return 80
        case 77: return 55
        case 80: return 55
        case 81: return 70
        case 82: return 85
        case 85: return 70
        case 86: return 85
        case 95: return 90
        case 96, 99: return 100
        default: return 35
        }
    }

    func clampScore(_ value: Double) -> Int {
        min(max(Int(value.rounded()), 0), 100)
    }

    func uniqueStrings(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var unique: [String] = []
        for value in values where !seen.contains(value) {
            seen.insert(value)
            unique.append(value)
        }
        return unique
    }

    func recommendationSort(lhs: ActivityRecommendation, rhs: ActivityRecommendation) -> Bool {
        switch (lhs.score, rhs.score) {
        case let (left?, right?):
            if left != right { return left > right }
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            break
        }

        if lhs.confidence != rhs.confidence {
            return lhs.confidence > rhs.confidence
        }

        return lhs.activity.rawValue < rhs.activity.rawValue
    }
}
