import Foundation
import Vision

nonisolated struct PreparedObjectPhotoDocument: Equatable, Sendable {
    let jpegData: Data
    let ocrText: String
    let classifications: [String]
}

nonisolated protocol ObjectPhotoProcessing: Sendable {
    func prepare(jpegData: Data) async throws -> PreparedObjectPhotoDocument
}

nonisolated struct ObjectPhotoProcessor: ObjectPhotoProcessing {
    func prepare(jpegData: Data) async throws -> PreparedObjectPhotoDocument {
        try Task.checkCancellation()

        var documentRequest = RecognizeDocumentsRequest()
        documentRequest.textRecognitionOptions.automaticallyDetectLanguage = true
        documentRequest.textRecognitionOptions.useLanguageCorrection = true
        let documents = try await documentRequest.perform(on: jpegData)

        try Task.checkCancellation()
        let classifications = try await ClassifyImageRequest().perform(on: jpegData)
        try Task.checkCancellation()

        return PreparedObjectPhotoDocument(
            jpegData: jpegData,
            ocrText: documents
                .map(\.document.text.transcript)
                .filter { !$0.isEmpty }
                .joined(separator: "\n"),
            classifications: classifications
                .filter { $0.confidence >= 0.15 }
                .prefix(8)
                .map(\.identifier)
        )
    }
}
