//
//  SmartScanView.swift
//  Again Cleaner
//
//  Analyzer screen: candidates grouped by category, classified by the 5-level
//  safety scale. Smart Clean auto-selects only Safe + Usually Safe. Review
//  Required is never folded into the green "safe cleanup" number.
//

import SwiftUI

struct SmartScanView: View {
    @ObservedObject var vm: SmartScanModel
    @State private var confirmClean = false

    var body: some View {
        VStack(spacing: 0) {
            header
            if vm.hasScanned || vm.isScanning { summaryBar }
            if !vm.runningBlockers.isEmpty { runningAppsBanner }
            // Only once the scan has actually stopped — while it's running the
            // size bounds are still growing, so a slider shown mid-scan would
            // keep jumping under the user's fingers.
            if !vm.candidates.isEmpty && !vm.isScanning && vm.hasScanned { Divider(); filterBar }
            Divider()
            content
            Divider()
            actionBar
        }
        .navigationTitle("Smart Scan")
        .sheet(isPresented: $confirmClean) {
            CleanupPreviewSheet(vm: vm) {
                confirmClean = false
                Task { await vm.cleanSelected() }
            } cancel: {
                confirmClean = false
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 16) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 26))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Smart Scan").font(.title2).bold()
                Text("Analyzes disk usage and classifies everything by how safe it is to remove.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if vm.isScanning {
                VStack(alignment: .trailing, spacing: 4) {
                    ProgressView(value: vm.progress).frame(width: 120)
                    Button("Cancel") { vm.cancel() }.buttonStyle(.link)
                }
            } else {
                Button {
                    Task { await vm.scan() }
                } label: {
                    Label(vm.hasScanned ? "Rescan" : "Scan", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r")
            }
        }
        .padding()
    }

    private var summaryBar: some View {
        HStack(spacing: 12) {
            SummaryChip(title: String(localized: "Scanned"),
                        value: Format.size(vm.totalFound), tint: .secondary)
            SummaryChip(title: String(localized: "Safe to clean"),
                        value: Format.size(vm.safeBytes), tint: .green)
            SummaryChip(title: String(localized: "Review required"),
                        value: Format.size(vm.reviewBytes), tint: .orange)
            SummaryChip(title: String(localized: "Selected"),
                        value: Format.size(vm.selectedBytes), tint: .accentColor)
            SummaryChip(title: String(localized: "Est. free after"),
                        value: Format.size(vm.estimatedFreeAfter), tint: .teal)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private var runningAppsBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(vm.runningBlockers.joined(separator: ", ")) is running")
                    .font(.subheadline).bold()
                Text("Close it before cleaning its data to avoid corruption.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Quit & Clean") { Task { await vm.quitAndClean() } }
                .buttonStyle(.borderedProminent)
            Button("Dismiss") { vm.dismissBlockers() }.buttonStyle(.link)
        }
        .padding(.horizontal).padding(.vertical, 8)
        .background(.orange.opacity(0.12))
    }

    private var filterBar: some View {
        HStack(spacing: 16) {
            Picker("Sort", selection: $vm.sortKey) {
                ForEach(ScanSortKey.allCases) { key in
                    Label(key.rawValue, systemImage: key.systemImage).tag(key)
                }
            }
            .labelsHidden().pickerStyle(.menu).fixedSize()

            SizeRangeSlider(bounds: vm.sizeBounds, selection: $vm.sizeFilter)
                .frame(maxWidth: 260)

            Spacer()
            let shown = vm.categoryGroups.reduce(0) { $0 + $1.items.count }
            Text("\(shown) of \(vm.candidates.count) items")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal).padding(.vertical, 8)
    }

    // MARK: - Content

