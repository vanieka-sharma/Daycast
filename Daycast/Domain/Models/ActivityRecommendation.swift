//
//  ActivityRecommendation.swift
//  Daycast
//
//  Ranked output for one activity, including rationale and known limits.
//

import Foundation

struct ActivityRecommendation: Equatable, Hashable {
    let activity: Activity
    let score: Int?
    let confidence: Int
    let summary: String
    let limitations: [String]

    init(
        activity: Activity,
        score: Int?,
        confidence: Int,
        summary: String,
        limitations: [String] = []
    ) {
        self.activity = activity
        self.score = score.map { min(max($0, 0), 100) }
        self.confidence = min(max(confidence, 0), 100)
        self.summary = summary
        self.limitations = limitations
    }
}
