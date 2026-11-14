import SwiftUI

struct CaptionInspector: View {
    @Binding var shot: Shot
    let position: Int
    let style: SetStyle
    let replaceImage: () -> Void

    var body: some View {
        Section {
            field("Headline", text: changed(\.headline), prompt: "Say what it does", lines: 2...4) {
                Menu {
                    let words = Highlight.words(in: shot.headline)
                    if words.isEmpty { Text("Type a headline first") }
                    ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                        let stored = shot.accents.contains { $0.caseInsensitiveCompare(word.text) == .orderedSame }
                        Toggle(word.text, isOn: Binding(get: { word.highlighted || stored }, set: { _ in
                            if word.highlighted {
                                shot.headline = Highlight.toggle(index, in: shot.headline) // Typed *markup*.
                            } else if stored {
                                shot.accents.removeAll { $0.caseInsensitiveCompare(word.text) == .orderedSame }
                            } else {
                                shot.accents.append(word.text)
                            }
                        }))
                    }
                } label: {
                    Label("Highlight", systemImage: "highlighter")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Color words with the theme accent.")
            }
            field("Subtitle", text: changed(\.subtitle), prompt: "Optional supporting line", lines: 1...3) { EmptyView() }
            if !style.layout.hasCaption {
                Label("Captions are saved but hidden in this layout.", systemImage: "eye.slash")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(ShotRenderer.warnings(shot: shot, style: style), id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } header: {
            HStack {
                Text("Shot \(position)")
                Spacer()
                Button(action: replaceImage) { Label("Replace Image", systemImage: "photo.badge.arrow.down") }
                    .buttonStyle(.borderless)
                    .labelStyle(.iconOnly)
                    .help("Replace \(shot.name) with another image")
            }
        }
    }

    /// Writes only real changes. Focusing a vertical text field writes back the same text,
    /// which would otherwise mark a just-opened document as edited.
    private func changed(_ key: WritableKeyPath<Shot, String>) -> Binding<String> {
        Binding(get: { shot[keyPath: key] }, set: { if $0 != shot[keyPath: key] { shot[keyPath: key] = $0 } })
    }

    private func field<Accessory: View>(_ title: String, text: Binding<String>, prompt: String, lines: ClosedRange<Int>,
                                        @ViewBuilder accessory: () -> Accessory) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                Spacer()
                accessory().font(.caption)
            }
            TextField(title, text: text, prompt: Text(verbatim: prompt), axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(lines)
                .labelsHidden()
        }
        .padding(.vertical, 2)
    }
}

/// Word-level accent markup: a word wrapped in *asterisks* takes the accent color.
enum Highlight {
    struct Word { var text: String; var highlighted: Bool }

    private static func split(_ token: Substring) -> (lead: String, core: String, trail: String) {
        let chars = Array(token)
        var start = 0, end = chars.count
        while start < end, !chars[start].isLetter && !chars[start].isNumber && chars[start] != "*" { start += 1 }
        while end > start, !chars[end - 1].isLetter && !chars[end - 1].isNumber && chars[end - 1] != "*" { end -= 1 }
        return (String(chars[..<start]), String(chars[start..<end]), String(chars[end...]))
    }

    static func words(in headline: String) -> [Word] {
        headline.split(separator: " ").compactMap { token in
            let core = split(token).core
            let bare = core.replacingOccurrences(of: "*", with: "")
            guard !bare.isEmpty else { return nil }
            return Word(text: bare, highlighted: core.hasPrefix("*") && core.hasSuffix("*") && core.count > 1)
        }
    }

    /// Wraps or unwraps the word at `index` (counting words as `words(in:)` does).
    static func toggle(_ index: Int, in headline: String) -> String {
        var tokens = headline.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        var wordIndex = -1
        for (i, token) in tokens.enumerated() {
            let parts = split(Substring(token))
            guard !parts.core.replacingOccurrences(of: "*", with: "").isEmpty else { continue }
            wordIndex += 1
            guard wordIndex == index else { continue }
            let bare = parts.core.replacingOccurrences(of: "*", with: "")
            let on = parts.core.hasPrefix("*") && parts.core.hasSuffix("*") && parts.core.count > 1
            tokens[i] = parts.lead + (on ? bare : "*\(bare)*") + parts.trail
            break
        }
        return tokens.joined(separator: " ")
    }
}
