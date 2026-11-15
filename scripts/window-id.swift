// Prints the CGWindowID of an on-screen Matte window.
// Pass a window title to match it; otherwise the first window is used.
import CoreGraphics
import Foundation

let title = CommandLine.arguments.dropFirst().first
guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) else { exit(1) }
let windows = info as NSArray as! [[String: Any]]
let match = windows.first { window in
    (window[kCGWindowOwnerName as String] as? String) == "Matte"
        && (title == nil || (window[kCGWindowName as String] as? String) == title)
}
if let id = match?[kCGWindowNumber as String] { print(id) }
