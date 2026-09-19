import SwiftUI

@main
struct AppleMusicLyricsWidgetApp: App {
    @State private var monitor = AppleMusicMonitor()

    var body: some Scene {
        WindowGroup {
            ContentView(monitor: monitor)
                .task { monitor.start() }
        }
    }
}
