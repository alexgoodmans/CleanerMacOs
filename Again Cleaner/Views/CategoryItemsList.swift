//
//  CategoryItemsList.swift
//  Again Cleaner
//
//  The file-level preview shown beneath an expanded category row. Every item
//  has its own checkbox (all ticked by default) so the user picks exactly what
//  gets removed.
//

import SwiftUI

/// A clearly-clickable disclosure pill — "‹N› ›" — that signals a row can be
/// expanded to reveal (and tick) its individual items.
struct ExpandControl: View {
    let itemCount: Int
    let isExpanded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 9))
                if isExpanded {
                    Text("Hide files")
                        .font(.caption2)
                } else {
                    Text("Show files (\(itemCount))")
                        .font(.caption2)
                }
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .foregroundStyle(isExpanded ? Color.accentColor : Color.secondary)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(
                (isExpanded ? Color.accentColor : Color.secondary).opacity(0.15),
                in: Capsule()
            )
            .overlay(
                Capsule().strokeBorder(
                    (isExpanded ? Color.accentColor : Color.secondary).opacity(0.3),
                    lineWidth: 0.5)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(itemCount == 0)
    }
}

struct CategoryItemsList: View {
    @ObservedObject var vm: CleanerViewModel
    let categoryID: String

    private var items: [TargetItem]? { vm.itemsByCategory[categoryID] }

    var body: some View {
        if let items {
            if items.isEmpty {
                Text("Nothing to remove")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.leading, 46).padding(.vertical, 2)
            } else {
                selectAllBar(count: items.count)
                ForEach(items.prefix(100)) { item in
                    row(item)
                }
                if items.count > 100 {
                    Text("+ \(items.count - 100) more items (all included)")
                        .font(.caption2).foregroundStyle(.tertiary)
                        .padding(.leading, 46)
                }
            }
        } else {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Loading…").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.leading, 46).padding(.vertical, 2)
        }
    }

    private func selectAllBar(count: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checklist")
                .font(.caption2).foregroundStyle(.secondary)
            Text("Tick what to remove · \(count) items")
                .font(.caption2).foregroundStyle(.secondary)
            Spacer()
            Button("All")  { vm.setAllItems(categoryID, selected: true) }
                .buttonStyle(.link).font(.caption2)
            Button("None") { vm.setAllItems(categoryID, selected: false) }
                .buttonStyle(.link).font(.caption2)
        }
        .padding(.leading, 46).padding(.trailing, 10).padding(.top, 2)
    }

    private func row(_ item: TargetItem) -> some View {
        let on = vm.isItemSelected(categoryID, item)
        return HStack(spacing: 8) {
            Image(systemName: on ? "checkmark.square.fill" : "square")
                .foregroundStyle(on ? Color.accentColor : Color.secondary)
                .onTapGesture { vm.toggleItem(categoryID, item) }

            Image(systemName: item.isDirectory ? "folder" : "doc")
                .font(.caption).foregroundStyle(.tertiary).frame(width: 16)

            VStack(alignment: .leading, spacing: 0) {
                Text(item.name).font(.caption).lineLimit(1).truncationMode(.middle)
                Text(item.parentPath).font(.caption2)
                    .foregroundStyle(.tertiary).lineLimit(1).truncationMode(.head)
            }

            Spacer()

            Text(Format.size(item.size))
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            if item.isDirectory {
                Button { vm.toggleFavorite(item.url) } label: {
                    Image(systemName: vm.isFavorite(item.url) ? "star.fill" : "star")
                        .font(.caption2)
                        .foregroundStyle(vm.isFavorite(item.url) ? .yellow : .secondary)
                }
                .buttonStyle(.borderless)
                .help(vm.isFavorite(item.url) ? "Remove from Favorites" : "Add folder to Favorites")
            }
            Button { vm.reveal(item.url) } label: {
                Image(systemName: "magnifyingglass").font(.caption2)
            }
            .buttonStyle(.borderless).help("Reveal in Finder")
        }
        .padding(.leading, 40).padding(.trailing, 4).padding(.vertical, 1)
        .contentShape(Rectangle())
        .onTapGesture { vm.toggleItem(categoryID, item) }
    }
}
