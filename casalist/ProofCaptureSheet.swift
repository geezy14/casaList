import SwiftUI
import PhotosUI
import CoreData

/// Presented when someone completes a chore with `requiresProof` set.
/// They pick (or take, via the picker's camera affordance) a photo,
/// which gets compressed and stored inline on the TaskItem, then the
/// completion proceeds through the caller's `onProofAttached` closure.
///
/// Compression target ~350KB so the record stays a plain CloudKit
/// BYTES field well under the 1MB record cap (same strategy as
/// FamilyMember.photoBlob avatars).
struct ProofCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var moc
    @Environment(\.colorScheme) private var sys

    let task: TaskItem
    /// Called after the photo is stored — the caller completes the chore.
    let onProofAttached: () -> Void

    @State private var pickerItem: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var saving = false

    private var P: CasalistCottage.Palette { CasalistCottage.Palette.resolve(sys == .dark) }

    var body: some View {
        NavigationStack {
            ZStack {
                P.bg.ignoresSafeArea()
                VStack(spacing: 18) {
                    Text("📸").font(.system(size: 44))
                    Text("Show your work!")
                        .font(.system(size: 20, weight: .heavy))
                    Text("\"\(task.task)\" needs a photo before it counts. Snap the finished job.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(P.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    if let img = previewImage {
                        Image(uiImage: img)
                            .resizable().scaledToFill()
                            .frame(maxWidth: 260, maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(P.border, lineWidth: 1.5))
                    }

                    PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                        HStack(spacing: 8) {
                            Image(systemName: previewImage == nil ? "camera.fill" : "arrow.triangle.2.circlepath.camera.fill")
                                .font(.system(size: 14, weight: .heavy))
                            Text(previewImage == nil ? "Pick a photo" : "Choose a different photo")
                                .font(.system(size: 14, weight: .heavy))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Capsule().fill(P.sky))
                        .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 24)
                    .onChange(of: pickerItem) { _, item in
                        guard let item else { return }
                        Task {
                            if let data = try? await item.loadTransferable(type: Data.self),
                               let img = UIImage(data: data) {
                                previewImage = img
                            }
                        }
                    }

                    if previewImage != nil {
                        Button {
                            attachAndComplete()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 15, weight: .heavy))
                                Text(saving ? "Saving…" : "Attach & mark done")
                                    .font(.system(size: 15, weight: .heavy))
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 15)
                            .background(Capsule().fill(P.mint))
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(.row)
                        .disabled(saving)
                        .padding(.horizontal, 24)
                    }

                    Spacer()
                }
                .padding(.top, 26)
            }
            .foregroundStyle(P.text)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    /// Downscale + JPEG-compress to ~350KB max, store inline, hand back
    /// to the caller to run the normal completion path.
    private func attachAndComplete() {
        guard let img = previewImage, !saving else { return }
        saving = true
        // Cap the long edge at 1280px, then walk quality down until the
        // payload fits the inline-BYTES budget.
        let scaled = img.scaledToFit(maxDimension: 1280)
        var quality: CGFloat = 0.7
        var data = scaled.jpegData(compressionQuality: quality)
        while let d = data, d.count > 350_000, quality > 0.25 {
            quality -= 0.1
            data = scaled.jpegData(compressionQuality: quality)
        }
        task.proofImageData = data
        try? moc.save()
        onProofAttached()
        dismiss()
    }
}

private extension UIImage {
    func scaledToFit(maxDimension: CGFloat) -> UIImage {
        let longEdge = max(size.width, size.height)
        guard longEdge > maxDimension else { return self }
        let scale = maxDimension / longEdge
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
