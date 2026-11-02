import SwiftUI
import AppKit

// MARK: - checkbox attachment
func checkboxAttachment(done: Bool) -> NSTextAttachment {
    let att = NSTextAttachment()
    let sym = done ? "checkmark.circle.fill" : "circle"
    if let img = NSImage(systemSymbolName: sym, accessibilityDescription: nil) {
        let size = NSSize(width: 16, height: 16)
        let resized = NSImage(size: size)
        resized.lockFocus()
        let imgSize = img.size
        let scale = min(size.width / imgSize.width, size.height / imgSize.height)
        let drawW = imgSize.width * scale
        let drawH = imgSize.height * scale
        let drawRect = NSRect(x: (size.width - drawW) / 2, y: (size.height - drawH) / 2, width: drawW, height: drawH)
        img.draw(in: drawRect)
        resized.unlockFocus()
        att.image = resized
        att.bounds = NSRect(x: 0, y: -4, width: 16, height: 16)
    }
    return att
}

// MARK: - EditorView
struct EditorView: NSViewRepresentable {
    @ObservedObject var store: Store

    func makeNSView(context: Context) -> NSScrollView {
        let tv = BlockTextView()
        BlockTextView.current = tv
        tv.delegate = context.coordinator
        tv.store = store
        tv.font = NSFont.systemFont(ofSize: 14)
        let para = NSMutableParagraphStyle()
        para.minimumLineHeight = 18
        para.lineSpacing = 3
        para.paragraphSpacing = 2
        tv.defaultParagraphStyle = para
        tv.typingAttributes = [.font: NSFont.systemFont(ofSize: 14), .paragraphStyle: para, .foregroundColor: NSColor.labelColor]
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

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let index = characterIndexForInsertion(at: point)
        let str = string as NSString
        let attr = attributedString()
        // Determine if click is on a task attachment
        var targetIndex = index
        if targetIndex >= str.length && str.length > 0 { targetIndex = str.length - 1 }
        if targetIndex >= 0 && targetIndex < str.length && str.character(at: targetIndex) == 0xFFFC {
            let currentDone = (attr.attribute(NSAttributedString.Key("TaskDone"), at: targetIndex, effectiveRange: nil) as? Bool) ?? false
            let newDone = !currentDone
            let newAtt = checkboxAttachment(done: newDone)
            let a = NSMutableAttributedString(attachment: newAtt)
            a.addAttribute(NSAttributedString.Key("TaskDone"), value: newDone, range: NSRange(location: 0, length: 1))
            replaceCharacters(in: NSRange(location: targetIndex, length: 1), with: "")
            insertText(a, replacementRange: NSRange(location: targetIndex, length: 0))
            applyTaskTextAttributes(start: targetIndex + 2, done: newDone)
            return
        }
        // also check previous char if click at boundary
        if targetIndex > 0 && targetIndex - 1 < str.length && str.character(at: targetIndex - 1) == 0xFFFC {
            let idx = targetIndex - 1
            let currentDone = (attr.attribute(NSAttributedString.Key("TaskDone"), at: idx, effectiveRange: nil) as? Bool) ?? false
            let newDone = !currentDone
            let newAtt = checkboxAttachment(done: newDone)
            let a = NSMutableAttributedString(attachment: newAtt)
            a.addAttribute(NSAttributedString.Key("TaskDone"), value: newDone, range: NSRange(location: 0, length: 1))
            replaceCharacters(in: NSRange(location: idx, length: 1), with: "")
            insertText(a, replacementRange: NSRange(location: idx, length: 0))
            applyTaskTextAttributes(start: idx + 2, done: newDone)
            return
        }
        super.mouseDown(with: event)
    }

