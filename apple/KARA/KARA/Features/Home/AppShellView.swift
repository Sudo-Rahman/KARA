import SwiftData
import SwiftUI

struct AppShellView: View {
    private let analyzer: any AssetAnalyzing

    init(analyzer: any AssetAnalyzing = AppleAssetAnalysisService()) {
        self.analyzer = analyzer
    }

    var body: some View {
        NavigationStack {
            AssetHomeView(analyzer: analyzer)
        }
    }
}

private struct AssetCreationPresentation: Identifiable {
    let id = UUID()
}

struct AssetHomeView: View {
    @Environment(KaraTheme.self) private var theme
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Asset.createdAt, order: .reverse) private var assets: [Asset]

    private let analyzer: any AssetAnalyzing

    @State private var presentedFlow: AssetCreationPresentation?

    init(analyzer: any AssetAnalyzing) {
        self.analyzer = analyzer
    }

    var body: some View {
        Group {
            if assets.isEmpty {
                emptyState
            } else {
                assetList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("asset.home.navigation-title")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if presentedFlow == nil {
                ToolbarSpacer(.flexible, placement: .bottomBar)

                ToolbarItem(placement: .bottomBar) {
                    Button {
                        presentedFlow = AssetCreationPresentation()
                    } label: {
                        Label("asset.home.add", systemImage: "plus")
                            .labelStyle(.iconOnly)
                            .font(.title3.weight(.semibold))
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel(Text("asset.home.add"))
                    .accessibilityIdentifier("home.add")
                }

                ToolbarSpacer(.flexible, placement: .bottomBar)
            }
        }
        .fullScreenCover(item: $presentedFlow) { _ in
            AssetCreationFlowView(
                state: AssetCreationState(
                    analyzer: analyzer,
                    saver: SwiftDataAssetRepository(modelContext: modelContext)
                )
            )
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("asset.home.empty.title", systemImage: "shippingbox")
                .foregroundStyle(theme.ink)
        } description: {
            Text("asset.home.empty.body")
                .foregroundStyle(theme.muted)
        }
        .accessibilityIdentifier("home.empty")
    }

    private var assetList: some View {
        List {
            Section {
                HStack(alignment: .firstTextBaseline) {
                    Text("asset.home.vault")
                        .font(theme.displayFont(size: 24, relativeTo: .title2))

                    Spacer()

                    Text("asset.home.count \(assets.count)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(theme.muted)
                        .contentTransition(.numericText())
                }
                .listRowBackground(theme.surface)
            }

            Section("asset.home.recent") {
                ForEach(assets) { asset in
                    AssetHomeRow(asset: asset)
                        .listRowBackground(theme.surface)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("home.assets")
    }
}

private struct AssetHomeRow: View {
    @Environment(KaraTheme.self) private var theme

    let asset: Asset

    var body: some View {
        HStack(spacing: KaraSpacing.medium) {
            Image(systemName: symbolName)
                .font(.title3)
                .foregroundStyle(theme.goldBright)
                .frame(width: 42, height: 42)
                .background(theme.gold.opacity(0.12), in: .circle)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                Text(asset.name)
                    .font(.headline)
                    .foregroundStyle(theme.ink)

                Text(categoryKey)
                    .font(.subheadline)
                    .foregroundStyle(theme.muted)
            }

            Spacer(minLength: KaraSpacing.small)

            if asset.quantity > 1 {
                Text("×\(asset.quantity)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(theme.muted)
            }
        }
        .padding(.vertical, KaraSpacing.xSmall)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.asset.\(asset.id.uuidString)")
    }

    private var categoryKey: LocalizedStringKey {
        LocalizedStringKey(asset.category.localizationKey)
    }

    private var symbolName: String {
        switch asset.category {
        case .bar:
            "square.stack.3d.up.fill"
        case .coin:
            "medal.fill"
        case .jewelry:
            "diamond.fill"
        case .custom:
            "shippingbox.fill"
        }
    }
}

#Preview("Empty vault") {
    AppShellView(analyzer: PreviewAssetAnalyzer())
        .environment(KaraTheme())
        .modelContainer(
            for: [Asset.self, AssetAttachment.self, SavedSeller.self, StorageLocation.self],
            inMemory: true
        )
        .preferredColorScheme(.dark)
}

private struct PreviewAssetAnalyzer: AssetAnalyzing {
    func analyzeObjectPhoto(_ data: Data) async throws -> AssetAnalysisSuggestion {
        AssetAnalysisSuggestion()
    }

    func analyzeInvoice(
        _ data: Data,
        filename: String,
        mimeType: String
    ) async throws -> AssetAnalysisSuggestion {
        AssetAnalysisSuggestion()
    }
}
