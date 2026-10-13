//
//  Activity.swift
//  Daycast
//
//  Domain activities that can be ranked from weather suitability.
//

import Foundation

enum Activity: String, CaseIterable, Hashable {
    case skiing
    case surfing
    case outdoorSightseeing
    case indoorSightseeing

    var displayName: String {
        switch self {
        case .skiing:
            return "Skiing"
        case .surfing:
            return "Surfing"
        case .outdoorSightseeing:
            return "Outdoor sightseeing"
        case .indoorSightseeing:
            return "Indoor sightseeing"
        }
    }
}
