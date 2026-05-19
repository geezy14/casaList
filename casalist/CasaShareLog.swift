import Foundation

/// Appender for the field diagnostic log at
/// `<Documents>/share-log.txt`. The CloudKit event observer, the
/// local-fallback path, the entity-lookup precondition, and the save
/// failure hook all want to write to this file. Without a helper each
/// site reimplements the same FileHandle + write dance (and one of
/// them silently dropped writes when the file didn't exist yet).
///
/// Pure additive utility — no access level change, no ordering
/// change, no sync surface touched. Safe for concurrent appenders
/// (FileHandle.write + a global serial queue).
enum CasaShareLog {
    private static let queue = DispatchQueue(label: "casa.share-log", qos: .utility)

    /// Append `msg` to `share-log.txt` with an ISO8601 timestamp prefix.
    /// Fire-and-forget; failures are silent (this is itself the field
    /// diagnostic — there's no further log to escalate to).
    static func append(_ msg: String) {
        let stamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(stamp)] \(msg)\n"
        queue.async {
            guard
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
                let data = line.data(using: .utf8)
            else { return }
            let url = docs.appendingPathComponent("share-log.txt")
            if FileManager.default.fileExists(atPath: url.path),
               let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                try? handle.write(contentsOf: data)
                try? handle.close()
            } else {
                try? data.write(to: url)
            }
        }
    }
}
