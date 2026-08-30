//
//  SmartScanView.swift
//  Again Cleaner
//
//  The new analyzer screen. Shows every candidate grouped by risk with what it
//  is and what happens after removal. Smart Clean removes only safe +
//  regeneratable items; everything riskier is opt-in. After cleaning it reports
//  the REAL recovered space, not the summed file size.
//

import SwiftUI

struct SmartScanView: View {
    @ObservedObject var vm: SmartScanModel

    var body: some View {
        VStack(spacing: 0) {
            header
            if !vm.runningBlockers.isEmpty { runningAppsBanner }
            Divider()
            content
            Divider()
            actionBar
        }
        .navigationTitle("Smart Scan")
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
                ForEach(vm.groups, id: \.risk) { group in
                    SwiftUI.Section {
                        ForEach(group.items) { item in
                            CandidateRow(item: item, vm: vm)
                        }
                    } header: {
                        riskHeader(group.risk, count: group.items.count,
                                   size: vm.size(of: group.risk))
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
            Text("Find caches, build artifacts, Docker build cache and more —\nclassified by how safe they are to remove.")
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button { Task { await vm.scan() } } label: {
                Label("Scan", systemImage: "sparkles.rectangle.stack")
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func riskHeader(_ risk: CleanupRisk, count: Int, size: Int64) -> some View {
        HStack {
            Circle().fill(risk.tint).frame(width: 8, height: 8)
            Text(risk.label).font(.subheadline).bold()
            Text("· \(count)").foregroundStyle(.secondary)
            Spacer()
            Text(Format.size(size)).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
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
                    Task { await vm.quickClean() }
                } label: {
                    Label("Quick Clean · \(Format.size(vm.presetBytes))", systemImage: "bolt.fill")
                }
                .help("Clean the same categories you cleaned last time")
                .disabled(vm.isCleaning)
            }

            Button("Select Safe") { vm.selectSmart() }
                .disabled(vm.candidates.isEmpty)

            Button {
                Task { await vm.cleanSelected() }
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

// MARK: - Candidate row

private struct CandidateRow: View {
    let item: CleanupCandidate
    @ObservedObject var vm: SmartScanModel

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if item.risk.isDeletable {
                Button {
                    vm.toggle(item)
                } label: {
                    Image(systemName: vm.isSelected(item) ? "checkmark.square.fill" : "square")
                        .foregroundStyle(vm.isSelected(item) ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "lock.fill").foregroundStyle(.secondary).font(.caption)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name).font(.body).lineLimit(1)
                    Spacer()
                    Text(Format.size(item.size))
                        .font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                }
                Text(item.explanation)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right.circle").font(.caption2)
                    Text(item.consequence).font(.caption2)
                }
                .foregroundStyle(item.risk.tint)
                if let path = item.path {
                    Text(path.path)
                        .font(.caption2.monospaced()).foregroundStyle(.tertiary).lineLimit(1)
                }
            }

            if item.path != nil {
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
