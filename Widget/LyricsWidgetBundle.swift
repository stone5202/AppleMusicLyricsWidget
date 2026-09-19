import SwiftUI
import WidgetKit

@main
struct LyricsWidgetBundle: WidgetBundle {
    var body: some Widget {
        LyricsWidget()
        LyricsLiveActivity()
    }
}
