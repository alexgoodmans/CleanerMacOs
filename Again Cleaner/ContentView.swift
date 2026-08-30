//
//  ContentView.swift
//  Again Cleaner
//

import SwiftUI

enum Section: String, CaseIterable, Identifiable {
    case overview  = "Overview"
    case smartScan = "Smart Scan"
    case junk      = "Junk Cleanup"
    case largeFiles = "Large Files"
    case favorites = "Favorites"
    case donate    = "Donate"
    case about     = "About"

    var id: String { rawValue }

    /// Localizable sidebar title (raw values stay stable for selection state).
    var title: LocalizedStringKey { LocalizedStringKey(rawValue) }

    /// Sections shown in the sidebar (Donate is gated behind a feature flag).
    static var visibleCases: [Section] {
        allCases.filter { $0 != .donate || Donation.isEnabled }
    }

    var systemImage: String {
        switch self {
        case .overview:   return "gauge.with.dots.needle.67percent"
        case .smartScan:  return "wand.and.stars"
        case .junk:       return "sparkles"
        case .largeFiles: return "doc.viewfinder"
        case .favorites:  return "star"
        case .donate:     return "heart"
        case .about:      return "person.crop.circle"
        }
    }
}

struct ContentView: View {
    @StateObject private var vm = CleanerViewModel()
    @StateObject private var smart = SmartScanModel()
    @State private var section: Section = .overview

    var body: some View {
        NavigationSplitView {
            List(Section.visibleCases, selection: $section) { item in
                Label(item.title, systemImage: item.systemImage)
                    .tag(item)
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210)
            .listStyle(.sidebar)
            .safeAreaInset(edge: .bottom) { DiskFooter(disk: vm.disk) }
        } detail: {
            Group {
                switch section {
                case .overview:   OverviewView(vm: vm)
                case .smartScan:  SmartScanView(vm: smart)
                case .junk:       JunkView(vm: vm)
                case .largeFiles: LargeFilesView(vm: vm)
                case .favorites:  FavoritesView(vm: vm)
                case .donate:     DonateView()
                case .about:      AboutView()
                }
            }
            .frame(minWidth: 560, minHeight: 480)
        }
        .task { vm.refreshDisk() }
    }
}

// MARK: - Sidebar disk footer

private struct DiskFooter: View {
    let disk: DiskInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "internaldrive")
                Text("Macintosh HD").font(.caption).bold()
                Spacer()
            }
            ProgressView(value: disk.usedFraction)
                .tint(disk.usedFraction > 0.9 ? .red : .accentColor)
            Text("\(Format.size(disk.free)) free of \(Format.size(disk.total))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
        .padding(8)
    }
}

#Preview {
    ContentView()
}
