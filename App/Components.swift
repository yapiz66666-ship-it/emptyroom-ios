import SwiftUI

/// Wraps children onto new lines, for campus and building chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let extra = rows[rows.count - 1].indices.isEmpty ? size.width : size.width + spacing
            if rows[rows.count - 1].width + extra > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            let isFirst = rows[rows.count - 1].indices.isEmpty
            rows[rows.count - 1].indices.append(index)
            rows[rows.count - 1].width += isFirst ? size.width : size.width + spacing
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
        }
        return rows
    }
}

/// A selectable chip, like Material's FilterChip.
struct ChipButton: View {
    let title: String
    let selected: Bool
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: selected ? .semibold : .regular))
                .foregroundColor(selected ? Palette.green : Palette.ink)
                .padding(.horizontal, 14)
                .frame(minHeight: 40)
                .background(RoundedRectangle(cornerRadius: 10).fill(selected ? Palette.greenSoft : Color.white))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Palette.green : Palette.busy, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
    }
}

struct LoadingPanel: View {
    let title: String
    let detail: String
    var actionTitle: String?
    var action: () -> Void = {}

    var body: some View {
        VStack(spacing: 10) {
            ProgressView().controlSize(.large)
            Text(title).font(.headline).multilineTextAlignment(.center).padding(.top, 14)
            Text(detail).font(.subheadline).foregroundColor(Palette.muted).multilineTextAlignment(.center)
            if let actionTitle {
                Button(actionTitle, action: action).padding(.top, 16)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background)
    }
}

struct GuideStep: View {
    let index: Int
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Palette.green)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Palette.greenSoft))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.medium)).foregroundColor(Palette.ink)
                Text(detail).font(.footnote).foregroundColor(Palette.muted)
            }
            Spacer(minLength: 0)
        }
    }
}

/// Big primary button used at the bottom of screens, within thumb reach.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(RoundedRectangle(cornerRadius: 16).fill(Palette.green.opacity(configuration.isPressed ? 0.8 : 1)))
    }
}
