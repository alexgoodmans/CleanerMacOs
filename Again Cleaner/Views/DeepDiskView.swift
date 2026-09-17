//
//  DeepDiskView.swift
//  Again Cleaner
//
//  Deep Disk Scan screen — a drill-down size tree (du -xhd 1 per level) with an
//  honest APFS free-space header and per-item proportion bars.
//

import SwiftUI

struct DeepDiskView: View {
    @ObservedObject var vm: DeepDiskModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            quickRoots
            Divider()
            breadcrumbBar
            if vm.children.count > 1 { Divider(); filterBar }
            Divider()
            content
        }
        .navigationTitle("Deep Disk Scan")
        .task { if vm.children.isEmpty { await vm.load(vm.root) } }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 16) {
            Image(systemName: "chart.pie").font(.system(size: 24)).foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 3) {
                Text("Disk").font(.headline)
                if vm.volume.total > 0 {
                    ProgressView(value: Double(vm.volume.used), total: Double(vm.volume.total))
                        .frame(width: 220)
                    Text("\(Format.size(vm.volume.available)) available of \(Format.size(vm.volume.total))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if vm.isLoading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Button("Cancel") { vm.cancel() }.buttonStyle(.link)
                }
            } else {
                Button { Task { await vm.load(vm.root) } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Rescan this folder")
            }
        }
        .padding()
    }

    private var quickRoots: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DeepDiskModel.quickRoots) { r in
                    Button(r.name) { Task { await vm.load(r.url) } }
                        .buttonStyle(.bordered).controlSize(.small)
                }
            }
            .padding(.horizontal).padding(.vertical, 6)
        }
    }

    private var breadcrumbBar: some View {
        HStack(spacing: 6) {
            Button { Task { await vm.goUp() } } label: { Image(systemName: "arrow.up") }
                .buttonStyle(.borderless).disabled(!vm.canGoUp)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(Array(vm.breadcrumb.enumerated()), id: \.offset) { _, crumb in
                        Button(crumb.name) { Task { await vm.load(crumb.url) } }
                            .buttonStyle(.link).font(.caption)
                        Text("›").font(.caption).foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer()
            if vm.isAtVolumeRoot {
                Label("du -x: volumes counted separately", systemImage: "info.circle")
                    .font(.caption2).foregroundStyle(.secondary)
                    .help("Under / the System and Data volumes are separate. Sizes stay on one volume so the APFS Data volume isn't double-counted as System.")
            }
        }
        .padding(.horizontal).padding(.vertical, 6)
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
            Text("\(vm.displayedChildren.count) of \(vm.children.count)")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal).padding(.vertical, 8)
    }

    // MARK: - Content

    @ViewBuilder private var content: some View {
        if vm.children.isEmpty && !vm.isLoading {
            ContentUnavailableView("Nothing to show", systemImage: "folder",
                                   description: Text("This folder is empty or unreadable."))
        } else {
            List(vm.displayedChildren) { child in
                DiskChildRow(child: child, fraction: fraction(child), vm: vm)
            }
            .listStyle(.inset)
        }
    }

    private func fraction(_ child: DiskChild) -> Double {
        vm.largestChild > 0 ? Double(child.size) / Double(vm.largestChild) : 0
    }
}

private struct DiskChildRow: View {
    let child: DiskChild
    let fraction: Double
    @ObservedObject var vm: DeepDiskModel

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: child.isDirectory ? "folder.fill" : "doc")
                .foregroundStyle(child.isDirectory ? Color.accentColor : .secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(child.url.lastPathComponent).lineLimit(1)
                    Spacer()
                    Text(Format.size(child.size))
                        .font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                }
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.tint.opacity(0.28))
                        .frame(width: max(2, geo.size.width * fraction), height: 4)
                }
                .frame(height: 4)
            }

            Button { vm.reveal(child.url) } label: { Image(systemName: "arrow.forward.square") }
                .buttonStyle(.borderless).help("Reveal in Finder")
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture { if child.isDirectory { Task { await vm.drill(into: child) } } }
    }
}
