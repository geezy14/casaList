import SwiftUI
import CoreData
import PhotosUI
import UIKit

struct ProfilePhotoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var moc
    @AppStorage("userName") private var userName: String = ""
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)])
    private var members: FetchedResults<FamilyMember>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Household.createdAt, ascending: true)])
    private var households: FetchedResults<Household>

    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var pickedImage: UIImage? = nil
    @State private var loading: Bool = false

    private var matchingMember: FamilyMember? {
        let trimmed = userName.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return nil }
        return members.first { $0.name.lowercased() == trimmed }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let pickedImage {
                    ImageCropView(inputImage: pickedImage) { data in
                        savePhoto(data)
                        self.pickedImage = nil
                        self.pickerItem = nil
                        dismiss()
                    } onCancel: {
                        self.pickedImage = nil
                        self.pickerItem = nil
                    }
                } else {
                    pickerScreen
                }
            }
            .navigationTitle(pickedImage == nil ? "Profile photo" : "Move and scale")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if pickedImage == nil {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                }
            }
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            loading = true
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let ui = UIImage(data: data) {
                    let resized = downsize(ui, maxDim: 1024)
                    await MainActor.run {
                        pickedImage = resized
                        loading = false
                    }
                } else {
                    await MainActor.run { loading = false }
                }
            }
        }
    }

    private var pickerScreen: some View {
        VStack(spacing: 24) {
            if let data = matchingMember?.photoData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable().scaledToFill()
                    .frame(width: 180, height: 180)
                    .clipShape(Circle())
                    .shadow(radius: 10)
            } else {
                ZStack {
                    Circle().fill(Color(.secondarySystemBackground)).frame(width: 180, height: 180)
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 100))
                        .foregroundStyle(Color.accentColor.opacity(0.6))
                }
            }

            VStack(spacing: 6) {
                Text(userName.isEmpty ? "Your profile" : userName)
                    .font(.system(size: 22, weight: .heavy))
                if userName.isEmpty {
                    Text("Set your name in Settings first").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
                }
            }

            PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                HStack(spacing: 8) {
                    if loading { ProgressView().tint(.white) }
                    Label(matchingMember?.photoData != nil ? "Change photo" : "Choose photo",
                          systemImage: "photo.on.rectangle.angled")
                        .font(.system(size: 16, weight: .heavy))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Capsule().fill(Color.accentColor))
                .foregroundStyle(.white)
            }
            .disabled(userName.trimmingCharacters(in: .whitespaces).isEmpty || loading)

            if matchingMember?.photoData != nil {
                Button(role: .destructive) { removePhoto() } label: {
                    Label("Remove photo", systemImage: "trash")
                        .font(.system(size: 14, weight: .semibold))
                }
            }

            Spacer()
        }
        .padding(20)
    }

    private func downsize(_ image: UIImage, maxDim: CGFloat) -> UIImage {
        let w = image.size.width, h = image.size.height
        let m = max(w, h)
        guard m > maxDim else { return image }
        let scale = maxDim / m
        let newSize = CGSize(width: w * scale, height: h * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private func savePhoto(_ data: Data) {
        if let existing = matchingMember {
            existing.photoData = data
        } else {
            let name = userName.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return }
            let m = FamilyMember(context: moc, name: name, role: "You", photoData: data)
            m.household = households.first
        }
        try? moc.save()
    }

    private func removePhoto() {
        matchingMember?.photoData = nil
        try? moc.save()
    }
}
