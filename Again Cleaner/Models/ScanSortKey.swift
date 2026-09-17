//
//  ScanSortKey.swift
//  Again Cleaner
//
//  Shared sort key for scan-result lists (Smart Scan, Deep Disk Scan, Large
//  Files). Size defaults to largest-first, name/date to the natural reading
//  order — the SortMenu below flips the arrow only for what actually reads
//  naturally ascending (name).
//

import Foundation

nonisolated enum ScanSortKey: String, CaseIterable, Identifiable, Sendable {
    case size = "Size"
    case name = "Name"
    case date = "Date"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .size: return "arrow.up.arrow.down"
        case .name: return "textformat"
        case .date: return "calendar"
        }
    }
}