    @ViewBuilder private var content: some View {
        if !vm.hasScanned && !vm.isScanning {
            emptyState
        } else if vm.candidates.isEmpty && !vm.isScanning {
            ContentUnavailableView("Nothing found", systemImage: "checkmark.seal",
                                   description: Text("No reclaimable data was detected."))
        } else {
            List {
                if let report = vm.lastReport { reportRow(report) }
                ForEach(vm.categoryGroups, id: \.category) { group in
                    SwiftUI.Section {
                        ForEach(group.items) { item in
                            CandidateRow(item: item, vm: vm)
                        }
                    } header: {
                        categoryHeader(group.category, items: group.items)
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "wand.and.stars").font(.system(size: 44)).foregroundStyle(.tint)
            Text("Scan your Mac").font(.title3).bold()
            Text("Find caches, build artifacts, SDKs, models and more —\nclassified by how safe they are to remove. Large is not junk.")
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button { Task { await vm.scan() } } label: {
                Label("Scan", systemImage: "sparkles.rectangle.stack")
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func categoryHeader(_ category: ScanCategory, items: [CleanupCandidate]) -> some View {
        let tick = vm.groupTick(for: items)
        let selectable = vm.selectableItems(in: items)
        return HStack(spacing: 8) {
            Button {
                vm.toggleGroup(items)
            } label: {
                Image(systemName: tick.symbol)
                    .font(.title3)
                    .foregroundStyle(tick == .none ? Color.secondary : Color.accentColor)
            }
            .buttonStyle(.plain)
            .disabled(selectable.isEmpty)
            .help(selectable.isEmpty
                  ? String(localized: "Nothing in this group can be selected")
                  : String(localized: "Select or deselect the whole group"))

            Image(systemName: category.systemImage)
            Text(category.title).font(.subheadline).bold()
            Text("· \(items.count)").foregroundStyle(.secondary)
            if !selectable.isEmpty {
                Text("· \(selectable.filter { vm.isSelected($0) }.count)/\(selectable.count)")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(Format.size(items.reduce(0) { $0 + $1.size }))
                .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !selectable.isEmpty else { return }
            vm.toggleGroup(items)
        }
    }

    private func reportRow(_ report: CleanupReport) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 1) {
                Text("Cleaned \(report.removedCount) item(s)").font(.subheadline).bold()
                Text("Actual disk space recovered: \(Format.size(report.actuallyRecovered))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !report.skipped.isEmpty {
                Text("\(report.skipped.count) skipped")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Action bar

    private var actionBar: some View {
        HStack(spacing: 12) {
            Toggle("Move to Trash", isOn: $vm.moveToTrash)
                .toggleStyle(.checkbox).font(.callout)

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text("\(vm.selected.count) selected")
                    .font(.caption).foregroundStyle(.secondary)
                Text(Format.size(vm.selectedBytes))
                    .font(.headline.monospacedDigit())
            }

            if vm.hasScanned && !vm.presetMatches.isEmpty {
                Button {
                    vm.applyPreset()
                    confirmClean = true
                } label: {
                    Label("Quick Clean · \(Format.size(vm.presetBytes))", systemImage: "bolt.fill")
                }
                .help("Select the same categories you cleaned last time — you'll still review before anything is removed")
                .disabled(vm.isCleaning)
            }

            Button("Select Safe") { vm.selectSmart() }
                .disabled(vm.candidates.isEmpty)
                .help("Select only Safe and Usually Safe items")

            Button {
                confirmClean = true
            } label: {
                if vm.isCleaning {
                    ProgressView().controlSize(.small)
                } else {
                    Label("Smart Clean", systemImage: "sparkles")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.selected.isEmpty || vm.isCleaning)
        }
        .padding()
    }
}

private struct SummaryChip: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.callout.bold().monospacedDigit()).foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Confirmation

private struct CleanupPreviewSheet: View {
    @ObservedObject var vm: SmartScanModel
    let confirm: () -> Void
    let cancel: () -> Void

    private var safeOnly: [CleanupCandidate] {
        vm.selectedItems().filter { $0.risk == .safe }
    }
    private var usuallySafe: [CleanupCandidate] {
        vm.selectedItems().filter { $0.risk == .usuallySafe }
    }
    private var reviewItems: [CleanupCandidate] {
        vm.selectedItems().filter { $0.risk == .reviewRequired }
    }
    private var destructive: [CleanupCandidate] {
        vm.selectedItems().filter { !$0.isRegenerable }
    }
    /// Anything riskier than the confirmed-disposable tier — worth a second look.
    private var nonSafeItems: [CleanupCandidate] {
        vm.selectedItems().filter { $0.risk != .safe }.sorted { $0.size > $1.size }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Confirm cleanup").font(.title2).bold()
            Text("This is not all junk. Review the mix before continuing.")
                .font(.callout).foregroundStyle(.secondary)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                row(String(localized: "Items"), "\(vm.selected.count)")
                row(String(localized: "Reclaimable"), Format.size(vm.selectedBytes))
                row(String(localized: "Safe"), Format.size(safeOnly.reduce(0) { $0 + $1.reclaimableBytes }))
                row(String(localized: "Usually safe"), Format.size(usuallySafe.reduce(0) { $0 + $1.reclaimableBytes }))
                row(String(localized: "Review required"), Format.size(vm.selectedReviewBytes))
            }

            if !usuallySafe.isEmpty {
                Label("\(usuallySafe.count) “usually safe” item(s) selected — regenerable for MOST apps, but this is a heuristic guess about where a file lives, not a guarantee about what's inside it. Check the list below.",
                      systemImage: "questionmark.circle.fill")
                    .foregroundStyle(.teal)
                    .font(.callout)
            }
            if !reviewItems.isEmpty {
                Label("\(reviewItems.count) review-required item(s) are selected. These may be SDKs, AVDs, volumes, models or documents — not cache.",
                      systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.callout)
            }
            if !destructive.isEmpty {
                Label("\(destructive.count) selected item(s) are not regenerable.",
                      systemImage: "xmark.shield")
                    .font(.callout)
            }
            let apps = RunningAppGuard.blockingApps(for: vm.selectedItems())
            if !apps.isEmpty {
                Label("Quit first: \(apps.joined(separator: ", "))",
                      systemImage: "app.badge.checkmark")
                    .font(.callout)
            }

            if !nonSafeItems.isEmpty {
                Text("What will be removed (beyond confirmed-safe):")
                    .font(.caption).bold().foregroundStyle(.secondary)
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(nonSafeItems) { item in
                            HStack(alignment: .top, spacing: 8) {
                                Text(item.risk.label)
                                    .font(.caption2).bold()
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(item.risk.tint.opacity(0.18), in: Capsule())
                                    .foregroundStyle(item.risk.tint)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.name).font(.caption).lineLimit(1)
                                    if let path = item.path {
                                        Text(path.path).font(.caption2.monospaced())
                                            .foregroundStyle(.tertiary).lineLimit(1).truncationMode(.middle)
                                    }
                                }
                                Spacer()
                                Text(Format.size(item.reclaimableBytes))
                                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(maxHeight: 160)
                .padding(8)
                .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
            }

            HStack {
                Spacer()
                Button("Cancel", action: cancel)
                Button(vm.moveToTrash ? "Move to Trash" : "Delete", action: confirm)
                    .buttonStyle(.borderedProminent)
                    .tint(!reviewItems.isEmpty ? .orange : .accentColor)
            }
        }
        .padding(24)
        .frame(minWidth: 480, idealWidth: 520)
    }

    private func row(_ k: String, _ v: String) -> some View {
        GridRow {
            Text(k).foregroundStyle(.secondary)
            Text(v).bold()
        }
    }
}

// MARK: - Candidate row

private struct CandidateRow: View {
    let item: CleanupCandidate
    @ObservedObject var vm: SmartScanModel

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if item.canUserDelete {
                Button {
                    vm.toggle(item)
                } label: {
                    Image(systemName: vm.isSelected(item) ? "checkmark.square.fill" : "square")
                        .foregroundStyle(vm.isSelected(item) ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
            } else if vm.isApp(item) {
                // The real app icon reads far better than a generic lock here —
                // this is exactly where you're scanning a list of applications.
                AppIconView(url: item.path)
            } else {
                Image(systemName: "lock.fill").foregroundStyle(.secondary).font(.caption)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name).font(.body).lineLimit(1).truncationMode(.middle)
                    Text(item.risk.label)
                        .font(.caption2).bold()
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(item.risk.tint.opacity(0.18), in: Capsule())
                        .foregroundStyle(item.risk.tint)
                        .help(item.risk.detail)
                    Spacer()
                    Text(Format.size(item.reclaimableBytes))
                        .font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                }
                Text(item.explanation)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(3)
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right.circle").font(.caption2)
                    Text(item.consequence).font(.caption2).lineLimit(2)
                }
                .foregroundStyle(item.risk.tint)
                if item.confidence == .unknown || item.confidence == .low {
                    Text(item.confidence.label).font(.caption2).foregroundStyle(.orange)
                }
                if let path = item.path {
                    Text(path.path)
                        .font(.caption2.monospaced()).foregroundStyle(.tertiary)
                        .lineLimit(1).truncationMode(.middle)
                }
            }

            if vm.isApp(item) {
                Button { Task { await vm.findLeftovers(for: item) } } label: {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.borderless).help("Find leftover files")
                Button { Task { await vm.uninstall(item) } } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless).help("Uninstall (move to Trash)")
            }

            if item.path != nil {
                Button { vm.ignore(item) } label: {
                    Image(systemName: "eye.slash")
                }
                .buttonStyle(.borderless)
                .help("Ignore this item")

                Button { vm.reveal(item) } label: {
                    Image(systemName: "arrow.forward.square")
                }
                .buttonStyle(.borderless)
                .help("Reveal in Finder")
            }
        }
        .padding(.vertical, 3)
    }
}
