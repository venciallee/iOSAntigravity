import SwiftUI
#if canImport(WidgetKit) && canImport(ActivityKit)
import WidgetKit
import ActivityKit

@main
struct AntigravityLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        AntigravityLiveActivityWidget()
    }
}
#endif
