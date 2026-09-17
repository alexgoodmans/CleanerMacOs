//
//  SizeRangeSlider.swift
//  Again Cleaner
//
//  A draggable two-handle range slider spanning [smallest found ... largest
//  found] so any scan-result list can be narrowed by size in one gesture.
//  SwiftUI's own Slider has no range-binding variant, so this is a small,
//  self-contained track + two thumbs built on DragGesture.
//

import SwiftUI

struct SizeRangeSlider: View {
    /// Full extent of what was found — the slider's travel limits.
    let bounds: ClosedRange<Int64>
    /// The currently selected sub-range within `bounds`.
    @Binding var selection: ClosedRange<Int64>

    private let trackHeight: CGFloat = 4
    private let thumbSize: CGFloat = 14

    private var span: Double { max(1, Double(bounds.upperBound - bounds.lowerBound)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(Format.size(selection.lowerBound))
                Text("–")
                Text(Format.size(selection.upperBound))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)

            GeometryReader { geo in
                let width = max(1, geo.size.width - thumbSize)
                let lowerX = fraction(of: selection.lowerBound) * width
                let upperX = fraction(of: selection.upperBound) * width

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)
                        .frame(height: trackHeight)

                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: max(0, upperX - lowerX), height: trackHeight)
                        .offset(x: lowerX)

                    thumb(x: lowerX) { drag in
                        let raw = value(at: drag, width: width)
                        selection = min(raw, selection.upperBound)...selection.upperBound
                    }
                    thumb(x: upperX) { drag in
                        let raw = value(at: drag, width: width)
                        selection = selection.lowerBound...max(raw, selection.lowerBound)
                    }
                }
                .frame(height: thumbSize)
            }
            .frame(height: thumbSize)
        }
        .disabled(bounds.upperBound <= bounds.lowerBound)
    }

    private func fraction(of value: Int64) -> Double {
        Double(value - bounds.lowerBound) / span
    }

    private func value(at dragX: CGFloat, width: CGFloat) -> Int64 {
        let clampedX = min(max(0, dragX), width)
        let fraction = width > 0 ? Double(clampedX) / Double(width) : 0
        return bounds.lowerBound + Int64(fraction * span)
    }

    private func thumb(x: CGFloat, onDrag: @escaping (CGFloat) -> Void) -> some View {
        Circle()
            .fill(Color.white)
            .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: 2))
            .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
            .frame(width: thumbSize, height: thumbSize)
            .offset(x: x)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in onDrag(g.location.x) }
            )
    }
}

extension SizeRangeSlider {
    /// Bounds spanning every size in `sizes`, or `0...0` when empty (the
    /// slider disables itself in that case — nothing to filter).
    static func bounds(for sizes: [Int64]) -> ClosedRange<Int64> {
        guard let lo = sizes.min(), let hi = sizes.max(), hi > lo else { return 0...0 }
        return lo...hi
    }
}
