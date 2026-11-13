import Foundation

/// Representative accepted sizes, checked against Apple on 2026-09-07.
enum OutputPreset: String, Codable, CaseIterable, Identifiable {
    case phone69, phone65, phone63, phone61, phone55, pad13, pad129, pad11, mac
    var id: Self { self }
    var title: String {
        switch self {
        case .phone69: "iPhone 6.9-inch"
        case .phone65: "iPhone 6.5-inch"
        case .phone63: "iPhone 6.3-inch"
        case .phone61: "iPhone 6.1-inch"
        case .phone55: "iPhone 5.5-inch"
        case .pad13: "iPad 13-inch"
        case .pad129: "iPad 12.9-inch"
        case .pad11: "iPad 11-inch"
        case .mac: "Mac"
        }
    }
    var size: CGSize {
        switch self {
        case .phone69: CGSize(width: 1320, height: 2868)
        case .phone65: CGSize(width: 1284, height: 2778)
        case .phone63: CGSize(width: 1206, height: 2622)
        case .phone61: CGSize(width: 1170, height: 2532)
        case .phone55: CGSize(width: 1242, height: 2208)
        case .pad13: CGSize(width: 2064, height: 2752)
        case .pad129: CGSize(width: 2048, height: 2732)
        case .pad11: CGSize(width: 1668, height: 2420)
        case .mac: CGSize(width: 2560, height: 1600)
        }
    }
}