    override func insertNewline(_ sender: Any?) {
        let str = string as NSString
        let sel = selectedRange()
        let lineRange = str.lineRange(for: NSRange(location: sel.location, length: 0))
        var tabs = 0
        var i = lineRange.location
        while i < lineRange.location + lineRange.length && str.character(at: i) == 9 { tabs += 1; i += 1 }
        var isBullet = false
        var isTask = false
        var taskDone = false
        if i < lineRange.location + lineRange.length {
            let c = str.character(at: i)
            if c == 0xFFFC {
                isTask = true
                if let d = textStorage?.attribute(NSAttributedString.Key("TaskDone"), at: i, effectiveRange: nil) as? Bool { taskDone = d }
                i += 1
                if i < lineRange.location + lineRange.length && str.character(at: i) == 32 { i += 1 }
            } else if i + 2 <= str.length {
                let m = str.substring(with: NSRange(location: i, length: 2))
                if m == "• " { isBullet = true; i += 2 }
            }
        }
        let contentAfter = str.substring(with: NSRange(location: i, length: lineRange.location + lineRange.length - i)).trimmingCharacters(in: .whitespacesAndNewlines)
        let isEmpty = contentAfter.isEmpty
        if isEmpty && (isBullet || isTask) {
            let markerStart = lineRange.location + tabs
            replaceCharacters(in: NSRange(location: markerStart, length: i - markerStart), with: "")
            return
        }
        let insert = NSMutableAttributedString()
        insert.append(NSAttributedString(string: "\n" + String(repeating: "\t", count: tabs)))
        if isBullet {
            insert.append(NSAttributedString(string: "• "))
        } else if isTask {
            let att = checkboxAttachment(done: taskDone)
            let a = NSMutableAttributedString(attachment: att)
            a.addAttribute(NSAttributedString.Key("TaskDone"), value: taskDone, range: NSRange(location: 0, length: 1))
            insert.append(a)
            insert.append(NSAttributedString(string: " "))
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
            if i < str.length && str.character(at: i) == 0xFFFC {
                let markerEnd = i + 2
                if sel.location == markerEnd {
                    replaceCharacters(in: NSRange(location: i, length: 2), with: "")
                    return
                }
            } else if i + 2 <= str.length {
                let m = str.substring(with: NSRange(location: i, length: 2))
                if m == "• " && sel.location == i + 2 {
                    replaceCharacters(in: NSRange(location: i, length: 2), with: "")
                    return
                }
            }
        }
        super.deleteBackward(sender)
    }

    private func applyTaskTextAttributes(start: Int, done: Bool) {
        let str = string as NSString
        let lineRange = str.lineRange(for: NSRange(location: start, length: 0))
        let end = lineRange.location + lineRange.length
        var len = end - start
        if len > 0 && start + len <= str.length && str.character(at: start + len - 1) == 10 { len -= 1 }
        guard len > 0 else { return }
        let r = NSRange(location: start, length: len)
        if done {
            textStorage?.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: r)
            textStorage?.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: r)
        } else {
            textStorage?.removeAttribute(.strikethroughStyle, range: r)
            textStorage?.addAttribute(.foregroundColor, value: NSColor.labelColor, range: r)
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 48 {
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if mods.contains(.shift) {
                outdentCurrentLine()
            } else {
                indentCurrentLine()
            }
            return
        }
        super.keyDown(with: event)
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
        para.minimumLineHeight = 18
        para.lineSpacing = 3
        para.paragraphSpacing = 2
        let result = NSMutableAttributedString()
        for (idx, block) in state.blocks.enumerated() {
            if idx > 0 { result.append(NSAttributedString(string: "\n")) }
            result.append(NSAttributedString(string: String(repeating: "\t", count: block.indent)))
            switch block.kind {
            case .paragraph: break
            case .bullet:
                result.append(NSAttributedString(string: "• "))
            case .task:
                let att = checkboxAttachment(done: block.done)
                let a = NSMutableAttributedString(attachment: att)
                a.addAttribute(NSAttributedString.Key("TaskDone"), value: block.done, range: NSRange(location: 0, length: 1))
                result.append(a)
                result.append(NSAttributedString(string: " "))
            }
            let textAttr = NSMutableAttributedString(string: block.text)
            if block.kind == .task && block.done {
                textAttr.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: textAttr.length))
                textAttr.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: NSRange(location: 0, length: textAttr.length))
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
    let lines = attr.string.components(separatedBy: "\\n")
    // compute offsets
    var offset = 0
    for line in lines {
        let lineLen = (line as NSString).length
        let r = NSRange(location: offset, length: lineLen)
        var i = r.location
        var tabs = 0
        while i < r.location + r.length && nsStr.character(at: i) == 9 { tabs += 1; i += 1 }
        var kind: BlockKind = .paragraph
        var done = false
        var textStart = i
        if i < r.location + r.length && nsStr.character(at: i) == 0xFFFC {
            kind = .task
            if let d = attr.attribute(NSAttributedString.Key("TaskDone"), at: i, effectiveRange: nil) as? Bool { done = d }
            i += 1
            if i < r.location + r.length && nsStr.character(at: i) == 32 { i += 1 }
            textStart = i
        } else {
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
        }
        let text = nsStr.substring(with: NSRange(location: textStart, length: r.location + r.length - textStart))
        blocks.append(Block(kind: kind, text: text, done: done, indent: tabs))
        offset += lineLen + 1
    }
    if blocks.isEmpty { blocks.append(Block(kind: .paragraph, text: "", done: false, indent: 0)) }
    return blocks
}