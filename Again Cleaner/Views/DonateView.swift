//
//  DonateView.swift
//  Again Cleaner
//

import SwiftUI

// MARK: - Donation configuration
//
// "Pay what you want" donations that work internationally.
// Opens a hosted checkout page in the browser — no payment SDK, no App Store
// review issues, and Apple does not take a cut when distributed outside the store.
//
// 👉 Set your own handles below. PayPal.me is the primary method because it can
//    carry the amount + currency directly in the URL, so preset buttons work.
enum Donation {
    /// Master switch for the Donate section. Flip to `true` once your payment
    /// accounts are set up — it will then appear in the sidebar.
    static let isEnabled = false

    /// PayPal.me handle, e.g. "digkill" → https://paypal.me/digkill/10USD
    static let payPalHandle = "digkill"
    /// Ko-fi username, e.g. "digkill" → https://ko-fi.com/digkill (page only)
    static let koFiHandle = "digkill"
    /// Buy Me a Coffee username → https://buymeacoffee.com/digkill (page only)
    static let buyMeACoffeeHandle = "digkill"

    /// Builds a PayPal.me checkout URL with an optional preset amount.
    static func payPalURL(amount: Decimal?, currency: String) -> URL? {
        var path = "https://paypal.me/\(payPalHandle)"
        if let amount {
            // PayPal.me accepts e.g. /10USD — format without trailing zeros.
            let value = NSDecimalNumber(decimal: amount).stringValue
            path += "/\(value)\(currency)"
        }
        return URL(string: path)
    }

    static var koFiURL: URL? { URL(string: "https://ko-fi.com/\(koFiHandle)") }
    static var buyMeACoffeeURL: URL? { URL(string: "https://buymeacoffee.com/\(buyMeACoffeeHandle)") }
}

// MARK: - Donate view

struct DonateView: View {

    /// Supported currencies for the preset/custom amount.
    private struct Currency: Identifiable, Hashable {
        let code: String
        let symbol: String
        var id: String { code }
    }

    private let currencies = [
        Currency(code: "USD", symbol: "$"),
        Currency(code: "EUR", symbol: "€"),
        Currency(code: "GBP", symbol: "£")
    ]

    private let presets: [Decimal] = [3, 5, 10, 25]

    @State private var currency = "USD"
    @State private var selectedAmount: Decimal? = 5
    @State private var customText: String = ""
    @Environment(\.openURL) private var openURL

    private var symbol: String {
        currencies.first { $0.code == currency }?.symbol ?? "$"
    }

    /// The amount that will actually be sent (custom field wins if it has a valid value).
    private var effectiveAmount: Decimal? {
        let normalized = customText.replacingOccurrences(of: ",", with: ".")
        if let value = Decimal(string: normalized), value > 0 {
            return value
        }
        return selectedAmount
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // Header
                VStack(spacing: 12) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 88, height: 88)
                        .background(
                            LinearGradient(colors: [.pink, .red],
                                           startPoint: .topLeading,
                                           endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                        )
                        .shadow(radius: 8, y: 4)

                    Text("Support Again Cleaner").font(.title).bold()
                    Text("The app is free. If it saved you some disk space — or a little time — you can chip in whatever you like. Every bit helps development.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }
                .padding(.top, 12)

                // Amount picker card
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Choose an amount").font(.headline)
                        Spacer()
                        Picker("Currency", selection: $currency) {
                            ForEach(currencies) { c in
                                Text("\(c.symbol) \(c.code)").tag(c.code)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .fixedSize()
                    }

                    // Preset amount buttons
                    HStack(spacing: 10) {
                        ForEach(presets, id: \.self) { amount in
                            let isSelected = customText.isEmpty && selectedAmount == amount
                            Button {
                                selectedAmount = amount
                                customText = ""
                            } label: {
                                Text("\(symbol)\(NSDecimalNumber(decimal: amount).stringValue)")
                                    .font(.callout).bold()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        isSelected ? AnyShapeStyle(Color.accentColor)
                                                   : AnyShapeStyle(.quaternary.opacity(0.4)),
                                        in: RoundedRectangle(cornerRadius: 10)
                                    )
                                    .foregroundStyle(isSelected ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Custom amount
                    HStack(spacing: 8) {
                        Text(symbol).font(.title3).foregroundStyle(.secondary)
                        TextField("Custom amount", text: $customText)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: customText) { _, newValue in
                                if !newValue.isEmpty { selectedAmount = nil }
                            }
                    }

                    // Donate button
                    Button {
                        if let url = Donation.payPalURL(amount: effectiveAmount, currency: currency) {
                            openURL(url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "heart.fill")
                            Text(donateButtonTitle)
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(effectiveAmount == nil)

                    Text("Opens PayPal in your browser. You can pay with a card even without a PayPal account.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding()
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                .frame(maxWidth: 420)

                // Other ways to donate
                VStack(alignment: .leading, spacing: 12) {
                    Text("Other ways").font(.headline)
                    if let url = Donation.koFiURL {
                        DonateLinkRow(icon: "cup.and.saucer.fill", title: "Ko-fi",
                                      detail: "ko-fi.com/\(Donation.koFiHandle)", url: url)
                    }
                    if let url = Donation.buyMeACoffeeURL {
                        DonateLinkRow(icon: "mug.fill", title: "Buy Me a Coffee",
                                      detail: "buymeacoffee.com/\(Donation.buyMeACoffeeHandle)", url: url)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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

    private var donateButtonTitle: String {
        if let amount = effectiveAmount {
            return "Donate \(symbol)\(NSDecimalNumber(decimal: amount).stringValue)"
        }
        return "Enter an amount"
    }
}

/// A tappable row that opens a donation platform URL.
private struct DonateLinkRow: View {
    let icon: String
    let title: String
    let detail: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 22)
                    .foregroundStyle(.pink)
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
    DonateView().frame(width: 600, height: 700)
}
