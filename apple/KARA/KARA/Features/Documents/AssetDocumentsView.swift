import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit
import VisionKit

@MainActor
struct AssetDocumentsView: View {
    private enum LoadState {
        case loading
        case loaded
        case failed
    }

    private enum PresentedSheet: Identifiable {
        case preview(AttachmentPreviewItem)
        case rename(AssetAttachment)

        var id: String {
            switch self {
            case let .preview(item): "preview-\(item.id.uuidString)"
            case let .rename(attachment): "rename-\(attachment.id.uuidString)"
            }
        }
    }

    private struct ScannerRequest: Identifiable {
        let id = UUID()
        let kind: AssetAttachmentKind
    }

    @Environment(KaraTheme.self) private var theme

    let asset: Asset
    private let repository: any AttachmentManaging

    @State private var attachments: [AssetAttachment] = []
    @State private var selectedFilter: AssetDocumentFilter = .all
    @State private var loadState: LoadState = .loading
    @State private var presentedSheet: PresentedSheet?
    @State private var pendingDeletion: AssetAttachment?
    @State private var scannerRequest: ScannerRequest?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var pendingImportKind: AssetAttachmentKind?
    @State private var isFileImporterPresented = false
    @State private var isPerformingOperation = false
    @State private var showsOperationError = false
    @State private var currentPreviewURL: URL?

    init(asset: Asset, repository: any AttachmentManaging) {
        self.asset = asset
        self.repository = repository
    }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            content
                .disabled(isPerformingOperation)

