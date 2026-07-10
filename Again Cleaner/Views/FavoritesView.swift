//
//  FavoritesView.swift
//  Again Cleaner
//
//  User-picked folders that can be emptied in one click.
//

import SwiftUI
import AppKit

struct FavoritesView: View {
    @ObservedObject var vm: CleanerViewModel
    @State private var confirmClean = false

    var body: some View {
        VStack(spacing: 0) {
            header

            if vm.favorites.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(vm.favorites) { fav in
                        FavoriteRow(favorite: fav,
                                    reveal: { vm.reveal(fav.url) },
                                    remove: { vm.removeFavorite(fav) })
                    }
                }
                .listStyle(.inset)
            }

            footer
        }
        .navigationTitle("Favorites")
        .task { await vm.scanFavorites() }
        .confirmationDialog(
            "Empty \(vm.favorites.count) favorite folder(s)?",
            isPresented: $confirmClean,
            titleVisibility: .visible
        ) {
            Button(vm.moveToTrash ? "Move Contents to Trash" : "Delete Contents",
                   role: .destructive) {
                Task { await vm.cleanFavorites() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if vm.moveToTrash {
                Text("The contents of every favorite folder will be removed. The folders themselves are kept. Items go to the Trash.")
            } else {
                Text("The contents of every favorite folder will be removed. The folders themselves are kept. This cannot be undone.")
            }
        }
        .overlay(alignment: .bottom) {
            if vm.showReclaimedBanner {
                Label("Reclaimed \(Format.size(vm.lastReclaimed))",
                      systemImage: "checkmark.circle.fill")
                    .font(.callout).bold()
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.green, in: Capsule())
                    .foregroundStyle(.white)
                    .padding(.bottom, 70)
                    .task {
                        try? await Task.sleep(for: .seconds(3))
                        withAnimation { vm.showReclaimedBanner = false }
                    }
            }
        }
    }

    // MARK: Sections

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Favorite folders")
                    .font(.headline)
                Text("Add folders you clean often — then empty them all in one click.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                pickFolder()
            } label: {
                Label("Add Folder", systemImage: "plus")
            }
        }
        .padding()
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No favorites yet", systemImage: "star")
        } description: {
            Text("Add folders like a build output, a downloads bucket or a scratch directory.")
        } actions: {
            Button("Add Folder") { pickFolder() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Toggle(isOn: $vm.moveToTrash) { Text("Move to Trash").font(.callout) }
                .toggleStyle(.switch)
                .controlSize(.mini)
            Spacer()
            Text("\(vm.favorites.count) folders · \(Format.size(vm.favoritesTotal))")
                .font(.callout).foregroundStyle(.secondary)
            Button {
                confirmClean = true
            } label: {
                if vm.isCleaning {
                    ProgressView().controlSize(.small)
                } else {
                    Label("Clean Favorites", systemImage: "trash")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(vm.favorites.isEmpty || vm.isCleaning || vm.favoritesTotal == 0)
        }
        .padding()
        .background(.bar)
    }

    // MARK: Actions

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = String(localized: "Add to Favorites")
        panel.message = String(localized: "Choose folders to add to your favorites for quick cleanup.")
        if panel.runModal() == .OK {
            panel.urls.forEach { vm.addFavorite($0) }
        }
    }
}

private struct FavoriteRow: View {
    let favorite: FavoriteFolder
    let reveal: () -> Void
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .foregroundStyle(.yellow)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(favorite.name).font(.body).bold()
                Text(favorite.path)
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }

            Spacer()

            if favorite.isScanning {
                ProgressView().controlSize(.small)
            } else {
                Text(Format.size(favorite.size))
                    .font(.body.monospacedDigit())
            }

            Button(action: reveal) { Image(systemName: "magnifyingglass") }
                .buttonStyle(.borderless).help("Reveal in Finder")
            Button(action: remove) { Image(systemName: "star.slash") }
                .buttonStyle(.borderless).help("Remove from favorites")
        }
        .padding(.vertical, 4)
    }
}
