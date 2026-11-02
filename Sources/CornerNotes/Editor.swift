import SwiftUI
import AppKit

// MARK: - EditorView
struct EditorView: NSViewRepresentable {
    @ObservedObject var store: Store

    func makeNSView(context: Context) -> NSScrollView {
        let tv = BlockTextView()
        BlockTextView.current = tv
        tv.delegate = context.coordinator
        tv.store = store
        tv.font = NSFont.systemFont(ofSize: 14)
        tv.textColor = NSColor.labelColor
        tv.backgroundColor = .clear
        tv.drawsBackground = false
        tv.isRichText = false
        tv.allowsUndo = true
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.textContainer?.lineFragmentPadding = 0
        tv.textContainerInset = NSSize(width: 0, height: 0)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        let para = NSMutableParagraphStyle()
        para.minimumLineHeight = 20
        para.maximumLineHeight = 20
        para.paragraphSpacing = 2
        tv.defaultParagraphStyle = para
        tv.typingAttributes = [.font: NSFont.systemFont(ofSize: 14), .paragraphStyle: para, .foregroundColor: NSColor.labelColor]
        tv.textStorage?.setAttributedString(store.blocksToAttributedString())
        context.coordinator.lastSyncedText = tv.string

        let scroll = NSScrollView()
        scroll.documentView = tv
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.backgroundColor = .clear
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let tv = nsView.documentView as? BlockTextView else { return }
        let newText = store.blocksToAttributedString()
        if newText.string != context.coordinator.lastSyncedText && !tv.hasFocus {
            tv.textStorage?.setAttributedString(newText)
            context.coordinator.lastSyncedText = newText.string
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        let store: Store
        var lastSyncedText: String = ""
        init(store: Store) { self.store = store }

        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            guard let tv = textView as? BlockTextView else { return true }
            let str = tv.string as NSString
            if replacementString == " " {
                let loc = affectedCharRange.location
                if loc > 0 && loc <= str.length {
                    let prevChar = str.character(at: loc - 1)
                    if prevChar == unichar(45) {
                        let lineRange = str.lineRange(for: NSRange(location: loc - 1, length: 0))
                        let before = str.substring(with: NSRange(location: lineRange.location, length: loc - 1 - lineRange.location))
                        if before.trimmingCharacters(in: .whitespaces).isEmpty {
                            tv.replaceCharacters(in: NSRange(location: loc - 1, length: 1), with: "•")
                            return true
                        }
                    }
                }
            }
            return true
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? BlockTextView else { return }
            let attr = tv.attributedString()
            store.state.blocks = attributedTextToBlocks(attr)
            store.scheduleSave()
            lastSyncedText = tv.string
        }
    }
}

// MARK: - BlockTextView
class BlockTextView: NSTextView {
    static weak var current: BlockTextView?
    var hasFocus: Bool { window?.firstResponder === self }
    weak var store: Store?

    override func insertNewline(_ sender: Any?) {
        let str = string as NSString
        let sel = selectedRange()
        let lineRange = str.lineRange(for: NSRange(location: sel.location, length: 0))
        var tabs = 0
        var i = lineRange.location
        while i < lineRange.location + lineRange.length && str.character(at: i) == 9 { tabs += 1; i += 1 }
        var isBullet = false
        if i < lineRange.location + lineRange.length {
            if i + 2 <= str.length {
                let m = str.substring(with: NSRange(location: i, length: 2))
                if m == "• " { isBullet = true; i += 2 }
            }
        }
        let contentAfter = str.substring(with: NSRange(location: i, length: lineRange.location + lineRange.length - i)).trimmingCharacters(in: .whitespacesAndNewlines)
        let isEmpty = contentAfter.isEmpty
        if isEmpty && isBullet {
            let markerStart = lineRange.location + tabs
            replaceCharacters(in: NSRange(location: markerStart, length: i - markerStart), with: "")
            return
        }
        let insert = NSMutableAttributedString()
        insert.append(NSAttributedString(string: "\n" + String(repeating: "\t", count: tabs)))
        if isBullet {
            insert.append(NSAttributedString(string: "• "))
        }
        if let ts = textStorage {
            ts.insert(insert, at: sel.location)
            setSelectedRange(NSRange(location: sel.location + insert.length, length: 0))
        }
    }

    override func deleteBackward(_ sender: Any?) {
        let str = string as NSString
        let sel = selectedRange()
        if sel.length == 0 && sel.location > 0 {
            let lineRange = str.lineRange(for: NSRange(location: sel.location, length: 0))
            var i = lineRange.location
            while i < lineRange.location + lineRange.length && str.character(at: i) == 9 { i += 1 }
            if i + 2 <= str.length {
                let m = str.substring(with: NSRange(location: i, length: 2))
                if m == "• " && sel.location == i + 2 {
                    replaceCharacters(in: NSRange(location: i, length: 2), with: "")
                    return
                }
            }
        }
        super.deleteBackward(sender)
    }

