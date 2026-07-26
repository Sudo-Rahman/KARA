import Foundation
import PDFKit

nonisolated struct InvoiceDocumentProcessor: Sendable {
    private let maximumPageCount: Int

    init(maximumPageCount: Int = 6) {
        self.maximumPageCount = max(1, maximumPageCount)
    }

    func prepare(pdfData: Data) throws -> Data {
        guard let document = PDFDocument(data: pdfData) else {
            throw MediaDocumentError.invalidPDF
        }
        guard document.pageCount > 0 else {
            throw MediaDocumentError.emptyDocument
        }
        guard document.pageCount > maximumPageCount else {
            return pdfData
        }

        let pageTexts = (0..<document.pageCount).map {
            document.page(at: $0)?.string ?? ""
        }
        let selectedIndices = Self.selectedPageIndices(
            pageTexts: pageTexts,
            maximumPageCount: maximumPageCount
        )
        let analysisDocument = PDFDocument()
        for (destinationIndex, sourceIndex) in selectedIndices.enumerated() {
            guard let page = document.page(at: sourceIndex)?.copy() as? PDFPage else {
                throw MediaDocumentError.invalidPDF
            }
            analysisDocument.insert(page, at: destinationIndex)
        }
        guard analysisDocument.pageCount == selectedIndices.count,
              let data = analysisDocument.dataRepresentation()
        else {
            throw MediaDocumentError.encodingFailed
        }
        return data
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
}
