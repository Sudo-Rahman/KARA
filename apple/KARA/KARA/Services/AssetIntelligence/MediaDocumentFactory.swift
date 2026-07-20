import Foundation
import PDFKit
import UIKit

nonisolated struct PreparedMediaDocument: Equatable, Sendable {
    let data: Data
    let filename: String
    let mimeType: String
    let pageCount: Int
}

nonisolated enum MediaDocumentError: Error, Equatable, Sendable {
    case invalidImage
    case invalidPDF
    case emptyDocument
    case encodingFailed
}

nonisolated enum MediaDocumentFactory {
    static func normalizedObjectJPEG(
        from data: Data,
        maxPixelDimension: CGFloat = 2_048,
        compressionQuality: CGFloat = 0.86
    ) throws -> Data {
        guard let image = UIImage(data: data) else {
            throw MediaDocumentError.invalidImage
        }
        return try normalizedObjectJPEG(
            from: image,
            maxPixelDimension: maxPixelDimension,
            compressionQuality: compressionQuality
        )
    }

    static func normalizedObjectJPEG(
        from image: UIImage,
        maxPixelDimension: CGFloat = 2_048,
        compressionQuality: CGFloat = 0.86
    ) throws -> Data {
        guard image.size.width > 0, image.size.height > 0,
              maxPixelDimension > 0,
              (0...1).contains(compressionQuality)
        else {
            throw MediaDocumentError.invalidImage
        }

        let scale = min(
            1,
            maxPixelDimension / max(image.size.width, image.size.height)
        )
        let targetSize = CGSize(
            width: max(1, floor(image.size.width * scale)),
            height: max(1, floor(image.size.height * scale))
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        let normalized = UIGraphicsImageRenderer(size: targetSize, format: format).image {
            context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        guard let data = normalized.jpegData(compressionQuality: compressionQuality) else {
            throw MediaDocumentError.encodingFailed
        }
        return data
    }

    static func invoicePDF(
        from images: [UIImage],
        filename: String = "facture.pdf"
    ) throws -> PreparedMediaDocument {
        guard !images.isEmpty else {
            throw MediaDocumentError.emptyDocument
        }

        let document = PDFDocument()
        for (index, image) in images.enumerated() {
            guard image.size.width > 0, image.size.height > 0,
                  let page = PDFPage(image: image)
            else {
                throw MediaDocumentError.invalidImage
            }
            document.insert(page, at: index)
        }

        guard let data = document.dataRepresentation() else {
            throw MediaDocumentError.encodingFailed
        }

        return PreparedMediaDocument(
            data: data,
            filename: pdfFilename(from: filename),
            mimeType: "application/pdf",
            pageCount: document.pageCount
        )
    }

    static func invoicePDF(
        fromImageData imageData: [Data],
        filename: String = "facture.pdf"
    ) throws -> PreparedMediaDocument {
        let images = try imageData.map { data in
            guard let image = UIImage(data: data) else {
                throw MediaDocumentError.invalidImage
            }
            return image
        }
        return try invoicePDF(from: images, filename: filename)
    }

    static func invoiceDocument(
        fromImportedData data: Data,
        filename: String,
        mimeType: String
    ) throws -> PreparedMediaDocument {
        if mimeType.caseInsensitiveCompare("application/pdf") == .orderedSame {
            guard let document = PDFDocument(data: data) else {
                throw MediaDocumentError.invalidPDF
            }
            guard document.pageCount > 0 else {
                throw MediaDocumentError.emptyDocument
            }

            return PreparedMediaDocument(
                data: data,
                filename: pdfFilename(from: filename),
                mimeType: "application/pdf",
                pageCount: document.pageCount
            )
        }

        guard mimeType.lowercased().hasPrefix("image/"),
              let image = UIImage(data: data)
        else {
            throw MediaDocumentError.invalidImage
        }
        return try invoicePDF(from: [image], filename: filename)
    }

    private static func pdfFilename(from filename: String) -> String {
        let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        let usableName = trimmed.isEmpty ? "facture" : trimmed
        let path = usableName as NSString
        if path.pathExtension.caseInsensitiveCompare("pdf") == .orderedSame {
            return usableName
        }
        return path.deletingPathExtension + ".pdf"
    }
}