            if isPerformingOperation {
                Color.black.opacity(0.14)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                ProgressView()
                    .controlSize(.large)
                    .padding(KaraSpacing.medium)
                    .background(.regularMaterial, in: .circle)
                    .accessibilityLabel(AssetDocumentsCopy.string("documents.add"))
            }
        }
        .navigationTitle(AssetDocumentsCopy.string("documents.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { addToolbarItem }
        .task(id: asset.id) { loadAttachments() }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task { await addPhoto(from: item) }
        }
        .sheet(item: $presentedSheet, onDismiss: removeTemporaryPreview) { sheet in
            switch sheet {
            case let .preview(item):
                AttachmentPreviewSheet(item: item)
            case let .rename(attachment):
                RenameAssetAttachmentSheet(
                    assetID: asset.id,
                    attachment: attachment,
                    repository: repository,
                    onRenamed: loadAttachments
                )
            }
        }
        .fullScreenCover(item: $scannerRequest) { request in
            DocumentScannerView { images in
                scannerRequest = nil
                addScannedDocument(images, kind: request.kind)
            } onCancel: {
                scannerRequest = nil
            } onFailure: { _ in
                scannerRequest = nil
                showsOperationError = true
            }
            .ignoresSafeArea()
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.pdf, .image],
            allowsMultipleSelection: false,
            onCompletion: importFiles
        )
        .confirmationDialog(
            AssetDocumentsCopy.string("documents.delete.title"),
            isPresented: deletionConfirmationBinding,
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { attachment in
            Button(AssetDocumentsCopy.string("documents.delete.confirm"), role: .destructive) {
                delete(attachment)
            }
            Button(AssetDocumentsCopy.string("documents.cancel"), role: .cancel) {}
        } message: { attachment in
            Text(String.localizedStringWithFormat(
                AssetDocumentsCopy.string("documents.delete.body"),
                attachment.filename
            ))
        }
        .alert(
            AssetDocumentsCopy.string("documents.error.title"),
            isPresented: $showsOperationError
        ) {
            Button(AssetDocumentsCopy.string("documents.close"), role: .cancel) {}
        } message: {
            Text(AssetDocumentsCopy.string("documents.error.operation"))
        }
        .onDisappear(perform: removeTemporaryPreview)
    }

    @ViewBuilder
    private var content: some View {
        switch loadState {
        case .loading:
            loadingContent
        case .failed:
            errorContent
        case .loaded where attachments.isEmpty:
            emptyContent
        case .loaded:
            documentsContent
        }
    }

    private var loadingContent: some View {
        ScrollView {
            VStack(spacing: KaraSpacing.medium) {
                headerCard
                ForEach(0 ..< 3, id: \.self) { _ in
                    KaraCard {
                        HStack(spacing: KaraSpacing.medium) {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(theme.cobalt.opacity(0.18))
                                .frame(width: 72, height: 88)
                            VStack(alignment: .leading, spacing: KaraSpacing.small) {
                                Text("Document sécurisé")
                                Text("PDF · 280 KB")
                            }
                        }
                    }
                }
            }
            .redacted(reason: .placeholder)
            .padding(KaraSpacing.large)
        }
        .accessibilityLabel(AssetDocumentsCopy.string("documents.title"))
    }

    private var errorContent: some View {
        ContentUnavailableView {
            Label(
                AssetDocumentsCopy.string("documents.error.title"),
                systemImage: "exclamationmark.lock.fill"
            )
        } description: {
            Text(AssetDocumentsCopy.string("documents.error.body"))
        } actions: {
            Button(AssetDocumentsCopy.string("documents.error.retry"), action: loadAttachments)
                .buttonStyle(.borderedProminent)
                .tint(theme.cobaltBright)
        }
        .foregroundStyle(theme.ink)
    }

    private var emptyContent: some View {
        VStack(spacing: KaraSpacing.large) {
            headerCard

            ContentUnavailableView {
                Label(
                    AssetDocumentsCopy.string("documents.empty.title"),
                    systemImage: "doc.badge.plus"
                )
            } description: {
                Text(AssetDocumentsCopy.string("documents.empty.body"))
            } actions: {
                Button(AssetDocumentsCopy.string("documents.empty.action")) {
                    beginImport(kind: .other)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.cobaltBright)
            }
            .foregroundStyle(theme.ink)

            Spacer(minLength: KaraSpacing.xxLarge)
        }
        .padding(KaraSpacing.large)
    }

    private var documentsContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: KaraSpacing.large) {
                headerCard

                if filterOptions.count > 2 {
                    filterBar
                }

                ForEach(groupedAttachments, id: \.kind) { group in
                    VStack(alignment: .leading, spacing: KaraSpacing.small) {
                        Text(AssetDocumentsCopy.string(group.kind.documentsLocalizationKey))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.goldBright)
                            .textCase(.uppercase)
                            .padding(.horizontal, KaraSpacing.xSmall)

                        ForEach(group.attachments) { attachment in
                            AssetDocumentRow(
                                attachment: attachment,
                                onOpen: { openPreview(attachment) },
                                onRename: { presentedSheet = .rename(attachment) },
                                onDelete: { pendingDeletion = attachment }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, KaraSpacing.large)
            .padding(.top, KaraSpacing.medium)
            .padding(.bottom, KaraSpacing.xxLarge)
        }
        .scrollEdgeEffectStyle(.hard, for: .top)
    }

    private var headerCard: some View {
        KaraCard {
            HStack(spacing: KaraSpacing.medium) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(theme.cobalt.opacity(0.18))
                    Image(systemName: "archivebox.fill")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(theme.goldBright)
                }
                .frame(width: 58, height: 58)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                    Text(asset.name)
                        .font(theme.displayFont(size: 20, relativeTo: .title3))
                        .foregroundStyle(theme.ink)
                        .lineLimit(2)

                    SensitiveValue {
                        HStack(spacing: KaraSpacing.small) {
                            Text(attachments.count, format: .number)
                                .monospacedDigit()
                            Text(AssetDocumentsCopy.string("documents.count.label"))
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.muted)
                }

                Spacer(minLength: 0)

                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(theme.cobaltBright)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
        }
        .accessibilityIdentifier("documents.header")
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: KaraSpacing.small) {
                ForEach(filterOptions) { filter in
                    Button {
                        withAnimation(.snappy) { selectedFilter = filter }
                    } label: {
                        Text(filterTitle(filter))
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .frame(minHeight: 40)
                            .background(
                                selectedFilter == filter
                                    ? theme.cobaltBright.opacity(0.28)
                                    : theme.surface.opacity(0.72),
                                in: .capsule
                            )
                            .overlay {
                                Capsule()
                                    .stroke(
                                        selectedFilter == filter
                                            ? theme.cobaltBright.opacity(0.72)
                                            : theme.gold.opacity(0.20),
                                        lineWidth: 1
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selectedFilter == filter ? theme.ink : theme.muted)
                    .accessibilityAddTraits(selectedFilter == filter ? .isSelected : [])
                    .accessibilityIdentifier("documents.filter.\(filter.id)")
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var addToolbarItem: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Menu {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(
                        AssetDocumentsCopy.string("documents.add.photo"),
                        systemImage: "photo.badge.plus"
                    )
                }

                Button {
                    beginImport(kind: .invoice)
                } label: {
                    Label(
                        AssetDocumentsCopy.string("documents.add.invoice"),
                        systemImage: "doc.text.fill"
                    )
                }

                Button {
                    beginImport(kind: .certificate)
                } label: {
                    Label(
                        AssetDocumentsCopy.string("documents.add.certificate"),
                        systemImage: "checkmark.seal.fill"
                    )
                }

                Button {
                    beginImport(kind: .other)
                } label: {
                    Label(
                        AssetDocumentsCopy.string("documents.add.other"),
                        systemImage: "doc.badge.plus"
                    )
                }

                if VNDocumentCameraViewController.isSupported {
                    Divider()
                    Button {
                        scannerRequest = ScannerRequest(kind: .other)
                    } label: {
                        Label(
                            AssetDocumentsCopy.string("documents.add.scan"),
                            systemImage: "doc.viewfinder"
                        )
                    }
                }
            } label: {
                Image(systemName: "plus")
                    .accessibilityLabel(AssetDocumentsCopy.string("documents.add"))
            }
        }
    }

    private var filterOptions: [AssetDocumentFilter] {
        AssetDocumentFilter.options(for: attachments)
    }

    private var groupedAttachments: [(kind: AssetAttachmentKind, attachments: [AssetAttachment])] {
        let visible = attachments.filter(selectedFilter.includes)
        return AssetAttachmentKind.allCases.compactMap { kind in
            let matches = visible.filter { $0.kind == kind }
            return matches.isEmpty ? nil : (kind, matches)
        }
    }

    private var deletionConfirmationBinding: Binding<Bool> {
        Binding(
            get: { pendingDeletion != nil },
            set: { isPresented in
                if !isPresented { pendingDeletion = nil }
            }
        )
    }

    private func filterTitle(_ filter: AssetDocumentFilter) -> String {
        switch filter {
        case .all:
            AssetDocumentsCopy.string("documents.filter.all")
        case let .kind(kind):
            AssetDocumentsCopy.string(kind.documentsLocalizationKey)
        }
    }

    private func loadAttachments() {
        do {
            attachments = try repository.attachments(for: asset.id)
            let availableFilters = AssetDocumentFilter.options(for: attachments)
            if !availableFilters.contains(selectedFilter) {
                selectedFilter = .all
            }
            loadState = .loaded
        } catch {
            loadState = .failed
        }
    }

    private func beginImport(kind: AssetAttachmentKind) {
        pendingImportKind = kind
        isFileImporterPresented = true
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        guard let kind = pendingImportKind else { return }
        pendingImportKind = nil
        Task { await addImportedFile(from: result, kind: kind) }
    }

    private func addImportedFile(
        from result: Result<[URL], Error>,
        kind: AssetAttachmentKind
    ) async {
        isPerformingOperation = true
        defer { isPerformingOperation = false }

        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            let payload = try await Task.detached(priority: .userInitiated) {
                let accessed = url.startAccessingSecurityScopedResource()
                defer {
                    if accessed { url.stopAccessingSecurityScopedResource() }
                }

                let values = try url.resourceValues(forKeys: [.contentTypeKey])
                let contentType = values.contentType
                    ?? UTType(filenameExtension: url.pathExtension)
                    ?? .data
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                let prepared = try MediaDocumentFactory.invoiceDocument(
                    fromImportedData: data,
                    filename: url.lastPathComponent,
                    mimeType: contentType.preferredMIMEType ?? "application/octet-stream"
                )
                return AssetAttachmentPayload(
                    kind: kind,
                    filename: prepared.filename,
                    mimeType: prepared.mimeType,
                    pageCount: prepared.pageCount,
                    data: prepared.data
                )
            }.value
            try repository.add(payload, to: asset.id)
            loadAttachments()
        } catch {
            showsOperationError = true
        }
    }

    private func addPhoto(from item: PhotosPickerItem) async {
        isPerformingOperation = true
        defer {
            isPerformingOperation = false
            selectedPhoto = nil
        }

        do {
            guard let source = try await item.loadTransferable(type: Data.self) else {
                throw MediaDocumentError.invalidImage
            }
            let data = try await Task.detached(priority: .userInitiated) {
                try MediaDocumentFactory.normalizedObjectJPEG(from: source)
            }.value
            try repository.add(
                AssetAttachmentPayload(
                    kind: .objectPhoto,
                    filename: AssetDocumentsCopy.string("documents.default.photo-filename"),
                    mimeType: "image/jpeg",
                    pageCount: 1,
                    data: data
                ),
                to: asset.id
            )
            loadAttachments()
        } catch {
            showsOperationError = true
        }
    }

    private func addScannedDocument(_ images: [UIImage], kind: AssetAttachmentKind) {
        let pages = images.map(ScannedDocumentPage.init)
        let filename = AssetDocumentsCopy.string("documents.default.scan-filename")
        isPerformingOperation = true

        Task {
            defer { isPerformingOperation = false }

            do {
                let prepared = try await ScannedDocumentPreparation.prepare(
                    pages: pages,
                    filename: filename
                )
                try repository.add(
                    AssetAttachmentPayload(
                        kind: kind,
                        filename: prepared.filename,
                        mimeType: prepared.mimeType,
                        pageCount: prepared.pageCount,
                        data: prepared.data
                    ),
                    to: asset.id
                )
                loadAttachments()
            } catch is CancellationError {
                return
            } catch {
                showsOperationError = true
            }
        }
    }

    private func openPreview(_ attachment: AssetAttachment) {
        isPerformingOperation = true
        let data = attachment.data
        let filename = attachment.filename
        let mimeType = attachment.mimeType
        let attachmentID = attachment.id

        Task {
            defer { isPerformingOperation = false }
            do {
                removeTemporaryPreview()
                let url = try await Task.detached(priority: .userInitiated) {
                    try TemporaryAttachmentFileStore.write(
                        data: data,
                        filename: filename,
                        mimeType: mimeType
                    )
                }.value
                currentPreviewURL = url
                presentedSheet = .preview(AttachmentPreviewItem(
                    id: attachmentID,
                    title: filename,
                    url: url
                ))
            } catch {
                showsOperationError = true
            }
        }
    }

    private func delete(_ attachment: AssetAttachment) {
        do {
            try repository.delete(attachmentID: attachment.id, for: asset.id)
            pendingDeletion = nil
            loadAttachments()
        } catch {
            showsOperationError = true
        }
    }

    private func removeTemporaryPreview() {
        guard let currentPreviewURL else { return }
        TemporaryAttachmentFileStore.removeFile(at: currentPreviewURL)
        self.currentPreviewURL = nil
    }
}

