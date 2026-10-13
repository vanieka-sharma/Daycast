//
//  DaycastApp.swift
//  Daycast
//
//  Created by Vanieka Sharma on 10/10/26.
//

import SwiftUI

@main
struct DaycastApp: App {
    private let searchViewModel: SearchViewModel

    init() {
        let httpClient = URLSessionHTTPClient()
        let geocodingClient = OpenMeteoGeocodingClient(httpClient: httpClient)
        let forecastClient = OpenMeteoForecastClient(httpClient: httpClient)
        let rankingService = ActivityRankingService()
        let recommendationService = RecommendationService(
            geocodingClient: geocodingClient,
            forecastClient: forecastClient,
            rankingService: rankingService
        )

        self.searchViewModel = SearchViewModel(recommendationService: recommendationService)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: searchViewModel)
        }
    }
}
