//
//  RecommendationService.swift
//  Daycast
//
//  Orchestrates city search, forecast fetch, and activity ranking.
//

import Foundation

protocol RecommendationServiceProtocol {
    func searchCities(query: String) async throws -> [City]
    func recommendations(for city: City) async throws -> [ActivityRecommendation]
}

struct RecommendationService: RecommendationServiceProtocol {
    private let geocodingClient: GeocodingClient
    private let forecastClient: ForecastClient
    private let rankingService: ActivityRankingServiceProtocol

    init(
        geocodingClient: GeocodingClient,
        forecastClient: ForecastClient,
        rankingService: ActivityRankingServiceProtocol
    ) {
        self.geocodingClient = geocodingClient
        self.forecastClient = forecastClient
        self.rankingService = rankingService
    }

    func searchCities(query: String) async throws -> [City] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AppError.emptyQuery
        }

        let cities = try await geocodingClient.searchCities(query: trimmed)
        guard !cities.isEmpty else {
            throw AppError.noCitiesFound
        }

        return cities
    }

    func recommendations(for city: City) async throws -> [ActivityRecommendation] {
        let forecast = try await forecastClient.fetchDailyForecast(
            latitude: city.latitude,
            longitude: city.longitude,
            days: 7
        )

        guard !forecast.isEmpty else {
            throw AppError.noForecastData
        }

        return rankingService.rankActivities(from: forecast)
    }
}
