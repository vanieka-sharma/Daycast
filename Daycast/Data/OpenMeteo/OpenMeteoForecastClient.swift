//
//  OpenMeteoForecastClient.swift
//  Daycast
//
//  Forecast API client and DTO mapping to domain weather inputs.
//

import Foundation

protocol ForecastClient {
    func fetchDailyForecast(latitude: Double, longitude: Double, days: Int) async throws -> [DailyForecast]
}

struct OpenMeteoForecastClient: ForecastClient {
    private let httpClient: HTTPClient
    private let decoder: JSONDecoder

    init(httpClient: HTTPClient, decoder: JSONDecoder = JSONDecoder()) {
        self.httpClient = httpClient
        self.decoder = decoder
    }

    func fetchDailyForecast(latitude: Double, longitude: Double, days: Int = 7) async throws -> [DailyForecast] {
        guard var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast") else {
            throw AppError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(
                name: "daily",
                value: "temperature_2m_max,temperature_2m_min,precipitation_sum,wind_speed_10m_max,weather_code,snowfall_sum"
            ),
            URLQueryItem(name: "forecast_days", value: String(days)),
            URLQueryItem(name: "timezone", value: "auto")
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

        let decoded: ForecastResponse
        do {
            decoded = try decoder.decode(ForecastResponse.self, from: data)
        } catch {
            throw AppError.decodingFailed
        }

        return try decoded.daily.toDomain()
    }
}

private struct ForecastResponse: Decodable {
    let daily: DailyDTO
}

private struct DailyDTO: Decodable {
    let time: [String]
    let temperature2mMax: [Double?]?
    let temperature2mMin: [Double?]?
    let precipitationSum: [Double?]?
    let windSpeed10mMax: [Double?]?
    let weatherCode: [Int?]?
    let snowfallSum: [Double?]?

    enum CodingKeys: String, CodingKey {
        case time
        case temperature2mMax = "temperature_2m_max"
        case temperature2mMin = "temperature_2m_min"
        case precipitationSum = "precipitation_sum"
        case windSpeed10mMax = "wind_speed_10m_max"
        case windspeed10mMax = "windspeed_10m_max"
        case weatherCode = "weather_code"
        case weathercode
        case snowfallSum = "snowfall_sum"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        time = try container.decode([String].self, forKey: .time)
        temperature2mMax = try container.decodeIfPresent([Double?].self, forKey: .temperature2mMax)
        temperature2mMin = try container.decodeIfPresent([Double?].self, forKey: .temperature2mMin)
        precipitationSum = try container.decodeIfPresent([Double?].self, forKey: .precipitationSum)
        snowfallSum = try container.decodeIfPresent([Double?].self, forKey: .snowfallSum)

        if let wind = try container.decodeIfPresent([Double?].self, forKey: .windSpeed10mMax) {
            windSpeed10mMax = wind
        } else {
            windSpeed10mMax = try container.decodeIfPresent([Double?].self, forKey: .windspeed10mMax)
        }

        if let codes = try container.decodeIfPresent([Int?].self, forKey: .weatherCode) {
            weatherCode = codes
        } else {
            weatherCode = try container.decodeIfPresent([Int?].self, forKey: .weathercode)
        }
    }

    func toDomain() throws -> [DailyForecast] {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"

        return try time.enumerated().map { index, dateString in
            guard let date = formatter.date(from: dateString) else {
                throw AppError.decodingFailed
            }

            return DailyForecast(
                date: date,
                tempMinC: value(at: index, in: temperature2mMin),
                tempMaxC: value(at: index, in: temperature2mMax),
                precipitationMm: value(at: index, in: precipitationSum),
                windMaxKmh: value(at: index, in: windSpeed10mMax),
                weatherCode: value(at: index, in: weatherCode),
                snowfallCm: value(at: index, in: snowfallSum)
            )
        }
    }

    private func value<T>(at index: Int, in array: [T?]?) -> T? {
        guard let array, array.indices.contains(index) else { return nil }
        return array[index]
    }
}
