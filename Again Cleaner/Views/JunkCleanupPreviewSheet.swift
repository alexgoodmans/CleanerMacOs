//
//  JunkCleanupPreviewSheet.swift
//  Again Cleaner
//
//  Shared confirmation sheet for the legacy Overview/Junk flow (CleanerViewModel).
//  Replaces a bare confirmationDialog that showed only a total size and a
//  generic "moved to Trash" message — no risk breakdown, no list of what was
//  about to be removed. That gap, combined with "Caution" categories being
//  pre-ticked by default, is what let a real cleanup run without the user ever
//  seeing what they'd actually selected.
//

import SwiftUI

struct JunkCleanupPreviewSheet: View {
    @ObservedObject var vm: CleanerViewModel
    let confirm: () -> Void
    let cancel: () -> Void

    private var selectedCategories: [JunkCategory] {
        vm.categories
            .filter { vm.selected.contains($0.id) }
            .sorted { vm.reclaimable(for: $0) > vm.reclaimable(for: $1) }
    }
    private func bytes(_ safety: Safety) -> Int64 {
        selectedCategories.filter { $0.safety == safety }
            .reduce(0) { $0 + vm.reclaimable(for: $1) }
    }
    private var cautionItems: [JunkCategory] { selectedCategories.filter { $0.safety == .caution } }
    private var riskyItems: [JunkCategory] { selectedCategories.filter { $0.safety == .risky } }
    /// Everything beyond confirmed-safe — worth a second look before deleting.
    private var nonSafeItems: [JunkCategory] { selectedCategories.filter { $0.safety != .safe } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Confirm cleanup").font(.title2).bold()
            Text("This is not all junk. Review the mix before continuing.")
                .font(.callout).foregroundStyle(.secondary)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                row(String(localized: "Categories"), "\(selectedCategories.count)")
                row(String(localized: "Reclaimable"), Format.size(vm.selectedReclaimable))
                row(String(localized: "Safe"), Format.size(bytes(.safe)))
                row(String(localized: "Caution"), Format.size(bytes(.caution)))
                row(String(localized: "Risky"), Format.size(bytes(.risky)))
            }

            if !cautionItems.isEmpty {
                Label("\(cautionItems.count) “Caution” categor\(cautionItems.count == 1 ? "y" : "ies") selected — usually regenerable, but that's a guess based on where the folder lives, not a guarantee about what's inside it. Check the list below.",
                      systemImage: "questionmark.circle.fill")
                    .foregroundStyle(.orange)
                    .font(.callout)
            }
            if !riskyItems.isEmpty {
                Label("\(riskyItems.count) “Risky” categor\(riskyItems.count == 1 ? "y" : "ies") selected — may hold real data (whole app-support folders, simulators, documents). Not cache.",
                      systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            if !nonSafeItems.isEmpty {
                Text("What will be removed (beyond confirmed-safe):")
                    .font(.caption).bold().foregroundStyle(.secondary)
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(nonSafeItems) { cat in
                            HStack(alignment: .top, spacing: 8) {
                                Text(cat.safety.label)
                                    .font(.caption2).bold()
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(cat.safety.tint.opacity(0.18), in: Capsule())
                                    .foregroundStyle(cat.safety.tint)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(cat.title).font(.caption).lineLimit(1)
                                    Text(cat.subtitle).font(.caption2)
                                        .foregroundStyle(.tertiary).lineLimit(1)
                                }
                                Spacer()
                                Text(Format.size(vm.reclaimable(for: cat)))
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
                Button(vm.moveToTrash ? "Move to Trash" : "Delete Permanently", role: .destructive, action: confirm)
                    .buttonStyle(.borderedProminent)
                    .tint(!riskyItems.isEmpty ? .red : (!cautionItems.isEmpty ? .orange : .accentColor))
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
