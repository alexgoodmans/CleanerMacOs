//
//  FileKind.swift
//  Again Cleaner
//
//  Classifies a large file by extension so the Large Files screen can filter to
//  the usual space hogs (disk images, archives, video, VM disks, installers).
//  Pure and testable — extension matching only.
//

import Foundation

nonisolated enum FileKind: String, CaseIterable, Sendable, Identifiable {
    case diskImage, archive, video, vm, installer, audio, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .diskImage: return String(localized: "Disk Image")
        case .archive:   return String(localized: "Archive")
        case .video:     return String(localized: "Video")
        case .vm:        return String(localized: "VM Disk")
        case .installer: return String(localized: "Installer")
        case .audio:     return String(localized: "Audio")
        case .other:     return String(localized: "Other")
        }
    }

    var systemImage: String {
        switch self {
        case .diskImage: return "opticaldiscdrive"
        case .archive:   return "doc.zipper"
        case .video:     return "film"
        case .vm:        return "cube.box"
        case .installer: return "shippingbox"
        case .audio:     return "waveform"
        case .other:     return "doc"
        }
    }

    /// Multi-part suffixes checked first, then single extensions.
    nonisolated static func of(_ url: URL) -> FileKind {
        let name = url.lastPathComponent.lowercased()
        func hasExt(_ exts: [String]) -> Bool {
            exts.contains { name.hasSuffix(".\($0)") }
        }
        if hasExt(["iso", "dmg", "cdr", "sparseimage", "sparsebundle"]) { return .diskImage }
        if hasExt(["vmdk", "hdd", "qcow2", "vdi", "vhd", "vhdx", "ova", "ovf", "utm"]) { return .vm }
        if hasExt(["zip", "tar", "gz", "tgz", "bz2", "xz", "7z", "rar", "tar.gz"]) { return .archive }
        if hasExt(["mov", "mp4", "m4v", "avi", "mkv", "webm", "flv"]) { return .video }
        if hasExt(["pkg", "mpkg", "msi", "exe"]) { return .installer }
        if hasExt(["wav", "aiff", "flac", "mp3", "m4a"]) { return .audio }
        return .other
    }
}
