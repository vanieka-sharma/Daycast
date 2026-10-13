//
//  ActivityRankingServiceTests.swift
//  DaycastTests
//
//  Focused tests for deterministic ranking behavior and missing-data handling.
//

import Foundation
import Testing
@testable import Daycast

@MainActor
struct ActivityRankingServiceTests {
    private let service: ActivityRankingServiceProtocol = ActivityRankingService()

    @Test
    func pleasantWeekRanksOutdoorAboveIndoor() {
        let forecast = makeForecast(
            days: 7,
            tempMin: 16,
            tempMax: 24,
            precipitation: 0.2,
            wind: 10,
            weatherCode: 1,
            snowfall: 0
        )

        let recommendations = service.rankActivities(from: forecast)
        let outdoor = recommendation(for: .outdoorSightseeing, in: recommendations)
        let indoor = recommendation(for: .indoorSightseeing, in: recommendations)

        #expect(outdoor.score != nil)
        #expect(indoor.score != nil)
        #expect((outdoor.score ?? 0) > (indoor.score ?? 0))
        #expect(!outdoor.summary.isEmpty)
    }

    @Test
    func rainyWeekRanksIndoorAboveOutdoor() {
        let forecast = makeForecast(
            days: 7,
            tempMin: 9,
            tempMax: 13,
            precipitation: 18,
            wind: 40,
            weatherCode: 82,
            snowfall: 0
        )

        let recommendations = service.rankActivities(from: forecast)
        let outdoor = recommendation(for: .outdoorSightseeing, in: recommendations)
        let indoor = recommendation(for: .indoorSightseeing, in: recommendations)

        #expect((indoor.score ?? 0) > (outdoor.score ?? 0))
    }

    @Test
    func scoresAndConfidenceStayWithinBounds() {
        let forecast = makeForecast(
            days: 7,
            tempMin: -20,
            tempMax: 42,
            precipitation: 35,
            wind: 90,
            weatherCode: 99,
            snowfall: 15
        )

        let recommendations = service.rankActivities(from: forecast)

        for recommendation in recommendations {
            if let score = recommendation.score {
                #expect(score >= 0)
                #expect(score <= 100)
            }
            #expect(recommendation.confidence >= 0)
            #expect(recommendation.confidence <= 100)
        }
    }

    @Test
    func missingDataDoesNotProduceSilentPositiveScore() {
        let forecast = [
            DailyForecast(
                date: Date(),
                tempMinC: nil,
                tempMaxC: nil,
                precipitationMm: nil,
                windMaxKmh: nil,
                weatherCode: nil,
                snowfallCm: nil
            )
        ]

        let recommendations = service.rankActivities(from: forecast)

        #expect(recommendations.count == Activity.allCases.count)
        #expect(recommendations.allSatisfy { $0.score == nil })
        #expect(recommendations.allSatisfy { $0.summary.contains("Not enough forecast inputs") })
    }

    @Test
    func skiingUsesProxyWhenSnowfallIsMissing() {
        let forecast = makeForecast(
            days: 7,
            tempMin: -4,
            tempMax: 0,
            precipitation: 6,
            wind: 20,
            weatherCode: 71,
            snowfall: nil
        )

        let recommendations = service.rankActivities(from: forecast)
        let skiing = recommendation(for: .skiing, in: recommendations)

        #expect(skiing.score != nil)
        #expect(skiing.limitations.joined(separator: " ").localizedCaseInsensitiveContains("no snowfall data"))
    }

    @Test
    func surfingConfidenceIsCappedAndIncludesMarineLimitation() {
        let forecast = makeForecast(
            days: 7,
            tempMin: 20,
            tempMax: 27,
            precipitation: 1,
            wind: 18,
            weatherCode: 1,
            snowfall: 0
        )

        let recommendations = service.rankActivities(from: forecast)
        let surfing = recommendation(for: .surfing, in: recommendations)

        #expect(surfing.score != nil)
        #expect(surfing.confidence <= 45)
        #expect(surfing.limitations.joined(separator: " ").localizedCaseInsensitiveContains("marine"))
    }

    private func recommendation(for activity: Activity, in recommendations: [ActivityRecommendation]) -> ActivityRecommendation {
        recommendations.first(where: { $0.activity == activity })!
    }

    private func makeForecast(
        days: Int,
        tempMin: Double?,
        tempMax: Double?,
        precipitation: Double?,
        wind: Double?,
        weatherCode: Int?,
        snowfall: Double?
    ) -> [DailyForecast] {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.startOfDay(for: Date())

        return (0..<days).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            return DailyForecast(
                date: date,
                tempMinC: tempMin,
                tempMaxC: tempMax,
                precipitationMm: precipitation,
                windMaxKmh: wind,
                weatherCode: weatherCode,
                snowfallCm: snowfall
            )
        }
    }
}
