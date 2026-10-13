//
//  SearchView.swift
//  Daycast
//
//  Main UI for city search and activity recommendations.
//

import SwiftUI

struct SearchView: View {
    @Bindable var viewModel: SearchViewModel
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                searchBar
                content
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .contentShape(Rectangle())
            .onTapGesture {
                isSearchFieldFocused = false
            }
            .navigationTitle("Daycast")
        }
    }
}

private extension SearchView {
    var searchBar: some View {
        HStack(spacing: 8) {
            ZStack(alignment: .trailing) {
                TextField("Search a city", text: $viewModel.searchText)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .focused($isSearchFieldFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        runSearch()
                    }

                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.clearSearch()
                        isSearchFieldFocused = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.trailing, 10)
                }
            }

            Button("Search") {
                runSearch()
            }
            .buttonStyle(.borderedProminent)
        }

    }

    @ViewBuilder
    var content: some View {
        switch viewModel.state {
        case .idle:
            centeredStatus {
                ContentUnavailableView(
                    "Search for a city",
                    systemImage: "magnifyingglass",
                    description: Text("Plan your week with weather-smart activity recommendations.")
                )
            }

        case .searchingCities:
            centeredStatus {
                progressSection(title: "Searching cities...")
            }

        case let .cityResults(cities):
            cityResultsSection(cities)

        case let .loadingRecommendations(city):
            centeredStatus {
                progressSection(title: "Loading recommendations for \(city.name)...")
            }

        case let .loaded(city, recommendations):
            recommendationsSection(city: city, recommendations: recommendations)

        case let .empty(message):
            centeredStatus {
                ContentUnavailableView("No Results", systemImage: "tray", description: Text(message))
            }

        case let .error(message):
            centeredStatus {
                VStack(spacing: 12) {
                    ContentUnavailableView(
                        "Something went wrong",
                        systemImage: "exclamationmark.triangle",
                        description: Text(message)
                    )
                    Button("Retry") {
                        Task { await viewModel.retry() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    func centeredStatus<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack {
            Spacer(minLength: 12)
            content()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    func progressSection(title: String) -> some View {
        HStack(spacing: 12) {
            ProgressView()
            Text(title)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    func cityResultsSection(_ cities: [City]) -> some View {
        List(cities) { city in
            Button {
                isSearchFieldFocused = false
                Task { await viewModel.selectCity(city) }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(city.name)
                        .font(.headline)
                    Text(city.country)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
        .scrollDismissesKeyboard(.immediately)
    }

    func recommendationsSection(city: City, recommendations: [ActivityRecommendation]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Recommendations for \(city.name), \(city.country)")
                    .font(.headline)

                Text("Ranked forecast suitability for the next 7 days")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ForEach(recommendations, id: \.activity) { recommendation in
                    recommendationCard(recommendation)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    func recommendationCard(_ recommendation: ActivityRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(recommendation.activity.displayName)
                    .font(.headline)

                Spacer()

                Text(scoreLabel(for: recommendation.score))
                    .font(.subheadline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.secondary.opacity(0.15), in: Capsule())
            }

            Text("Confidence: \(recommendation.confidence)%")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(recommendation.summary)
                .font(.body)

            if !recommendation.limitations.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Limitations")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(recommendation.limitations, id: \.self) { limitation in
                        Text("- \(limitation)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    func scoreLabel(for score: Int?) -> String {
        guard let score else { return "N/A" }
        return "\(score)/100"
    }

    func runSearch() {
        isSearchFieldFocused = false
        Task { await viewModel.searchCities() }
    }
}