private struct AssetDocumentRow: View {
    @Environment(KaraTheme.self) private var theme

    let attachment: AssetAttachment
    let onOpen: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        KaraCard(padding: 12) {
            HStack(spacing: KaraSpacing.medium) {
                Button(action: onOpen) {
                    HStack(spacing: KaraSpacing.medium) {
                        thumbnail

                        VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                            Text(attachment.filename)
                                .font(.headline)
                                .foregroundStyle(theme.ink)
                                .lineLimit(2)

                            Text(metadata)
                                .font(.caption)
                                .foregroundStyle(theme.muted)
                                .lineLimit(1)

                            Text(attachment.createdAt, format: .dateTime.day().month(.abbreviated).year())
                                .font(.caption2)
                                .foregroundStyle(theme.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(attachment.filename)
                .accessibilityHint(AssetDocumentsCopy.string("documents.preview.open"))

                Menu {
                    Button(action: onRename) {
                        Label(
                            AssetDocumentsCopy.string("documents.menu.rename"),
                            systemImage: "pencil"
                        )
                    }

                    ShareLink(
                        item: AssetAttachmentTransfer(
                            data: attachment.data,
                            filename: attachment.filename
                        ),
                        preview: SharePreview(
                            attachment.filename,
                            image: Image(systemName: attachment.kind.documentsSymbolName)
                        )
                    ) {
                        Label(
                            AssetDocumentsCopy.string("documents.menu.share"),
                            systemImage: "square.and.arrow.up"
                        )
                    }

                    Divider()

                    Button(role: .destructive, action: onDelete) {
                        Label(
                            AssetDocumentsCopy.string("documents.menu.delete"),
                            systemImage: "trash"
                        )
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                        .contentShape(.circle)
                        .accessibilityLabel(AssetDocumentsCopy.string("documents.menu.more"))
                }
            }
        }
        .accessibilityIdentifier("documents.row.\(attachment.id.uuidString)")
    }

    @ViewBuilder
    private var thumbnail: some View {
        if attachment.kind == .objectPhoto, let image = UIImage(data: attachment.data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 88)
                .clipped()
                .clipShape(.rect(cornerRadius: 14))
                .accessibilityHidden(true)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(theme.cobalt.opacity(0.16))
                Image(systemName: attachment.kind.documentsSymbolName)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(theme.goldBright)
            }
            .frame(width: 72, height: 88)
            .accessibilityHidden(true)
        }
    }

    private var metadata: String {
        var parts: [String] = []
        if let pageCount = attachment.pageCount, pageCount > 1 {
            parts.append("\(pageCount) p.")
        } else {
            parts.append(AssetDocumentsCopy.string(
                AssetAttachmentContentKind(mimeType: attachment.mimeType).localizationKey
            ))
        }
        parts.append(ByteCountFormatter.string(
            fromByteCount: Int64(attachment.data.count),
            countStyle: .file
        ))
        return parts.joined(separator: " · ")
    }
}

private struct RenameAssetAttachmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(KaraTheme.self) private var theme

