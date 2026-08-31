//
//  JunkView.swift
//  Again Cleaner
//

import SwiftUI

struct JunkView: View {
    @ObservedObject var vm: CleanerViewModel
    @State private var confirmClean = false

    var body: some View {
        VStack(spacing: 0) {
            header

            if vm.results.isEmpty && !vm.isScanningJunk {
                emptyState
            } else {
                List {
                    ForEach(vm.sortedVisibleCategories) { cat in
                        JunkRow(
                            category: cat,
                            size: vm.reclaimable(for: cat),
                            isScanning: vm.results[cat.id]?.isScanning ?? false,
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
                        }
                    }
                }
                .listStyle(.inset)
            }

            footer
        }
        .navigationTitle("Junk Cleanup")
        .confirmationDialog(
            "Clean \(Format.size(vm.selectedReclaimable))?",
            isPresented: $confirmClean,
            titleVisibility: .visible
        ) {
            Button(vm.moveToTrash ? "Move to Trash" : "Delete Permanently",
                   role: .destructive) {
                Task { await vm.cleanSelected() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if vm.moveToTrash {
                Text("Selected items will be moved to the Trash where you can recover them.")
            } else {
                Text("Selected items will be permanently deleted and cannot be recovered.")
            }
        }
        .overlay(alignment: .bottom) {
            if vm.showReclaimedBanner { reclaimedBanner }
        }
    }

    // MARK: Sections

    private var header: some View {
        HStack {
            // Master checkbox for every found category.
            Button {
                vm.setAllCategories(!vm.allFoundSelected)
            } label: {
                Image(systemName: vm.allFoundSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(vm.allFoundSelected ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .help("Select all")

            VStack(alignment: .leading, spacing: 2) {
                Text("Found \(Format.size(vm.totalReclaimable)) of junk")
                    .font(.headline)
                Text("Safe items are pre-selected. Review risky ones before cleaning.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()

            // Sort control.
            Menu {
                Picker("Sort by", selection: $vm.junkSort) {
                    ForEach(CleanerViewModel.JunkSort.allCases) { s in
                        Label(s.rawValue, systemImage: s.systemImage).tag(s)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Label("Sort: \(vm.junkSort.rawValue)", systemImage: vm.junkSort.systemImage)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Sort categories")
            .disabled(vm.results.isEmpty)

            Button {
                Task { await vm.scanJunk() }
            } label: {
                Label(vm.isScanningJunk ? "Scanning…" : "Rescan", systemImage: "arrow.clockwise")
            }
            .disabled(vm.isScanningJunk)
        }
        .padding()
        .overlay(alignment: .bottom) {
            if vm.isScanningJunk { ProgressView(value: vm.junkProgress) }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nothing scanned yet", systemImage: "sparkles")
        } description: {
            Text("Run a scan to discover caches, logs and old build data.")
        } actions: {
            Button("Scan for Junk") { Task { await vm.scanJunk() } }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Toggle(isOn: $vm.moveToTrash) {
                Text("Move to Trash").font(.callout)
            }
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
        .padding()
        .background(.bar)
    }

    private var reclaimedBanner: some View {
        Label("Reclaimed \(Format.size(vm.lastReclaimed))",
              systemImage: "checkmark.circle.fill")
            .font(.callout).bold()
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(.green, in: Capsule())
            .foregroundStyle(.white)
            .padding(.bottom, 70)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task {
                try? await Task.sleep(for: .seconds(3))
                withAnimation { vm.showReclaimedBanner = false }
            }
    }

}

private struct JunkRow: View {
    let category: JunkCategory
    let size: Int64
    let isScanning: Bool
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
                .help(itemCount > 0 ? "Show files" : "")

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .onTapGesture(perform: toggle)

            Image(systemName: category.systemImage)
                .frame(width: 22)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(category.title).font(.body).bold()
                    SafetyBadge(safety: category.safety)
                }
                Text(category.subtitle)
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isScanning {
                ProgressView().controlSize(.small)
            } else {
                Text(Format.size(size))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.primary)
            }

            // Pin the category's folder(s) to Favorites for one-click cleanup.
            Button(action: toggleFavorite) {
                Image(systemName: isFavorited ? "star.fill" : "star")
                    .foregroundStyle(isFavorited ? .yellow : .secondary)
            }
            .buttonStyle(.borderless)
            .help(isFavorited ? "Remove from Favorites" : "Add folder to Favorites")

            // Disclosure control for the file-level preview.
            ExpandControl(itemCount: itemCount, isExpanded: isExpanded, action: toggleExpand)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        // Tapping the row body expands it; the checkbox handles selection.
        .onTapGesture { if itemCount > 0 { toggleExpand() } }
    }
}

private struct SafetyBadge: View {
    let safety: Safety
    var body: some View {
        Text(safety.label)
            .font(.caption2).bold()
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(safety.tint.opacity(0.18), in: Capsule())
            .foregroundStyle(safety.tint)
    }
}
