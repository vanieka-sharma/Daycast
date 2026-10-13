//
//  ContentView.swift
//  Daycast
//
//  Created by Vanieka Sharma on 10/10/26.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel: SearchViewModel

    init(viewModel: SearchViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        SearchView(viewModel: viewModel)
    }
}

#Preview {
    ContentView(viewModel: SearchViewModel(recommendationService: PreviewRecommendationService()))
}

private struct PreviewRecommendationService: RecommendationServiceProtocol {
    func searchCities(query: String) async throws -> [City] {
        [City(name: "Paris", country: "France", latitude: 48.8566, longitude: 2.3522)]
    }

    func recommendations(for city: City) async throws -> [ActivityRecommendation] {
        [
            ActivityRecommendation(
                activity: .outdoorSightseeing,
                score: 78,
                confidence: 90,
                summary: "Mild temperatures and generally dry conditions favor outdoor sightseeing this week."
            ),
            ActivityRecommendation(
                activity: .indoorSightseeing,
                score: 42,
                confidence: 88,
                summary: "Indoor sightseeing is a reasonable option for part of the week."
            ),
            ActivityRecommendation(
                activity: .surfing,
                score: 30,
                confidence: 40,
                summary: "Surfing suitability appears limited, and confidence is low without marine-condition data.",
                limitations: ["No marine swell, tide, or current data is available for surfing quality."]
            ),
            ActivityRecommendation(
                activity: .skiing,
                score: 20,
                confidence: 65,
                summary: "Skiing conditions look limited from available weather signals this week."
            )
        ]
    }
}
