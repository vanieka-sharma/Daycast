//
//  HTTPClient.swift
//  Daycast
//
//  Small protocol to keep API clients mockable in tests.
//

import Foundation

protocol HTTPClient {
    func data(from url: URL) async throws -> (Data, URLResponse)
}

struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func data(from url: URL) async throws -> (Data, URLResponse) {
        try await session.data(from: url)
    }
}
