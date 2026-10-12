//
//  TreemapView.swift
//  CleanMySims
//

import SwiftUI

/// Squarified treemap: each category gets an area proportional to its size.
struct TreemapView: View {
    struct Entry: Equatable {
        let type: CleanableItemType
        let size: Int64
        let itemCount: Int
        let isActive: Bool
    }

    let entries: [Entry]
    /// Keep the categories in their declared order instead of sorting by size,
    /// so tiles grow in place while a scan is running.
    var keepsOrder = false
    var onSelect: (CleanableItemType) -> Void = { _ in }

    private let spacing: CGFloat = 4

    var body: some View {
        GeometryReader { geometry in
            let nonEmpty = entries.filter { $0.size > 0 }
            let visible = keepsOrder ? nonEmpty : nonEmpty.sorted { $0.size > $1.size }
            let rects = Treemap.layout(
                visible.map { Double($0.size) },
                in: CGRect(origin: .zero, size: geometry.size)
            )

            ZStack(alignment: .topLeading) {
                ForEach(Array(zip(visible, rects)), id: \.0.type) { entry, rect in
                    let frame = rect.insetBy(dx: spacing / 2, dy: spacing / 2)
                    TreemapTile(entry: entry, size: frame.size) {
                        onSelect(entry.type)
                    }
                    .frame(width: max(frame.width, 0), height: max(frame.height, 0))
                    .offset(x: frame.minX, y: frame.minY)
                }
            }
            .padding(-spacing / 2)
        }
        .animation(.smooth(duration: 0.35), value: entries)
    }
}

private struct TreemapTile: View {
    let entry: TreemapView.Entry
    let size: CGSize
    let action: () -> Void

    @State private var isHovered = false

    private var title: String { entry.type.title }
    private var sizeText: String { entry.size.formatted(.byteCount(style: .file)) }

    var body: some View {
        Button(action: action) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(
                    Theme.Colors.tileBackground(for: entry.type),
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .overlay {
                    if entry.isActive {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Theme.Colors.accent, lineWidth: 2)
                    }
                }
                .brightness(isHovered ? -0.03 : 0)
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("\(title) · \(sizeText)")
        .accessibilityLabel("\(title), \(sizeText)")
    }

    private var cornerRadius: CGFloat {
        min(12, min(size.width, size.height) / 4)
    }

    @ViewBuilder
    private var content: some View {
        if size.width >= 120 && size.height >= 90 {
            VStack(alignment: .leading, spacing: 3) {
                CategoryIcon(type: entry.type, size: 28)
                Spacer(minLength: 4)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(sizeText)
                    .font(.system(size: size.width >= 200 && size.height >= 160 ? 24 : 17, weight: .bold))
                    .contentTransition(.numericText())
                if size.width >= 170 && size.height >= 140 && entry.itemCount > 0 {
                    HStack(spacing: 6) {
                        Text("^[\(entry.itemCount) item](inflect: true)")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.Colors.secondaryText)
                        if entry.type.isSafeToDelete {
                            SafeBadge()
                        }
                    }
                }
            }
            .lineLimit(1)
            .foregroundStyle(Theme.Colors.primaryText)
            .padding(12)
        } else if size.width >= 64 && size.height >= 50 {
            VStack(alignment: .leading, spacing: 2) {
                CategoryIcon(type: entry.type, size: 20)
                Spacer(minLength: 2)
                if size.width >= 70 && size.height >= 70 {
                    Text(entry.type.shortTitle)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Colors.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Text(sizeText)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.Colors.primaryText)
                    .lineLimit(1)
            }
            .padding(8)
        } else if size.width >= 24 && size.height >= 24 {
            CategoryIcon(type: entry.type, size: 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Squarified treemap layout (Bruls, Huizing & van Wijk).
enum Treemap {
    /// Rectangles for `values` (sorted largest first), in the same order.
    static func layout(_ values: [Double], in rect: CGRect) -> [CGRect] {
        let total = values.reduce(0, +)
        guard total > 0, rect.width > 0, rect.height > 0 else {
            return values.map { _ in .zero }
        }

        let scale = rect.width * rect.height / total
        let areas = values.map { $0 * scale }

        var result: [CGRect] = []
        var remaining = rect
        var row: [Double] = []
        var index = 0

        while index < areas.count {
            let side = min(remaining.width, remaining.height)
            let candidate = row + [areas[index]]
            if row.isEmpty || worstRatio(candidate, side: side) <= worstRatio(row, side: side) {
                row = candidate
                index += 1
            } else {
                let (placed, rest) = place(row, in: remaining)
                result += placed
                remaining = rest
                row = []
            }
        }
        if !row.isEmpty {
            result += place(row, in: remaining).placed
        }
        return result
    }

    /// Worst aspect ratio of a row laid along a side of length `side`.
    private static func worstRatio(_ row: [Double], side: Double) -> Double {
        let sum = row.reduce(0, +)
        guard sum > 0, side > 0, let largest = row.max(), let smallest = row.min(), smallest > 0 else {
            return .infinity
        }
        let sideSquared = side * side
        let sumSquared = sum * sum
        return max(sideSquared * largest / sumSquared, sumSquared / (sideSquared * smallest))
    }

    /// Lays a row along the shorter side of `rect` and returns what is left.
    private static func place(_ row: [Double], in rect: CGRect) -> (placed: [CGRect], rest: CGRect) {
        let sum = row.reduce(0, +)
        if rect.width >= rect.height {
            // Column on the left
            let width = sum / rect.height
            var y = rect.minY
            let placed = row.map { area -> CGRect in
                let height = area / width
                defer { y += height }
                return CGRect(x: rect.minX, y: y, width: width, height: height)
            }
            return (placed, CGRect(x: rect.minX + width, y: rect.minY, width: rect.width - width, height: rect.height))
        } else {
            // Row on top
            let height = sum / rect.width
            var x = rect.minX
            let placed = row.map { area -> CGRect in
                let width = area / height
                defer { x += width }
                return CGRect(x: x, y: rect.minY, width: width, height: height)
            }
            return (placed, CGRect(x: rect.minX, y: rect.minY + height, width: rect.width, height: rect.height - height))
        }
    }
}

#Preview {
    TreemapView(entries: [
        .init(type: .testClones, size: 73_400_000_000, itemCount: 10, isActive: false),
        .init(type: .runtimes, size: 16_900_000_000, itemCount: 2, isActive: true),
        .init(type: .builds, size: 13_300_000_000, itemCount: 8, isActive: false),
        .init(type: .previews, size: 6_000_000_000, itemCount: 3, isActive: false),
        .init(type: .deviceSupport, size: 6_800_000_000, itemCount: 1, isActive: false),
        .init(type: .cache, size: 3_800_000_000, itemCount: 2, isActive: false),
        .init(type: .androidSdk, size: 3_000_000_000, itemCount: 4, isActive: false),
        .init(type: .archives, size: 590_000_000, itemCount: 4, isActive: false)
    ])
    .frame(width: 590, height: 330)
    .padding()
}
