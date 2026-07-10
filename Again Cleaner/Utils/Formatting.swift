//
//  Formatting.swift
//  Again Cleaner
//

import Foundation
import SwiftUI

enum Format {
    static let bytes: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowedUnits = [.useKB, .useMB, .useGB]
        return f
    }()

    static func size(_ value: Int64) -> String {
        value <= 0 ? "—" : bytes.string(fromByteCount: value)
    }

    static let date: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
}

extension Safety {
    var tint: Color {
        switch self {
        case .safe:    return .green
        case .caution: return .orange
        case .risky:   return .red
        }
    }
}
