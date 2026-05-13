import SwiftUI
import PhotosUI

struct ImageCropView: View {
    let inputImage: UIImage
    var onSave: (Data) -> Void
    var onCancel: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1
    @State private var baseScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero

    private let cropDiameter: CGFloat = 280

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { geo in
                ZStack {
                    Image(uiImage: inputImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: cropDiameter, height: cropDiameter)
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(width: geo.size.width, height: geo.size.height)

                    Rectangle()
                        .fill(Color.black.opacity(0.65))
                        .mask(
                            Rectangle()
                                .overlay(
                                    Circle()
                                        .frame(width: cropDiameter, height: cropDiameter)
                                        .blendMode(.destinationOut)
                                )
                                .compositingGroup()
                        )
                        .allowsHitTesting(false)

                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: cropDiameter, height: cropDiameter)
                        .allowsHitTesting(false)
                }
                .contentShape(Rectangle())
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { v in scale = max(0.5, min(baseScale * v, 6)) }
                            .onEnded { _ in baseScale = scale },
                        DragGesture()
                            .onChanged { v in
                                offset = CGSize(
                                    width: baseOffset.width + v.translation.width,
                                    height: baseOffset.height + v.translation.height
                                )
                            }
                            .onEnded { _ in baseOffset = offset }
                    )
                )
            }

            VStack {
                Spacer()
                Text("Pinch to zoom · drag to move")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.bottom, 18)
                HStack {
                    Button("Cancel") {
                        if let onCancel { onCancel() } else { dismiss() }
                    }
                    .foregroundStyle(.white).padding()
                    Spacer()
                    Button("Use") {
                        if let data = renderCropped() { onSave(data) }
                    }
                    .foregroundStyle(.white).fontWeight(.bold).padding()
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 30)
        }
    }

    @MainActor
    private func renderCropped() -> Data? {
        let content = ZStack {
            Image(uiImage: inputImage)
                .resizable()
                .scaledToFill()
                .frame(width: cropDiameter, height: cropDiameter)
                .scaleEffect(scale)
                .offset(offset)
        }
        .frame(width: cropDiameter, height: cropDiameter)
        .clipShape(Circle())

        let renderer = ImageRenderer(content: content)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage?.jpegData(compressionQuality: 0.85)
    }
}
