//
//  CleaningOverlay.swift
//  Again Cleaner
//
//  Shown over a results list while a cleanup runs. It blurs the list and
//  swallows every click, so nothing can be ticked, ignored, revealed or
//  uninstalled mid-clean — the selection the executor is working from stays
//  exactly what the user confirmed. A broom sweeping debris into a dustpan
//  plus a spinner make it obvious work is in progress.
//
//  SF Symbols has no broom, so the animation is drawn on a Canvas and driven
//  by TimelineView (pure function of time — no state to get out of sync).
//

import SwiftUI

struct CleaningOverlay: View {
    /// Optional "12 items · 3.4 GB" line under the title.
    var detail: String? = nil

    var body: some View {
        ZStack {
            Rectangle().fill(.regularMaterial)

            VStack(spacing: 12) {
                SweepingBroomAnimation()
                    .frame(width: 190, height: 110)

                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Cleaning in progress…").font(.headline)
                }

                if let detail {
                    Text(detail)
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Text("Please wait — items can't be changed until cleanup finishes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
        // Swallow every click/scroll aimed at the list underneath.
        .contentShape(Rectangle())
        .onTapGesture {}
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

// MARK: - Broom animation

struct SweepingBroomAnimation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            Canvas { ctx, size in
                let t = reduceMotion ? 0.3 : timeline.date.timeIntervalSinceReferenceDate
                Self.draw(in: &ctx, size: size, time: t)
            }
        }
        .accessibilityHidden(true)
    }

    // Palette
    private static let handleColor = Color(red: 0.58, green: 0.38, blue: 0.20)
    private static let strawColor  = Color(red: 0.95, green: 0.77, blue: 0.33)
    private static let strawLine   = Color(red: 0.78, green: 0.58, blue: 0.18)
    private static let bandColor   = Color(red: 0.80, green: 0.22, blue: 0.20)
    private static let panColor    = Color.accentColor
    private static let dustColors: [Color] = [.gray, .brown, .gray.opacity(0.7), .orange.opacity(0.7), .brown.opacity(0.8)]

    private static func draw(in ctx: inout GraphicsContext, size: CGSize, time t: Double) {
        // Everything is laid out on a 190×110 design grid, scaled to fit.
        let scale = min(size.width / 190, size.height / 110)
        ctx.scaleBy(x: scale, y: scale)
        let floorY: CGFloat = 98

        drawFloor(in: &ctx, floorY: floorY)
        drawDust(in: &ctx, floorY: floorY, time: t)
        drawDustpan(in: &ctx, floorY: floorY)
        drawBroom(in: &ctx, floorY: floorY, time: t)
    }

    private static func drawFloor(in ctx: inout GraphicsContext, floorY: CGFloat) {
        var floor = Path()
        floor.move(to: CGPoint(x: 6, y: floorY + 1))
        floor.addLine(to: CGPoint(x: 184, y: floorY + 1))
        ctx.stroke(floor, with: .color(.secondary.opacity(0.35)),
                   style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
    }

    /// Debris hopping right→left along the floor into the dustpan, staggered.
    private static func drawDust(in ctx: inout GraphicsContext, floorY: CGFloat, time t: Double) {
        let count = 6
        for k in 0..<count {
            let p = (t / 2.2 + Double(k) / Double(count)).truncatingRemainder(dividingBy: 1)
            let x = 158 - 118 * p
            let hop = abs(sin(p * .pi * 4)) * 5 * (1 - p)
            let y = Double(floorY) - 3 - hop
            // Fade out as it drops into the pan mouth.
            let alpha = p < 0.8 ? 1 : max(0, (1 - p) / 0.2)
            let s = 3.0 + Double(k % 3)
            var piece = ctx
            piece.opacity = alpha
            piece.translateBy(x: x, y: y)
            piece.rotate(by: .radians(p * 9 + Double(k)))
            let rect = CGRect(x: -s / 2, y: -s / 2, width: s, height: s)
            let shape = k.isMultiple(of: 2)
                ? Path(ellipseIn: rect)
                : Path(roundedRect: rect, cornerRadius: 0.8)
            piece.fill(shape, with: .color(dustColors[k % dustColors.count]))
        }
    }

    private static func drawDustpan(in ctx: inout GraphicsContext, floorY: CGFloat) {
        // Side view: back wall + floor scoop, open to the right.
        var pan = Path()
        pan.move(to: CGPoint(x: 18, y: floorY - 30))
        pan.addLine(to: CGPoint(x: 18, y: floorY))
        pan.addLine(to: CGPoint(x: 64, y: floorY))
        pan.addLine(to: CGPoint(x: 60, y: floorY - 5))
        pan.addQuadCurve(to: CGPoint(x: 26, y: floorY - 30),
                         control: CGPoint(x: 30, y: floorY - 8))
        pan.closeSubpath()
        ctx.fill(pan, with: .color(panColor.opacity(0.85)))
        ctx.stroke(pan, with: .color(panColor),
                   style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))

        var handle = Path()
        handle.move(to: CGPoint(x: 20, y: floorY - 28))
        handle.addLine(to: CGPoint(x: 6, y: floorY - 52))
        ctx.stroke(handle, with: .color(panColor),
                   style: StrokeStyle(lineWidth: 4, lineCap: .round))
    }

    private static func drawBroom(in ctx: inout GraphicsContext, floorY: CGFloat, time t: Double) {
        // One sweep stroke toward the pan (60%), then lift and return (40%).
        let period = 1.5
        let phase = (t / period).truncatingRemainder(dividingBy: 1)
        let x: Double, lift: Double, tilt: Double
        if phase < 0.6 {
            let e = easeInOut(phase / 0.6)
            x = 150 - 62 * e
            lift = 0
            tilt = 26 - 12 * e
        } else {
            let e = easeInOut((phase - 0.6) / 0.4)
            x = 88 + 62 * e
            lift = sin(e * .pi) * 7
            tilt = 14 + 12 * e
        }

        var broom = ctx
        broom.translateBy(x: x, y: Double(floorY) - lift)

        // The bristles stay flat on the floor (like a real broom pressed down);
        // only the handle tilts. The head's top edge follows the handle base.
        let rad = tilt * .pi / 180
        let top = CGPoint(x: 20 * sin(rad), y: -20 * cos(rad))

        var head = Path()
        head.move(to: CGPoint(x: top.x - 8, y: top.y))
        head.addLine(to: CGPoint(x: top.x + 8, y: top.y))
        head.addLine(to: CGPoint(x: 15, y: 0))
        head.addLine(to: CGPoint(x: -15, y: 0))
        head.closeSubpath()
        broom.fill(head, with: .color(strawColor))

        var straws = Path()
        for i in -3...3 {
            straws.move(to: CGPoint(x: top.x + Double(i) * 2.2, y: top.y + 2))
            straws.addLine(to: CGPoint(x: Double(i) * 4.2, y: 0))
        }
        broom.stroke(straws, with: .color(strawLine), lineWidth: 0.8)

        // Handle + binding band, tilted about the head's top centre.
        var upper = broom
        upper.translateBy(x: top.x, y: top.y)
        upper.rotate(by: .degrees(tilt))   // handle top leans right

        var stick = Path()
        stick.move(to: CGPoint(x: 0, y: -2))
        stick.addLine(to: CGPoint(x: 0, y: -68))
        upper.stroke(stick, with: .color(handleColor),
                     style: StrokeStyle(lineWidth: 4, lineCap: .round))

        let band = Path(roundedRect: CGRect(x: -9, y: -4, width: 18, height: 5), cornerRadius: 1.5)
        upper.fill(band, with: .color(bandColor))
    }

    private static func easeInOut(_ x: Double) -> Double {
        x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2
    }
}