    let assetID: UUID
    let attachment: AssetAttachment
    let repository: any AttachmentManaging
    let onRenamed: () -> Void

    @State private var filename: String
    @State private var showsError = false

    init(
        assetID: UUID,
        attachment: AssetAttachment,
        repository: any AttachmentManaging,
        onRenamed: @escaping () -> Void
    ) {
        self.assetID = assetID
        self.attachment = attachment
        self.repository = repository
        self.onRenamed = onRenamed
        _filename = State(initialValue: attachment.filename)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: KaraSpacing.large) {
                TextField(AssetDocumentsCopy.string("documents.rename.field"), text: $filename)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(KaraSpacing.medium)
                    .background(theme.surface, in: .rect(cornerRadius: 14))

                if showsError {
                    Label(
                        AssetDocumentsCopy.string("documents.error.operation"),
                        systemImage: "exclamationmark.circle.fill"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.red)
                }

                Spacer()
            }
            .padding(KaraSpacing.large)
            .background(theme.background.ignoresSafeArea())
            .navigationTitle(AssetDocumentsCopy.string("documents.rename.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AssetDocumentsCopy.string("documents.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(AssetDocumentsCopy.string("documents.rename.save"), action: save)
                        .disabled(filename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.height(260)])
    }

    private func save() {
        do {
            try repository.rename(
                attachmentID: attachment.id,
                for: assetID,
                to: filename
            )
            onRenamed()
            dismiss()
        } catch {
            showsError = true
        }
    }
}

