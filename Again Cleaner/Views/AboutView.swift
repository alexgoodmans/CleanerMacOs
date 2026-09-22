//
//  AboutView.swift
//  Again Cleaner
//

import SwiftUI

struct AboutView: View {

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(v) (\(b))"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // App identity
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 96, height: 96)
                        .background(
                            LinearGradient(colors: [.mint, .teal],
                                           startPoint: .topLeading,
                                           endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                        )
                        .shadow(radius: 8, y: 4)

                    Text("Again Cleaner").font(.title).bold()
                    Text(appVersion).font(.callout).foregroundStyle(.secondary)
                    Text("Safe, no-nonsense disk cleanup for macOS.")
                        .font(.callout).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 12)

                Divider().frame(maxWidth: 360)

                // Developer card
                VStack(alignment: .leading, spacing: 16) {
                    Text("Developer").font(.headline)

                    HStack(spacing: 14) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.teal)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("MediaRise").font(.title3).bold()
                            Text("Software • Robotics • Startups")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    LinkRow(icon: "envelope.fill", title: "Email",
                            detail: "alexcatleva@gmail.com",
                            url: URL(string: "mailto:alexcatleva@gmail.com")!)
                    LinkRow(icon: "chevron.left.forwardslash.chevron.right", title: "GitHub",
                            detail: "github.com/digkill",
                            url: URL(string: "https://github.com/digkill")!)
                    LinkRow(icon: "globe", title: "Website",
                            detail: "mediarise.org",
                            url: URL(string: "https://mediarise.org")!)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                .frame(maxWidth: 420)

                Text("Made with ♥ in Swift · © \(Calendar.current.component(.year, from: .now)) Digkill")
                    .font(.caption2).foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
        }
        .navigationTitle("About")
    }
}

/// A tappable contact row that opens a URL.
private struct LinkRow: View {
    let icon: String
    let title: String
    let detail: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 22)
                    .foregroundStyle(.teal)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.callout).bold().foregroundStyle(.primary)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption).foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AboutView().frame(width: 600, height: 600)
}