    override func keyDown(with event: NSEvent) {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if mods == .command, event.charactersIgnoringModifiers?.lowercased() == "s" {
            applyStrikethroughToSelection()
            return
        }
        if event.keyCode == 48 {
            if mods.contains(.shift) {
                outdentCurrentLine()
            } else {
                indentCurrentLine()
            }
            return
        }
        super.keyDown(with: event)
    }

    private func applyStrikethroughToSelection() {
        let range = selectedRange()
        guard range.length > 0 else { return }
        textStorage?.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        store?.state.blocks = attributedTextToBlocks(attributedString())
        store?.scheduleSave()
    }

    private func indentCurrentLine() {
        let sel = selectedRange()
        let str = string as NSString
        let lineRange = str.lineRange(for: NSRange(location: sel.location, length: 0))
        var i = lineRange.location
        var tabs = 0
        while i < lineRange.location + lineRange.length && str.character(at: i) == 9 { i += 1; tabs += 1 }
        if tabs < 4 {
            insertText("\t", replacementRange: NSRange(location: lineRange.location, length: 0))
        }
    }

    private func outdentCurrentLine() {
        let sel = selectedRange()
        let str = string as NSString
        let lineRange = str.lineRange(for: NSRange(location: sel.location, length: 0))
        var i = lineRange.location
        if i < str.length && str.character(at: i) == 9 {
            replaceCharacters(in: NSRange(location: i, length: 1), with: "")
        }
    }
}

// MARK: - Store helpers
extension Store {
    func blocksToAttributedString() -> NSAttributedString {
        let para = NSMutableParagraphStyle()
        para.minimumLineHeight = 20
        para.maximumLineHeight = 20
        para.paragraphSpacing = 2
        let result = NSMutableAttributedString()
        for (idx, block) in state.blocks.enumerated() {
            if idx > 0 { result.append(NSAttributedString(string: "\n")) }
            result.append(NSAttributedString(string: String(repeating: "\t", count: block.indent)))
            switch block.kind {
            case .paragraph: break
            case .bullet:
                result.append(NSAttributedString(string: "• "))
            }
            let textAttr = NSMutableAttributedString(string: block.text)
            for range in block.strikethroughRanges {
                let safeStart = max(0, min(range.location, textAttr.length))
                let safeLength = max(0, min(range.length, textAttr.length - safeStart))
                guard safeLength > 0 else { continue }
                textAttr.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: safeStart, length: safeLength))
            }
            result.append(textAttr)
        }
        if result.length == 0 {
            result.append(NSAttributedString(string: ""))
        }
        result.addAttribute(.paragraphStyle, value: para, range: NSRange(location: 0, length: result.length))
        result.addAttribute(.font, value: NSFont.systemFont(ofSize: 14), range: NSRange(location: 0, length: result.length))
        return result
    }
}

func attributedTextToBlocks(_ attr: NSAttributedString) -> [Block] {
    var blocks: [Block] = []
    let nsStr = attr.string as NSString
    let lines = attr.string.components(separatedBy: "\n")
    var offset = 0
    for line in lines {
        let lineLen = (line as NSString).length
        let r = NSRange(location: offset, length: lineLen)
        var i = r.location
        var tabs = 0
        while i < r.location + r.length && nsStr.character(at: i) == 9 { tabs += 1; i += 1 }
        var kind: BlockKind = .paragraph
        var textStart = i
        let remaining = nsStr.substring(with: NSRange(location: i, length: r.location + r.length - i))
        if remaining.hasPrefix("• ") {
            kind = .bullet
            i += 2
            textStart = i
        } else if remaining.hasPrefix("- ") {
            kind = .bullet
            i += 2
            textStart = i
        }
        let text = nsStr.substring(with: NSRange(location: textStart, length: r.location + r.length - textStart))
        let textRange = NSRange(location: textStart, length: (text as NSString).length)
        var strikethroughRanges: [TextRange] = []
        attr.enumerateAttribute(.strikethroughStyle, in: textRange) { value, range, _ in
            guard let style = value as? Int, style != 0 else { return }
            strikethroughRanges.append(TextRange(location: range.location - textStart, length: range.length))
        }
        blocks.append(Block(kind: kind, text: text, indent: tabs, strikethroughRanges: strikethroughRanges))
        offset += lineLen + 1
    }
    if blocks.isEmpty { blocks.append(Block(kind: .paragraph, text: "")) }
    return blocks
}
