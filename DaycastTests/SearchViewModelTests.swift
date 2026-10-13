//
//  SearchViewModelTests.swift
//  DaycastTests
//
//  Focused tests for search and state transitions.
//

import Foundation
import Testing
@testable import Daycast

@MainActor
struct SearchViewModelTests {
    @Test
    func emptyQueryShowsEmptyState() async {
        let service = MockRecommendationService()
        let viewModel = SearchViewModel(recommendationService: service)

        viewModel.searchText = "   "
        await viewModel.searchCities()

        guard case let .empty(message) = viewModel.state else {
            Issue.record("Expected empty state for blank query")
            return
        }
        #expect(message.contains("enter a city") || message.contains("Enter a city"))
    }

    @Test
    func successfulSearchShowsCityResults() async {
        let service = MockRecommendationService()
        let city = City(name: "Berlin", country: "Germany", latitude: 52.52, longitude: 13.4)
        service.searchResult = .success([city])

        let viewModel = SearchViewModel(recommendationService: service)
        viewModel.searchText = "Berlin"

        await viewModel.searchCities()

        guard case let .cityResults(cities) = viewModel.state else {
            Issue.record("Expected city results state")
            return
        }
        #expect(cities == [city])
    }

    @Test
    func failedSearchShowsErrorThenRetrySucceeds() async {
        let service = MockRecommendationService()
        let city = City(name: "Tokyo", country: "Japan", latitude: 35.6762, longitude: 139.6503)
        service.searchResult = .failure(AppError.networkUnavailable)

        let viewModel = SearchViewModel(recommendationService: service)
        viewModel.searchText = "Tokyo"

        await viewModel.searchCities()

        guard case .error = viewModel.state else {
            Issue.record("Expected error state after failed search")
            return
        }

        service.searchResult = .success([city])
        await viewModel.retry()

        guard case let .cityResults(cities) = viewModel.state else {
            Issue.record("Expected city results after retry")
            return
        }
        #expect(cities == [city])
    }

    @Test
    func selectingCityLoadsRecommendations() async {
        let service = MockRecommendationService()
        let city = City(name: "Lisbon", country: "Portugal", latitude: 38.7223, longitude: -9.1393)
        service.recommendationResult = .success([
            ActivityRecommendation(
                activity: .outdoorSightseeing,
                score: 70,
                confidence: 80,
                summary: "Good weather for walking."
            )
        ])

        let viewModel = SearchViewModel(recommendationService: service)

        await viewModel.selectCity(city)

        guard case let .loaded(loadedCity, recommendations) = viewModel.state else {
            Issue.record("Expected loaded state")
            return
        }
        #expect(loadedCity == city)
        #expect(recommendations.count == 1)
        #expect(recommendations[0].activity == .outdoorSightseeing)
    }
}

@MainActor
private final class MockRecommendationService: RecommendationServiceProtocol {
    var searchResult: Result<[City], Error> = .success([])
    var recommendationResult: Result<[ActivityRecommendation], Error> = .success([])

    func searchCities(query: String) async throws -> [City] {
        try searchResult.get()
    }

    func recommendations(for city: City) async throws -> [ActivityRecommendation] {
        try recommendationResult.get()
    }
}
