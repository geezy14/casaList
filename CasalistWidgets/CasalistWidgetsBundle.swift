import WidgetKit
import SwiftUI

@main
struct CasalistWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayRemindersWidget()
        if #available(iOS 16.2, *) {
            StatusPingLiveActivity()
        }
    }
}
