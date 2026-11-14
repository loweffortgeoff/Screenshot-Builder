import SwiftUI

@main
struct ScreenshotBuilderApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: ShotDocument()) { file in
            EditorView(document: file.$document)
        }
        .defaultSize(width: 1320, height: 880)
    }
}
