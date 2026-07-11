//
//  DonateView.swift
//  Again Cleaner
//

import SwiftUI

// MARK: - Donation configuration
//
// "Buy me a coffee" donations via DonationAlerts — opens a hosted page in the
// browser: no payment SDK, no App Store review issues, works internationally.
enum Donation {
    /// Master switch for the Donate section in the sidebar.
    static let isEnabled = true

    /// DonationAlerts page.
    static let donationAlertsURL = URL(string: "https://www.donationalerts.com/r/digkill")!
}

// MARK: - Donate view

struct DonateView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // Header
                VStack(spacing: 12) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 88, height: 88)
                        .background(
                            LinearGradient(colors: [.orange, .brown],
                                           startPoint: .topLeading,
                                           endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                        )
                        .shadow(radius: 8, y: 4)

                    Text("Support Again Cleaner").font(.title).bold()
                    Text("The app is free and always will be. If it saved you some gigabytes — you can buy the developer a coffee ☕")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }
                .padding(.top, 12)

                // Coffee button card
                VStack(spacing: 14) {
                    Button {
                        openURL(Donation.donationAlertsURL)
                    } label: {
                        HStack {
                            Image(systemName: "cup.and.saucer.fill")
                            Text("Buy me a coffee")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.large)

                    Text("Opens DonationAlerts in your browser — any amount, any method.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                .frame(maxWidth: 420)

                Text("Thank you for your support ♥")
                    .font(.caption2).foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
        }
        .navigationTitle("Donate")
    }
}

#Preview {
    DonateView().frame(width: 600, height: 500)
}
