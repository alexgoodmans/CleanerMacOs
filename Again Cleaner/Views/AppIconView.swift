//
//  AppIconView.swift
//  Again Cleaner
//
//  Shows the real .app icon (via NSWorkspace) instead of a generic glyph
//  wherever a row represents an actual application — much more scannable
//  than an SF Symbol when you're looking at a list of apps. Icons are cached
//  in memory by path since NSWorkspace's lookup isn't free and the same app
//  can appear in several lists (Large Applications, leftovers, uninstall…).
//

import SwiftUI
import AppKit

@MainActor
private enum AppIconCache {
    static var storage: [String: NSImage] = [:]
}

struct AppIconView: View {
    let url: URL?
    var size: CGFloat = 18

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon).resizable()
            } else {
                Image(systemName: "app.dashed").resizable().foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }

    private var icon: NSImage? {
        guard let url else { return nil }
        let key = url.path
        if let cached = AppIconCache.storage[key] { return cached }
        guard FileManager.default.fileExists(atPath: key) else { return nil }
        let image = NSWorkspace.shared.icon(forFile: key)
        AppIconCache.storage[key] = image
        return image
    }
}
