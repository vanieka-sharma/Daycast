//
//  SearchViewModel.swift
//  Daycast
//
//  Screen state and actions for city search and ranked recommendations.
//

import Foundation
import Observation

@MainActor
@Observable
final class SearchViewModel {
    enum State: Equatable {
        case idle
        case searchingCities
        case cityResults([City])
        case loadingRecommendations(City)
        case loaded(city: City, recommendations: [ActivityRecommendation])
        case empty(message: String)
        case error(message: String)
    }

    var searchText: String = ""
    private(set) var state: State = .idle

    private let recommendationService: RecommendationServiceProtocol
    private var retryAction: RetryAction?

    private enum RetryAction {
        case search(query: String)
        case load(city: City)
    }

    init(recommendationService: RecommendationServiceProtocol) {
        self.recommendationService = recommendationService
    }

    func searchCities() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            retryAction = nil
            state = .empty(message: AppError.emptyQuery.localizedDescription)
            return
        }

        state = .searchingCities
        retryAction = .search(query: query)

        do {
            let cities = try await recommendationService.searchCities(query: query)
            state = .cityResults(cities)
        } catch {
            let appError = AppError.from(error)
            if appError == .noCitiesFound {
                state = .empty(message: appError.localizedDescription)
            } else {
                state = .error(message: appError.localizedDescription)
            }
        }
    }

    func selectCity(_ city: City) async {
        state = .loadingRecommendations(city)
        retryAction = .load(city: city)

        do {
            let recommendations = try await recommendationService.recommendations(for: city)
            state = .loaded(city: city, recommendations: recommendations)
        } catch {
            state = .error(message: AppError.from(error).localizedDescription)
        }
    }

    func retry() async {
        guard let retryAction else { return }

        switch retryAction {
        case let .search(query):
            searchText = query
            await searchCities()
        case let .load(city):
            await selectCity(city)
        }
    }

    func clearSearch() {
        searchText = ""
        retryAction = nil
        state = .idle
    }
}
