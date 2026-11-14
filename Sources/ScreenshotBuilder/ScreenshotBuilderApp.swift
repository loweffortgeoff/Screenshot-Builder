import SwiftUI

@main
struct ScreenshotBuilderApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: ShotDocument()) { file in
            EditorView(document: file.$document)
        }
        .defaultSize(width: 1440, height: 920)
    }
}
