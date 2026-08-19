//
//  DockerParsing.swift
//  Again Cleaner
//
//  Pure, unit-testable parsers for `docker system df` output and the size
//  strings Docker prints (SI units, base 1000: "10.27GB", "512MB", "0B").
//  Kept free of any Process/IO so they can be tested without Docker installed.
//

import Foundation

enum DockerParsing {

    /// Parse a Docker size token ("10.27GB", "512MB", "0B", "1.2kB") into bytes.
    nonisolated static func bytes(from token: String) -> Int64 {
        let s = token.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty, s != "N/A" else { return 0 }

        // Split number from unit suffix.
        let idx = s.firstIndex { $0.isLetter } ?? s.endIndex
        let numPart = String(s[s.startIndex..<idx])
        let unit = String(s[idx...]).uppercased()
        guard let value = Double(numPart) else { return 0 }

        let multiplier: Double
        switch unit {
        case "B", "":   multiplier = 1
        case "KB":      multiplier = 1_000
        case "MB":      multiplier = 1_000_000
        case "GB":      multiplier = 1_000_000_000
        case "TB":      multiplier = 1_000_000_000_000
        default:        multiplier = 1
        }
        return Int64(value * multiplier)
    }

    struct Row: Equatable, Sendable {
        let type: String        // "Images", "Containers", "Local Volumes", "Build Cache"
        let total: Int
        let active: Int
        let size: Int64
        let reclaimable: Int64
    }

    /// Parse the table form of `docker system df`.
    /// Columns: TYPE / TOTAL / ACTIVE / SIZE / RECLAIMABLE.
    nonisolated static func parseSystemDF(_ output: String) -> [Row] {
        var rows: [Row] = []
        let knownTypes = ["Images", "Containers", "Local Volumes", "Build Cache"]

        for line in output.split(separator: "\n") {
            let text = String(line)
            guard let type = knownTypes.first(where: { text.hasPrefix($0) }) else { continue }

            // Remaining columns after the (possibly multi-word) type.
            let rest = text.dropFirst(type.count)
            let cols = rest.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            // Expect: TOTAL ACTIVE SIZE RECLAIMABLE [(pct)]
            guard cols.count >= 4 else { continue }

            rows.append(Row(
                type: type,
                total: Int(cols[0]) ?? 0,
                active: Int(cols[1]) ?? 0,
                size: bytes(from: cols[2]),
                reclaimable: bytes(from: cols[3])
            ))
        }
        return rows
    }
}
