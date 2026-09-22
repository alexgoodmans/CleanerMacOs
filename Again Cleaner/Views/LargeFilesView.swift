//
//  LargeFilesView.swift
//  Again Cleaner
//

import SwiftUI

struct LargeFilesView: View {
    @ObservedObject var vm: CleanerViewModel
    @State private var toDelete: LargeFile?

    var body: some View {
        VStack(spacing: 0) {
            controls

            if vm.largeFiles.isEmpty && !vm.isScanningFiles {
                ContentUnavailableView {
                    Label("No large files found", systemImage: "doc.viewfinder")
                } description: {
                    Text("Scan your home folder for files above the size threshold.")
                }
                .frame(maxHeight: .infinity)
            } else {
                Table(vm.filteredLargeFiles) {
                    TableColumn("Size") { file in
                        Text(Format.size(file.size))
                            .font(.body.monospacedDigit())
                    }
                    .width(90)
                    TableColumn("Name") { file in
                        Text(file.name).lineLimit(1).truncationMode(.middle)
                    }
                    TableColumn("Type") { file in
                        Label(file.kind.displayName, systemImage: file.kind.systemImage)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .width(120)
                    TableColumn("Belongs to") { file in
                        Text(file.owner ?? "—")
                            .font(.caption).foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.middle)
                    }
                    .width(130)
                    TableColumn("Location") { file in
                        Text(file.url.deletingLastPathComponent().path)
                            .font(.caption).foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.head)
                    }
                    TableColumn("Modified") { file in
                        Text(Format.date.string(from: file.modified))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .width(110)
                    TableColumn("") { file in
                        HStack(spacing: 8) {
                            Button { vm.reveal(file.url) } label: {
                                Image(systemName: "magnifyingglass")
                            }
                            .help("Reveal in Finder")
                            Button { toDelete = file } label: {
                                Image(systemName: "trash")
                            }
                            .help("Delete this file")
                        }
                        .buttonStyle(.borderless)
                    }
                    .width(70)
                }
            }
        }
        .navigationTitle("Large Files")
        .confirmationDialog(
            "Delete \(toDelete?.name ?? "")?",
            isPresented: Binding(get: { toDelete != nil },
                                 set: { if !$0 { toDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button(vm.moveToTrash ? "Move to Trash" : "Delete Permanently",
                   role: .destructive) {
                if let f = toDelete { vm.deleteLargeFile(f) }
                toDelete = nil
            }
            Button("Cancel", role: .cancel) { toDelete = nil }
        } message: {
            if let f = toDelete {
                Text("\(f.path)\n\(Format.size(f.size))")
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Files larger than")
                Text("\(Int(vm.largeFileThresholdMB)) MB").bold().monospacedDigit()
                Slider(value: $vm.largeFileThresholdMB, in: 100...5000, step: 100)
                    .frame(maxWidth: 240)
                Spacer()
                if vm.isScanningFiles {
                    Button("Stop", role: .destructive) { vm.cancelLargeScan() }
                    ProgressView().controlSize(.small)
                } else {
                    Button {
                        Task { await vm.scanLargeFiles() }
                    } label: {
                        Label("Scan", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            if !vm.largeFiles.isEmpty && !vm.isScanningFiles {
                HStack(spacing: 16) {
                    HStack(spacing: 8) {
                        Text("Type").font(.caption).foregroundStyle(.secondary)
                        Picker("Type", selection: $vm.largeFileKind) {
                            Text("All").tag(FileKind?.none)
                            ForEach(vm.largeFileKinds, id: \.kind) { entry in
                                Text("\(entry.kind.displayName) (\(entry.count))").tag(FileKind?.some(entry.kind))
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(maxWidth: 200)
                    }

                    Picker("Sort", selection: $vm.largeFileSort) {
                        ForEach(ScanSortKey.allCases) { key in
                            Label(key.rawValue, systemImage: key.systemImage).tag(key)
                        }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()

                    SizeRangeSlider(bounds: vm.largeFileSizeBounds, selection: $vm.largeFileSizeFilter)
                        .frame(maxWidth: 220)

                    Spacer()

                    Text("\(vm.filteredLargeFiles.count) files · \(Format.size(vm.filteredLargeFiles.reduce(0) { $0 + $1.size }))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(.bar)
    }
}
