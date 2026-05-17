import SwiftUI

/// Bottom-sheet color picker. Used to pick a custom hex color for
/// a `ReminderColorTag`. Wraps SwiftUI's native `ColorPicker` (the
/// system color wheel + sliders) and adds a hex text field so the
/// user can paste / type a value directly.
///
/// Bound to a `ReminderColorTag` so the caller doesn't have to know
/// about hex parsing. On every change (slider drag, hex edit) the
/// tag is replaced with a fresh `.custom(hex)`.
struct ColorWheelSheet: View {
    @Binding var tag: ReminderColorTag
    @Environment(\.dismiss) private var dismiss

    @State private var workingColor: Color
    @State private var hexInput: String

    init(tag: Binding<ReminderColorTag>) {
        self._tag = tag
        // Seed from current tag. Falls back to accent when the tag
        // isn't custom yet.
        let initialColor: Color = {
            if case .custom = tag.wrappedValue { return tag.wrappedValue.swiftUIColor }
            return .accentColor
        }()
        _workingColor = State(initialValue: initialColor)
        _hexInput = State(initialValue: initialColor.hexString)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                // Big preview swatch so the user can see the result.
                Circle()
                    .fill(workingColor)
                    .frame(width: 88, height: 88)
                    .overlay(Circle().stroke(.secondary.opacity(0.3), lineWidth: 1))
                    .padding(.top, 8)

                // Native iOS color wheel — clear label, big tap area.
                ColorPicker(
                    "Color wheel",
                    selection: $workingColor,
                    supportsOpacity: false
                )
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))

                // Hex text field. Updates the color when a valid
                // 6-digit hex is typed (with or without leading #).
                HStack(spacing: 10) {
                    Text("Hex").font(.system(size: 14, weight: .semibold))
                    TextField("#FF8800", text: $hexInput)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                        .multilineTextAlignment(.trailing)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))

                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle("Custom color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
            // Keep the two inputs in sync. Wheel-drag → hex updates.
            // Hex-type → color updates iff it parses cleanly.
            .onChange(of: workingColor) { _, newColor in
                let newHex = newColor.hexString
                if newHex.uppercased() != hexInput.uppercased() {
                    hexInput = newHex
                }
            }
            .onChange(of: hexInput) { _, newHex in
                if let parsed = Color(hex: newHex), parsed != workingColor {
                    workingColor = parsed
                }
            }
        }
    }

    private func save() {
        tag = .custom(workingColor.hexString)
        dismiss()
    }
}