#if DEBUG
@MainActor
private final class PreviewAttachmentRepository: AttachmentManaging {
    private var values: [AssetAttachment]

    init(values: [AssetAttachment]) {
        self.values = values
    }

    func attachments(for assetID: UUID) throws -> [AssetAttachment] {
        values.filter { $0.assetID == assetID }
    }

    func add(_ payload: AssetAttachmentPayload, to assetID: UUID) throws -> AssetAttachment {
        let attachment = AssetAttachment(
            assetID: assetID,
            kind: payload.kind,
            filename: payload.filename,
            mimeType: payload.mimeType,
            pageCount: payload.pageCount,
            data: payload.data
        )
        values.append(attachment)
        return attachment
    }

    func rename(attachmentID: UUID, for assetID: UUID, to filename: String) throws -> AssetAttachment {
        guard let attachment = values.first(where: {
            $0.id == attachmentID && $0.assetID == assetID
        }) else {
            throw AssetRepositoryError.attachmentNotFound(attachmentID)
        }
        attachment.filename = filename
        return attachment
    }

    func delete(attachmentID: UUID, for assetID: UUID) throws {
        values.removeAll { $0.id == attachmentID && $0.assetID == assetID }
    }
}

#Preview("Documents linked to an asset") {
    let asset = Asset(name: "Lingotin 20 g CPOR", category: .bar)
    let repository = PreviewAttachmentRepository(values: [
        AssetAttachment(
            assetID: asset.id,
            kind: .invoice,
            filename: "Facture d’achat.pdf",
            mimeType: "application/pdf",
            pageCount: 1,
            data: Data(repeating: 0, count: 258_000)
        ),
        AssetAttachment(
            assetID: asset.id,
            kind: .certificate,
            filename: "Certificat CPOR.pdf",
            mimeType: "application/pdf",
            pageCount: 1,
            data: Data(repeating: 0, count: 342_000)
        ),
        AssetAttachment(
            assetID: asset.id,
            kind: .objectPhoto,
            filename: "Photo du lingotin.jpg",
            mimeType: "image/jpeg",
            pageCount: 1,
            data: Data()
        ),
    ])

    NavigationStack {
        AssetDocumentsView(asset: asset, repository: repository)
    }
    .environment(KaraTheme())
    .preferredColorScheme(.dark)
}
#endif
