import SwiftUI
import UIKit

/// Color picker for `ReminderColorTag`. Wraps the system
/// `UIColorPickerViewController` so we get Apple's three-tab UI for
/// free:
/// - **Grid** — preset color swatches
/// - **Spectrum** — 2D hue/saturation plane + brightness slider
/// - **Sliders** — RGB / HSB / Hex (toggle in the picker chrome)
///
/// All three tabs are always visible at the top of the sheet — no
/// extra tap to reveal them. The Sliders tab has a built-in Hex
/// input via Apple's "Display P3 Hex Color" mode toggle.
///
/// Binding updates as the user drags, so the parent view sees the
/// custom-tag set in real time. Swipe down to dismiss.
struct ColorWheelSheet: View {
    @Binding var tag: ReminderColorTag

    /// Track the working color separately so we don't churn the
    /// parent binding on every drag pixel — we only push back when
    /// the user actually stops moving.
    @State private var workingColor: UIColor

    init(tag: Binding<ReminderColorTag>) {
        self._tag = tag
        let seed: UIColor = {
            if case .custom = tag.wrappedValue {
                return UIColor(tag.wrappedValue.swiftUIColor)
            }
            return UIColor(Color.accentColor)
        }()
        _workingColor = State(initialValue: seed)
    }

    var body: some View {
        SystemColorPicker(color: $workingColor)
            .ignoresSafeArea()
            .onChange(of: workingColor) { _, newColor in
                tag = .custom(Color(uiColor: newColor).hexString)
            }
    }
}

/// SwiftUI wrapper for `UIColorPickerViewController`. The system
/// controller renders the Grid / Spectrum / Sliders tab bar itself
/// at the top and a brightness slider at the bottom; we just bind
/// its selectedColor to a `@State` so SwiftUI sees the live updates.
private struct SystemColorPicker: UIViewControllerRepresentable {
    @Binding var color: UIColor

    func makeUIViewController(context: Context) -> UIColorPickerViewController {
        let picker = UIColorPickerViewController()
        picker.selectedColor = color
        picker.supportsAlpha = false
        picker.delegate = context.coordinator
        // Inline presentation — don't show a Close button (the
        // SwiftUI sheet handles dismissal via swipe / chrome).
        picker.modalPresentationStyle = .pageSheet
        return picker
    }

    func updateUIViewController(_ vc: UIColorPickerViewController, context: Context) {
        // Keep the picker's selectedColor in sync if the parent
        // changed it (rare — usually only on first open).
        if vc.selectedColor != color {
            vc.selectedColor = color
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIColorPickerViewControllerDelegate {
        var parent: SystemColorPicker
        init(_ p: SystemColorPicker) { self.parent = p }

        func colorPickerViewControllerDidSelectColor(_ vc: UIColorPickerViewController) {
            parent.color = vc.selectedColor
        }

        func colorPickerViewController(
            _ viewController: UIColorPickerViewController,
            didSelect color: UIColor,
            continuously: Bool
        ) {
            // iOS 15+ continuous-update variant. Forward every change.
            parent.color = color
        }
    }
}
