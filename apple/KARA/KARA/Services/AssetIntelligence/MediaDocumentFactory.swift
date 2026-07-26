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
        compressionQuality: CGFloat = 0.86,
        maxByteCount: Int = 4 * 1_024 * 1_024
    ) throws -> Data {
        guard let image = UIImage(data: data) else {
            throw MediaDocumentError.invalidImage
        }
        return try normalizedObjectJPEG(
            from: image,
            maxPixelDimension: maxPixelDimension,
            compressionQuality: compressionQuality,
            maxByteCount: maxByteCount
        )
    }

    static func normalizedObjectJPEG(
        from image: UIImage,
        maxPixelDimension: CGFloat = 2_048,
        compressionQuality: CGFloat = 0.86,
        maxByteCount: Int = 4 * 1_024 * 1_024
    ) throws -> Data {
        guard image.size.width > 0, image.size.height > 0,
              maxPixelDimension > 0,
              (0...1).contains(compressionQuality),
              maxByteCount > 0
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
        var normalized = renderOpaque(image, size: targetSize)
        var lastEncoded: Data?
        let qualities = adaptiveQualities(startingAt: compressionQuality)

        while true {
            for quality in qualities {
                guard let data = normalized.jpegData(compressionQuality: quality) else {
                    throw MediaDocumentError.encodingFailed
                }
                lastEncoded = data
                if data.count <= maxByteCount { return data }
            }

            let largestDimension = max(normalized.size.width, normalized.size.height)
            guard largestDimension > 128, let lastEncoded else {
                throw MediaDocumentError.encodingFailed
            }
            let byteRatio = CGFloat(maxByteCount) / CGFloat(lastEncoded.count)
            let proportionalScale = sqrt(max(0.01, byteRatio)) * 0.92
            let scale = min(0.82, max(0.5, proportionalScale))
            let nextSize = CGSize(
                width: max(128, floor(normalized.size.width * scale)),
                height: max(128, floor(normalized.size.height * scale))
            )
            guard nextSize != normalized.size else {
                throw MediaDocumentError.encodingFailed
            }
            normalized = renderOpaque(normalized, size: nextSize)
        }
    }

    private static func adaptiveQualities(startingAt quality: CGFloat) -> [CGFloat] {
        var qualities = [quality]
        for candidate in [0.78, 0.68, 0.58, 0.48, 0.38] where candidate < quality {
            qualities.append(candidate)
        }
        return qualities
    }

    private static func renderOpaque(_ image: UIImage, size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            image.draw(in: CGRect(origin: .zero, size: size))
        }
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
