//
//  OverviewView.swift
//  Again Cleaner
//

import SwiftUI

struct OverviewView: View {
    @ObservedObject var vm: CleanerViewModel
    @State private var confirmClean = false

    /// Categories with real reclaimable content, ordered by the chosen sort.
    private var found: [JunkCategory] {
        vm.sortedVisibleCategories
            .filter { (vm.results[$0.id]?.size ?? 0) > 0 }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                DiskGauge(disk: vm.disk)

                if vm.disk.usedFraction > 0.9 {
                    Label("Your disk is almost full. Start with a Junk Cleanup.",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                }

                HStack(spacing: 16) {
                    StatCard(title: "Reclaimable Junk",
                             value: vm.isScanningJunk ? "Scanning…" : Format.size(vm.totalReclaimable),
                             systemImage: "sparkles", tint: .accentColor)
                    StatCard(title: "Free Space",
                             value: Format.size(vm.disk.free),
                             systemImage: "externaldrive.badge.checkmark", tint: .green)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Recommended flow")
                        .font(.headline)
                    StepRow(number: 1, text: "Scan to see what actually eats space.")
                    StepRow(number: 2, text: "Clean caches, logs, trash and old build data.")
                    StepRow(number: 3, text: "Hunt down large files you forgot about.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))

                Button {
                    Task { await vm.scanJunk() }
                } label: {
                    Label(vm.isScanningJunk ? "Scanning…" : "Scan for Junk",
                          systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(vm.isScanningJunk)

                if vm.isScanningJunk {
                    ProgressView(value: vm.junkProgress) {
                        Text("Scanning…").font(.caption).foregroundStyle(.secondary)
                    }
                } else if !found.isEmpty {
                    foundSection
                }
            }
            .padding(24)
        }
        .navigationTitle("Overview")
        .sheet(isPresented: $confirmClean) {
            JunkCleanupPreviewSheet(vm: vm) {
                confirmClean = false
                Task { await vm.cleanSelected() }
            } cancel: {
                confirmClean = false
            }
        }
    }

    // MARK: - Found results (shown right under the scan button)

    private var foundSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                // Master checkbox for every found category.
                Button {
                    vm.setAllCategories(!vm.allFoundSelected)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: vm.allFoundSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(vm.allFoundSelected ? Color.accentColor : Color.secondary)
                        Text("Select all").font(.callout)
                    }
                }
                .buttonStyle(.plain)

                Text("Found problems")
                    .font(.headline)
                    .padding(.leading, 8)
                Spacer()

                // Sort control (shared with the Junk screen).
                Menu {
                    Picker("Sort by", selection: $vm.junkSort) {
                        ForEach(CleanerViewModel.JunkSort.allCases) { s in
                            Label(s.rawValue, systemImage: s.systemImage).tag(s)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label("Sort: \(vm.junkSort.rawValue)", systemImage: vm.junkSort.systemImage)
                        .font(.caption)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Sort categories")

                Text("\(found.count) categories · \(Format.size(vm.totalReclaimable))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)

            if vm.junkSizeBounds.upperBound > vm.junkSizeBounds.lowerBound {
                HStack(spacing: 12) {
                    Text("Filter by size").font(.caption).foregroundStyle(.secondary)
                    SizeRangeSlider(bounds: vm.junkSizeBounds, selection: $vm.junkSizeFilter)
                        .frame(maxWidth: 220)
                    Spacer()
                }
                .padding(.bottom, 10)
            }

            VStack(spacing: 0) {
                ForEach(found) { cat in
                    FoundRow(
                        category: cat,
                        size: vm.reclaimable(for: cat),
                        itemCount: vm.results[cat.id]?.itemCount ?? 0,
                        isSelected: vm.selected.contains(cat.id),
                        isExpanded: vm.expanded.contains(cat.id),
                        isFavorited: vm.isFavorited(cat),
                        toggle: { vm.toggleCategory(cat) },
                        toggleExpand: { Task { await vm.toggleExpand(cat) } },
                        toggleFavorite: { vm.toggleFavorite(cat) }
                    )
                    if vm.expanded.contains(cat.id) {
                        CategoryItemsList(vm: vm, categoryID: cat.id)
                            .padding(.vertical, 4)
                    }
                    if cat.id != found.last?.id { Divider() }
                }
            }
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 12) {
                Toggle(isOn: $vm.moveToTrash) { Text("Move to Trash").font(.callout) }
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                Spacer()
                Text("\(vm.selected.count) selected · \(Format.size(vm.selectedReclaimable))")
                    .font(.callout).foregroundStyle(.secondary)
                Button {
                    confirmClean = true
                } label: {
                    if vm.isCleaning {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Clean", systemImage: "trash")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(vm.selected.isEmpty || vm.isCleaning)
            }
            .padding(.top, 12)
        }
    }

}

/// Compact selectable row used in the Overview results list.
private struct FoundRow: View {
    let category: JunkCategory
    let size: Int64
    let itemCount: Int
    let isSelected: Bool
    let isExpanded: Bool
    let isFavorited: Bool
    let toggle: () -> Void
    let toggleExpand: () -> Void
    let toggleFavorite: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Leading disclosure indicator — makes it obvious the row expands.
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(isExpanded ? Color.accentColor : Color.secondary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .opacity(itemCount > 0 ? 1 : 0)
                .frame(width: 12)
                .onTapGesture { if itemCount > 0 { toggleExpand() } }

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .onTapGesture(perform: toggle)

            Image(systemName: category.systemImage)
                .frame(width: 20)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(category.title).font(.body).bold()
                    Text(category.safety.label)
                        .font(.caption2).bold()
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(category.safety.tint.opacity(0.18), in: Capsule())
                        .foregroundStyle(category.safety.tint)
                }
                Text(category.subtitle)
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(Format.size(size))
                .font(.body.monospacedDigit())

            Button(action: toggleFavorite) {
                Image(systemName: isFavorited ? "star.fill" : "star")
                    .foregroundStyle(isFavorited ? .yellow : .secondary)
            }
            .buttonStyle(.borderless)
            .help(isFavorited ? "Remove from Favorites" : "Add folder to Favorites")

            ExpandControl(itemCount: itemCount, isExpanded: isExpanded, action: toggleExpand)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        // Tapping the row body expands it; the checkbox handles selection.
        .onTapGesture { if itemCount > 0 { toggleExpand() } }
    }
}

private struct DiskGauge: View {
    let disk: DiskInfo

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 18)
                Circle()
                    .trim(from: 0, to: disk.usedFraction)
                    .stroke(disk.usedFraction > 0.9 ? Color.red : Color.accentColor,
                            style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: disk.usedFraction)
                VStack(spacing: 2) {
                    Text("\(Int(disk.usedFraction * 100))%").font(.system(size: 34, weight: .bold))
                    Text("used").font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(width: 160, height: 160)

            Text("\(Format.size(disk.used)) used · \(Format.size(disk.free)) free")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(tint)
            Text(value).font(.title3).bold()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct StepRow: View {
    let number: Int
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption).bold()
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.accentColor.opacity(0.2)))
            Text(text).font(.callout)
        }
    }
}
