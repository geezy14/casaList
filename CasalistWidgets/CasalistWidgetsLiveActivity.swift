import ActivityKit
import WidgetKit
import SwiftUI

/// Lock-screen / Dynamic Island UI for a Casalist status ping.
///
/// The `StatusPingActivityAttributes` type is defined in
/// `casalist/StatusPingActivityAttributes.swift` in the main app. That
/// file is added to BOTH targets via Xcode → File Inspector → Target
/// Membership so both the main app (which starts/updates activities)
/// and the widget extension (which renders them) see the same type.
@available(iOS 16.2, *)
struct StatusPingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StatusPingActivityAttributes.self) { context in
            // Lock-Screen card
            lockScreen(context: context)
                .activityBackgroundTint(senderTint(for: context.attributes.senderColorHex).opacity(0.18))
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.emoji.isEmpty ? "📣" : context.state.emoji)
                        .font(.title2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.attributes.sender)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(senderTint(for: context.attributes.senderColorHex))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.state.message)
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(2)
                        Spacer()
                        Text(context.state.expiresAt, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Text(context.state.emoji.isEmpty ? "📣" : context.state.emoji)
            } compactTrailing: {
                Text(context.attributes.sender)
                    .lineLimit(1)
                    .font(.system(size: 11, weight: .heavy))
            } minimal: {
                Text(context.state.emoji.isEmpty ? "📣" : context.state.emoji)
            }
            .keylineTint(senderTint(for: context.attributes.senderColorHex))
        }
    }

    @ViewBuilder
    private func lockScreen(context: ActivityViewContext<StatusPingActivityAttributes>) -> some View {
        HStack(spacing: 12) {
            // Sender color stripe
            RoundedRectangle(cornerRadius: 3)
                .fill(senderTint(for: context.attributes.senderColorHex))
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(context.state.emoji.isEmpty ? "📣" : context.state.emoji)
                    Text(context.attributes.sender)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(senderTint(for: context.attributes.senderColorHex))
                    Spacer()
                    Text(context.state.expiresAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(context.state.message)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(3)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }

    /// Decode the Casalist FamilyMember.colorHex (0xRRGGBB) into a
    /// SwiftUI Color so the Live Activity's accent stripe matches the
    /// sender's avatar color in the main app.
    private func senderTint(for hex: Int64) -> Color {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        return Color(red: r, green: g, blue: b)
    }
}

@available(iOS 16.2, *)
extension StatusPingActivityAttributes {
    fileprivate static var preview: StatusPingActivityAttributes {
        StatusPingActivityAttributes(
            sender: "geezy",
            senderColorHex: 0xC97357,
            taskUid: "preview"
        )
    }
}

@available(iOS 16.2, *)
extension StatusPingActivityAttributes.ContentState {
    fileprivate static var onTheWay: StatusPingActivityAttributes.ContentState {
        .init(message: "On my way home", emoji: "🚗", expiresAt: .now.addingTimeInterval(900))
    }

    fileprivate static var atStore: StatusPingActivityAttributes.ContentState {
        .init(message: "At the grocery store -- text me if you need anything", emoji: "🛒", expiresAt: .now.addingTimeInterval(3600))
    }
}

#Preview("Lock Screen", as: .content, using: StatusPingActivityAttributes.preview) {
    StatusPingLiveActivity()
} contentStates: {
    StatusPingActivityAttributes.ContentState.onTheWay
    StatusPingActivityAttributes.ContentState.atStore
}
