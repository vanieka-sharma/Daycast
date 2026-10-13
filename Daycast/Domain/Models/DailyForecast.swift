//
//  DailyForecast.swift
//  Daycast
//
//  API-agnostic daily weather inputs used by the ranking engine.
//

import Foundation

struct DailyForecast: Equatable, Hashable {
    let date: Date
    let tempMinC: Double?
    let tempMaxC: Double?
    let precipitationMm: Double?
    let windMaxKmh: Double?
    let weatherCode: Int?
    let snowfallCm: Double?

    init(
        date: Date,
        tempMinC: Double?,
        tempMaxC: Double?,
        precipitationMm: Double?,
        windMaxKmh: Double?,
        weatherCode: Int?,
        snowfallCm: Double?
    ) {
        self.date = date
        self.tempMinC = tempMinC
        self.tempMaxC = tempMaxC
        self.precipitationMm = precipitationMm
        self.windMaxKmh = windMaxKmh
        self.weatherCode = weatherCode
        self.snowfallCm = snowfallCm
    }
}
