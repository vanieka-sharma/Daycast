//
//  OpenMeteoGeocodingClient.swift
//  Daycast
//
//  Geocoding API client for city search.
//

import Foundation

protocol GeocodingClient {
    func searchCities(query: String) async throws -> [City]
}

struct OpenMeteoGeocodingClient: GeocodingClient {
    private let httpClient: HTTPClient
    private let decoder: JSONDecoder

    init(httpClient: HTTPClient, decoder: JSONDecoder = JSONDecoder()) {
        self.httpClient = httpClient
        self.decoder = decoder
    }

    func searchCities(query: String) async throws -> [City] {
        guard var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search") else {
            throw AppError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: "8"),
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "format", value: "json")
        ]

        guard let url = components.url else {
            throw AppError.invalidURL
        }

        let (data, response) = try await httpClient.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.invalidResponse(statusCode: -1)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw AppError.invalidResponse(statusCode: httpResponse.statusCode)
        }

        let decoded: GeocodingResponse
        do {
            decoded = try decoder.decode(GeocodingResponse.self, from: data)
        } catch {
            throw AppError.decodingFailed
        }

        let results = decoded.results ?? []

        return results.map { item in
            let cityName: String
            if let admin1 = item.admin1, !admin1.isEmpty {
                cityName = "\(item.name), \(admin1)"
            } else {
                cityName = item.name
            }

            return City(
                id: item.id.map(String.init),
                name: cityName,
                country: item.country,
                latitude: item.latitude,
                longitude: item.longitude
            )
        }
    }
}

private struct GeocodingResponse: Decodable {
    let results: [GeocodingResult]?
}

private struct GeocodingResult: Decodable {
    let id: Int?
    let name: String
    let country: String
    let admin1: String?
    let latitude: Double
    let longitude: Double
}
