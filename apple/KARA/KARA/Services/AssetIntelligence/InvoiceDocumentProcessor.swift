import Foundation
import PDFKit
import UIKit
import Vision

nonisolated struct PreparedInvoiceDocument: Equatable, Sendable {
    let originalPDFData: Data
    let pageCount: Int
    let selectedPageIndices: [Int]
    let extractedText: String
    let renderedPageImages: [Data]
    let ocrText: String
}

nonisolated protocol InvoiceDocumentOCRRecognizing: Sendable {
    func recognizeText(in imageData: Data) async throws -> String
}

nonisolated struct InvoiceDocumentProcessor: Sendable {
    private let ocrRecognizer: any InvoiceDocumentOCRRecognizing
    private let maximumPageCount: Int

    init(
        ocrRecognizer: any InvoiceDocumentOCRRecognizing = VisionInvoiceDocumentOCRRecognizer(),
        maximumPageCount: Int = 6
    ) {
        self.ocrRecognizer = ocrRecognizer
        self.maximumPageCount = max(1, maximumPageCount)
    }

    func prepare(pdfData: Data) async throws -> PreparedInvoiceDocument {
        try Task.checkCancellation()
        guard let document = PDFDocument(data: pdfData) else {
            throw MediaDocumentError.invalidPDF
        }
        guard document.pageCount > 0 else {
            throw MediaDocumentError.emptyDocument
        }

        let pageTexts = (0..<document.pageCount).map {
            document.page(at: $0)?.string ?? ""
        }
        let indices = Self.selectedPageIndices(
            pageTexts: pageTexts,
            maximumPageCount: maximumPageCount
        )

        var renderedImages: [Data] = []
        var recognizedTexts: [String] = []
        renderedImages.reserveCapacity(indices.count)
        recognizedTexts.reserveCapacity(indices.count)

        for index in indices {
            try Task.checkCancellation()
            guard let page = document.page(at: index) else {
                throw MediaDocumentError.invalidPDF
            }
            let rendered = try Self.render(page: page)
            renderedImages.append(rendered)
            recognizedTexts.append(try await ocrRecognizer.recognizeText(in: rendered))
        }

        return PreparedInvoiceDocument(
            originalPDFData: pdfData,
            pageCount: document.pageCount,
            selectedPageIndices: indices,
            extractedText: pageTexts
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n\n"),
            renderedPageImages: renderedImages,
            ocrText: recognizedTexts
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n\n")
        )
    }

    nonisolated static func selectedPageIndices(
        pageTexts: [String],
        maximumPageCount: Int = 6
    ) -> [Int] {
        guard maximumPageCount > 0, !pageTexts.isEmpty else {
            return []
        }

        guard pageTexts.count > maximumPageCount else {
            return Array(pageTexts.indices)
        }

        let hasExtractedText = pageTexts.contains {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        guard hasExtractedText else {
            return boundaryPageIndices(
                pageCount: pageTexts.count,
                maximumPageCount: maximumPageCount
            )
        }

        var selected = Set<Int>()
        selected.insert(pageTexts.startIndex)
        if maximumPageCount > 1 {
            selected.insert(pageTexts.index(before: pageTexts.endIndex))
        }

        let rankedInteriorPages = pageTexts.indices
            .filter { !selected.contains($0) }
            .sorted { lhs, rhs in
                let lhsLength = informativeCharacterCount(in: pageTexts[lhs])
                let rhsLength = informativeCharacterCount(in: pageTexts[rhs])
                return lhsLength == rhsLength ? lhs < rhs : lhsLength > rhsLength
            }

        for index in rankedInteriorPages where selected.count < maximumPageCount {
            selected.insert(index)
        }

        return selected.sorted()
    }

    private nonisolated static func boundaryPageIndices(
        pageCount: Int,
        maximumPageCount: Int
    ) -> [Int] {
        guard pageCount > maximumPageCount else {
            return Array(0..<pageCount)
        }

        let leadingCount = (maximumPageCount + 1) / 2
        let trailingCount = maximumPageCount / 2
        let leading = 0..<leadingCount
        let trailing = (pageCount - trailingCount)..<pageCount
        return Array(Set(leading).union(trailing)).sorted()
    }

    private nonisolated static func informativeCharacterCount(in text: String) -> Int {
        text.unicodeScalars.lazy.filter {
            !CharacterSet.whitespacesAndNewlines.contains($0)
        }.count
    }

    private static func render(page: PDFPage) throws -> Data {
        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else {
            throw MediaDocumentError.invalidPDF
        }

        let maximumDimension: CGFloat = 2_048
        let scale = min(3, maximumDimension / max(bounds.width, bounds.height))
        let targetSize = CGSize(
            width: max(1, floor(bounds.width * scale)),
            height: max(1, floor(bounds.height * scale))
        )
        let image = page.thumbnail(of: targetSize, for: .mediaBox)
        guard let data = image.jpegData(compressionQuality: 0.88) else {
            throw MediaDocumentError.encodingFailed
        }
        return data
    }
}

nonisolated struct VisionInvoiceDocumentOCRRecognizer: InvoiceDocumentOCRRecognizing {
    func recognizeText(in imageData: Data) async throws -> String {
        try Task.checkCancellation()
        var request = RecognizeDocumentsRequest()
        request.textRecognitionOptions.automaticallyDetectLanguage = true
        request.textRecognitionOptions.useLanguageCorrection = true
        let observations = try await request.perform(on: imageData)
        try Task.checkCancellation()
        return observations
            .map(\.document.text.transcript)
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}
