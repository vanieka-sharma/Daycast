//
//  OpenMeteoMappingTests.swift
//  DaycastTests
//
//  Tests API DTO decoding and mapping into domain models.
//

import Foundation
import Testing
@testable import Daycast

@MainActor
struct OpenMeteoMappingTests {
    @Test
    func geocodingMapsCities() async throws {
        let json = """
        {
          "results": [
            {
              "id": 1,
              "name": "Paris",
              "country": "France",
              "admin1": "Ile-de-France",
              "latitude": 48.8566,
              "longitude": 2.3522
            }
          ]
        }
        """.data(using: .utf8)!

        let client = OpenMeteoGeocodingClient(
            httpClient: MockHTTPClient(data: json, statusCode: 200)
        )

        let cities = try await client.searchCities(query: "Paris")

        #expect(cities.count == 1)
        #expect(cities[0].name == "Paris, Ile-de-France")
        #expect(cities[0].country == "France")
        #expect(cities[0].latitude == 48.8566)
        #expect(cities[0].longitude == 2.3522)
    }

    @Test
    func forecastMapsDailyWeatherUsingOpenMeteoKeys() async throws {
        let json = """
        {
          "daily": {
            "time": ["2026-10-13", "2026-10-14"],
            "temperature_2m_min": [9.0, 10.0],
            "temperature_2m_max": [17.0, 18.0],
            "precipitation_sum": [0.2, 1.0],
            "wind_speed_10m_max": [12.0, 22.0],
            "weather_code": [1, 3],
            "snowfall_sum": [0.0, 0.0]
          }
        }
        """.data(using: .utf8)!

        let client = OpenMeteoForecastClient(
            httpClient: MockHTTPClient(data: json, statusCode: 200)
        )

        let forecast = try await client.fetchDailyForecast(latitude: 48.8566, longitude: 2.3522, days: 2)

        #expect(forecast.count == 2)
        #expect(forecast[0].tempMinC == 9.0)
        #expect(forecast[0].tempMaxC == 17.0)
        #expect(forecast[0].windMaxKmh == 12.0)
        #expect(forecast[0].weatherCode == 1)
    }

    @Test
    func forecastSupportsLegacyKeyVariants() async throws {
        let json = """
        {
          "daily": {
            "time": ["2026-10-13"],
            "temperature_2m_min": [5.0],
            "temperature_2m_max": [12.0],
            "precipitation_sum": [2.0],
            "windspeed_10m_max": [30.0],
            "weathercode": [63]
          }
        }
        """.data(using: .utf8)!

        let client = OpenMeteoForecastClient(
            httpClient: MockHTTPClient(data: json, statusCode: 200)
        )

        let forecast = try await client.fetchDailyForecast(latitude: 50.0, longitude: 8.0, days: 1)

        #expect(forecast.count == 1)
        #expect(forecast[0].windMaxKmh == 30.0)
        #expect(forecast[0].weatherCode == 63)
    }
}

private struct MockHTTPClient: HTTPClient {
    let data: Data
    let statusCode: Int

    func data(from url: URL) async throws -> (Data, URLResponse) {
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, response)
    }
}
