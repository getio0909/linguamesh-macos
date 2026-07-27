import AppKit
import SwiftUI

@MainActor
public struct NativeTextEditor: NSViewRepresentable {
    @Binding private var text: String
    private let isEditable: Bool
    private let accessibilityLabel: String

    public init(
        text: Binding<String>,
        isEditable: Bool,
        accessibilityLabel: String
    ) {
        _text = text
        self.isEditable = isEditable
        self.accessibilityLabel = accessibilityLabel
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.allowsUndo = isEditable
        textView.usesFindBar = true
        textView.font = NSFont.preferredFont(forTextStyle: .body, options: [:])
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.string = text
        textView.setAccessibilityLabel(accessibilityLabel)
        scrollView.documentView = textView
        return scrollView
    }

    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else {
            return
        }
        context.coordinator.parent = self
        textView.isEditable = isEditable
        textView.setAccessibilityLabel(accessibilityLabel)
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            if isEditable {
                let validRanges = selectedRanges.filter { rangeValue in
                    let range = rangeValue.rangeValue
                    return NSMaxRange(range) <= textView.string.utf16.count
                }
                textView.selectedRanges = validRanges.isEmpty
                    ? [NSValue(range: NSRange(location: textView.string.utf16.count, length: 0))]
                    : validRanges
            } else {
                textView.scrollToEndOfDocument(nil)
            }
        }
    }

    @MainActor
    public final class Coordinator: NSObject, NSTextViewDelegate {
        fileprivate var parent: NativeTextEditor

        fileprivate init(parent: NativeTextEditor) {
            self.parent = parent
        }

        public func textDidChange(_ notification: Notification) {
            guard parent.isEditable,
                  let textView = notification.object as? NSTextView
            else {
                return
            }
            parent.text = textView.string
        }
    }
}
