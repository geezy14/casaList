import SwiftUI

/// Drop-in replacement for .buttonStyle(.plain) on full-row buttons.
/// Expands the hit area to the full frame so the entire row is tappable,
/// not just the text/icon content.
struct RowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

extension ButtonStyle where Self == RowButtonStyle {
    static var row: RowButtonStyle { RowButtonStyle() }
}
