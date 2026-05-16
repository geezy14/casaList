import Foundation
import UIKit

/// On-device-only photo attachments for reminders. Photos are NOT
/// synced via CloudKit — they live in the app's Documents directory
/// keyed by the reminder's UID. Keeps the CloudKit footprint small
/// and lets users attach reference photos (a med bottle, an item to
/// buy, a parking spot) without bloating the shared schema.
///
/// Storage: `<Documents>/reminder-photos/{uid}.jpg` — JPEG @ 0.85
/// quality, downscaled to fit 1600×1600 max so thumbnails stay snappy.
enum ReminderPhotoStore {
    private static var directory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("reminder-photos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func url(for uid: String) -> URL {
        directory.appendingPathComponent("\(uid).jpg")
    }

    static func image(for uid: String) -> UIImage? {
        let path = url(for: uid).path
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        return UIImage(contentsOfFile: path)
    }

    static func hasImage(for uid: String) -> Bool {
        FileManager.default.fileExists(atPath: url(for: uid).path)
    }

    @discardableResult
    static func save(_ image: UIImage, for uid: String) -> Bool {
        let resized = downscale(image, maxDimension: 1600)
        guard let data = resized.jpegData(compressionQuality: 0.85) else { return false }
        do {
            try data.write(to: url(for: uid), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    static func delete(for uid: String) {
        let u = url(for: uid)
        try? FileManager.default.removeItem(at: u)
    }

    /// Proportional downscale so the longest side fits `maxDimension`.
    /// Passes through unchanged if the image is already smaller.
    private static func downscale(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return image }
        let scale = maxDimension / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
