//
//  City.swift
//  Daycast
//
//  Domain model for a user-selectable city.
//

import Foundation

struct City: Equatable, Hashable, Identifiable {
    let id: String
    let name: String
    let country: String
    let latitude: Double
    let longitude: Double

    init(id: String? = nil, name: String, country: String, latitude: Double, longitude: Double) {
        self.id = id ?? "\(name.lowercased())|\(country.lowercased())|\(latitude)|\(longitude)"
        self.name = name
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
    }
}
