//
//  AppError.swift
//  Daycast
//
//  App-level errors mapped from networking and domain conditions.
//

import Foundation

enum AppError: LocalizedError, Equatable {
    case invalidURL
    case invalidResponse(statusCode: Int)
    case decodingFailed
    case emptyQuery
    case noCitiesFound
    case noForecastData
    case networkUnavailable
    case timedOut
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Unable to create the API request URL."
        case let .invalidResponse(statusCode):
            return "The weather service returned an unexpected response (\(statusCode))."
        case .decodingFailed:
            return "Received data in an unexpected format."
        case .emptyQuery:
            return "Please enter a city name to search."
        case .noCitiesFound:
            return "No cities matched your search."
        case .noForecastData:
            return "No forecast data is available for this location right now."
        case .networkUnavailable:
            return "No internet connection. Check your network and try again."
        case .timedOut:
            return "The request timed out. Please try again."
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }

    static func from(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkUnavailable
            case .timedOut:
                return .timedOut
            default:
                return .unknown
            }
        }

        return .unknown
    }
}
