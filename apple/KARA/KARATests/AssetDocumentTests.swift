import Testing
import PDFKit
import UIKit
@testable import KARA

@Suite("Invoice document preparation")
struct AssetDocumentTests {
    @Test("Attachment metadata distinguishes text, images, PDFs and generic files")
    func classifiesAttachmentContentTypes() {
        #expect(AssetAttachmentContentKind(mimeType: "application/pdf") == .pdf)
        #expect(AssetAttachmentContentKind(mimeType: "image/jpeg") == .image)
        #expect(AssetAttachmentContentKind(mimeType: "text/plain") == .text)
        #expect(AssetAttachmentContentKind(mimeType: "application/octet-stream") == .file)
    }

    @Test
    func textDocumentsKeepBoundaryPagesAndRankTheMostInformativePages() {
        let pageTexts = [
            "Cover",
            String(repeating: "A", count: 20),
            String(repeating: "B", count: 80),
            String(repeating: "C", count: 40),
            String(repeating: "D", count: 60),
            String(repeating: "E", count: 10),
            String(repeating: "F", count: 100),
            "Terms",
        ]

        let indices = InvoiceDocumentProcessor.selectedPageIndices(
            pageTexts: pageTexts,
            maximumPageCount: 6
        )

        #expect(indices == [0, 2, 3, 4, 6, 7])
    }

    @Test
    func imageOnlyDocumentsUseTheirFirstAndLastThreePages() {
        let indices = InvoiceDocumentProcessor.selectedPageIndices(
            pageTexts: Array(repeating: "", count: 10),
            maximumPageCount: 6
        )

        #expect(indices == [0, 1, 2, 7, 8, 9])
    }

    @Test
    @MainActor
    func importedPDFKeepsItsOriginalBytes() throws {
        let source = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: 320, height: 480)
        ).pdfData { context in
            context.beginPage()
            "Facture originale".draw(at: CGPoint(x: 24, y: 24), withAttributes: nil)
        }

        let document = try MediaDocumentFactory.invoiceDocument(
            fromImportedData: source,
            filename: "facture-source.pdf",
            mimeType: "application/pdf"
        )

        #expect(document.data == source)
        #expect(document.filename == "facture-source.pdf")
        #expect(document.mimeType == "application/pdf")
        #expect(document.pageCount == 1)
    }

    @Test
    @MainActor
    func scannedImagesBecomeOneMultipagePDF() throws {
        let images = [makeImage(color: .systemYellow), makeImage(color: .systemBlue)]

        let document = try MediaDocumentFactory.invoicePDF(
            from: images,
            filename: "scan"
        )

        #expect(document.filename == "scan.pdf")
        #expect(document.mimeType == "application/pdf")
        #expect(document.pageCount == 2)
        #expect(PDFDocument(data: document.data)?.pageCount == 2)
    }

    @Test
    @MainActor
    func scannedDocumentPreparationCreatesOnePDFWithoutBlockingItsCaller() async throws {
        let pages = [
            ScannedDocumentPage(makeImage(color: .systemYellow)),
            ScannedDocumentPage(makeImage(color: .systemBlue)),
        ]

        let document = try await ScannedDocumentPreparation.prepare(
            pages: pages,
            filename: "scan-asynchrone"
        )

        #expect(document.filename == "scan-asynchrone.pdf")
        #expect(document.mimeType == "application/pdf")
        #expect(document.pageCount == 2)
        #expect(PDFDocument(data: document.data)?.pageCount == 2)
    }

    @Test
    @MainActor
    func objectImagesAreOrientedDownsampledAndEncodedAsJPEG() throws {
        let base = UIGraphicsImageRenderer(
            size: CGSize(width: 1_200, height: 600)
        ).image { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1_200, height: 600))
        }
        let cgImage = try #require(base.cgImage)
        let rotated = UIImage(cgImage: cgImage, scale: 1, orientation: .right)

        let data = try MediaDocumentFactory.normalizedObjectJPEG(
            from: rotated,
            maxPixelDimension: 300,
            compressionQuality: 0.8
        )
        let decoded = try #require(UIImage(data: data))

        #expect(data.starts(with: [0xFF, 0xD8]))
        #expect(decoded.imageOrientation == .up)
        #expect(max(decoded.size.width, decoded.size.height) <= 300.5)
        #expect(decoded.size.height > decoded.size.width)
    }

    @Test
    @MainActor
    func normalizedObjectJPEGAdaptsCompressionToTheUploadLimit() throws {
        let noisyImage = makeHighEntropyImage(pixelDimension: 800)

        let data = try MediaDocumentFactory.normalizedObjectJPEG(
            from: noisyImage,
            maxPixelDimension: 800,
            compressionQuality: 0.9,
            maxByteCount: 100_000
        )

        #expect(data.count <= 100_000)
        #expect(data.starts(with: [0xFF, 0xD8]))
    }

    @Test
    @MainActor
    func importedImagesAreNormalizedToPDF() throws {
        let imageData = try #require(makeImage(color: .systemGreen).pngData())

        let document = try MediaDocumentFactory.invoiceDocument(
            fromImportedData: imageData,
            filename: "facture.png",
            mimeType: "image/png"
        )

        #expect(document.filename == "facture.pdf")
        #expect(document.mimeType == "application/pdf")
        #expect(document.pageCount == 1)
        #expect(document.data != imageData)
        #expect(PDFDocument(data: document.data)?.pageCount == 1)
    }

    @Test
    @MainActor
    func invoicePreparationLimitsUploadToSixPages() throws {
        let source = makeImageOnlyPDF(pageCount: 8)
        let processor = InvoiceDocumentProcessor()

        let prepared = try processor.prepare(pdfData: source)

        #expect(PDFDocument(data: prepared)?.pageCount == 6)
    }

    @Test
    @MainActor
    func shortInvoicePreparationPreservesOriginalBytes() throws {
        let source = makeImageOnlyPDF(pageCount: 2)
        let processor = InvoiceDocumentProcessor()

        let prepared = try processor.prepare(pdfData: source)

        #expect(prepared == source)
    }

    @MainActor
    private func makeImage(color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 120, height: 180)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 120, height: 180))
        }
    }

    @MainActor
    private func makeHighEntropyImage(pixelDimension: Int) -> UIImage {
        var state: UInt64 = 0x4B_41_52_41
        var pixels = [UInt8](repeating: 0, count: pixelDimension * pixelDimension * 4)
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            state = state &* 6_364_136_223_846_793_005 &+ 1
            pixels[offset] = UInt8(truncatingIfNeeded: state >> 24)
            pixels[offset + 1] = UInt8(truncatingIfNeeded: state >> 32)
            pixels[offset + 2] = UInt8(truncatingIfNeeded: state >> 40)
            pixels[offset + 3] = 255
        }
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        let image = CGImage(
            width: pixelDimension,
            height: pixelDimension,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: pixelDimension * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
        return UIImage(cgImage: image)
    }

    @MainActor
    private func makeImageOnlyPDF(pageCount: Int) -> Data {
        UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: 320, height: 480)
        ).pdfData { context in
            for index in 0..<pageCount {
                context.beginPage()
                UIColor(white: CGFloat(index + 1) / CGFloat(pageCount + 1), alpha: 1)
                    .setFill()
                context.cgContext.fill(
                    CGRect(x: 24, y: 24, width: 272, height: 432)
                )
            }
        }
    }
}
