import SwiftUI
import UIKit

/// Bottom-sheet custom color picker for `ReminderColorTag`.
///
/// Shows three always-visible HSB sliders (hue, saturation,
/// brightness) plus a live preview swatch and a hex text field for
/// direct typing/pasting. No "tap to expand" gateway — every control
/// is interactable the moment the sheet appears.
struct ColorWheelSheet: View {
    @Binding var tag: ReminderColorTag
    @Environment(\.dismiss) private var dismiss

    @State private var hue: Double
    @State private var saturation: Double
    @State private var brightness: Double
    @State private var hexInput: String

    init(tag: Binding<ReminderColorTag>) {
        self._tag = tag
        // Seed from existing tag (or accent when not custom yet).
        let initialColor: Color = {
            if case .custom = tag.wrappedValue { return tag.wrappedValue.swiftUIColor }
            return .accentColor
        }()
        let (h, s, b) = Self.hsb(of: initialColor)
        _hue = State(initialValue: h)
        _saturation = State(initialValue: s)
        _brightness = State(initialValue: b)
        _hexInput = State(initialValue: initialColor.hexString)
    }

    private var workingColor: Color {
        Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Circle()
                        .fill(workingColor)
                        .frame(width: 96, height: 96)
                        .overlay(Circle().stroke(.secondary.opacity(0.3), lineWidth: 1))
                        .padding(.top, 8)

                    // HSB sliders — always visible, no extra tap to
                    // reveal. Each track shows the gradient relevant
                    // to that axis so the thumb position is obvious.
                    VStack(spacing: 14) {
                        sliderRow(
                            label: "Hue",
                            value: $hue,
                            track: AnyView(
                                LinearGradient(
                                    gradient: Gradient(colors: stride(from: 0.0, through: 1.0, by: 0.1).map {
                                        Color(hue: $0, saturation: 1, brightness: 1)
                                    }),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        )
                        sliderRow(
                            label: "Saturation",
                            value: $saturation,
                            track: AnyView(
                                LinearGradient(
                                    colors: [
                                        Color(hue: hue, saturation: 0, brightness: brightness),
                                        Color(hue: hue, saturation: 1, brightness: brightness),
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        )
                        sliderRow(
                            label: "Brightness",
                            value: $brightness,
                            track: AnyView(
                                LinearGradient(
                                    colors: [
                                        Color(hue: hue, saturation: saturation, brightness: 0),
                                        Color(hue: hue, saturation: saturation, brightness: 1),
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        )
                    }
                    .padding(.horizontal, 8)

                    // Hex text field — bidirectional sync with sliders.
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
                }
                .padding(20)
            }
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
            // Slider drag → hex updates.
            .onChange(of: hue) { _, _ in syncHexFromSliders() }
            .onChange(of: saturation) { _, _ in syncHexFromSliders() }
            .onChange(of: brightness) { _, _ in syncHexFromSliders() }
            // Hex type → sliders update (only when valid).
            .onChange(of: hexInput) { _, newHex in
                guard let parsed = Color(hex: newHex) else { return }
                let (h, s, b) = Self.hsb(of: parsed)
                // Tolerance check so micro-roundtripping doesn't fight
                // the user's drag.
                if abs(h - hue) > 0.005 || abs(s - saturation) > 0.005 || abs(b - brightness) > 0.005 {
                    hue = h
                    saturation = s
                    brightness = b
                }
            }
        }
    }

    private func syncHexFromSliders() {
        let h = workingColor.hexString
        if h.uppercased() != hexInput.uppercased() {
            hexInput = h
        }
    }

    private func sliderRow(label: String, value: Binding<Double>, track: AnyView) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.system(size: 12, weight: .heavy)).tracking(0.6)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(value.wrappedValue * 100))%")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            ZStack {
                Capsule().fill(.tertiary).frame(height: 18)
                track.frame(height: 18).clipShape(Capsule())
                Slider(value: value, in: 0...1)
                    .tint(.clear)   // hide the default tint so the gradient track shows through
            }
            .frame(height: 28)
        }
    }

    private func save() {
        tag = .custom(workingColor.hexString)
        dismiss()
    }

    /// HSB decomposition via UIColor (Color doesn't expose components
    /// directly). Defaults a sensible mid-gray when extraction fails.
    private static func hsb(of color: Color) -> (Double, Double, Double) {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (Double(h), Double(s), Double(b))
    }
}
