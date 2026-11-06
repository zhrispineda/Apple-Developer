//
//  ContentItem+Formatting.swift
//  Developer
//

import Foundation

nonisolated func formattedClockDuration(_ seconds: Double) -> String {
    let total = Int(seconds.rounded())
    let (hours, minutes, secs) = (total / 3600, (total % 3600) / 60, total % 60)
    return hours > 0
        ? String(format: "%d:%02d:%02d", hours, minutes, secs)
        : String(format: "%d:%02d", minutes, secs)
}

nonisolated func formattedTimestamp(_ seconds: Double) -> String {
    let total = Int(seconds)
    let (hours, minutes, secs) = (total / 3600, (total % 3600) / 60, total % 60)
    return hours > 0
        ? String(format: "%d:%02d:%02d", hours, minutes, secs)
        : String(format: "%02d:%02d", minutes, secs)
}

nonisolated func formattedMinutes(_ seconds: Double) -> String {
    let minutes = max(Int((seconds / 60).rounded()), 1)
    return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
}
