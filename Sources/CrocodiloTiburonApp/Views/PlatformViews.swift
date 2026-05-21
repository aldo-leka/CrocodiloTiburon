import SwiftUI
import PDFKit

struct FilingPDFView: NSViewRepresentable {
    let data: Data
    let accessibilityValue: String

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.setAccessibilityElement(true)
        view.setAccessibilityIdentifier(CTAccessibility.readerPDF)
        view.setAccessibilityValue(accessibilityValue)
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        nsView.document = PDFDocument(data: data)
        nsView.setAccessibilityValue(accessibilityValue)
    }
}
