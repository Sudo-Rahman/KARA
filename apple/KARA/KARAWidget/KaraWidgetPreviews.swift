import WidgetKit

#if DEBUG
#Preview("Market · Small", as: .systemSmall, widget: {
    KARAWidget()
}) {
    KaraWidgetEntry.gallery
}

#Preview("Portfolio · Small", as: .systemSmall, widget: {
    KARAWidget()
}) {
    KaraWidgetEntry.galleryPortfolio
}

#Preview("Panorama · Medium", as: .systemMedium, widget: {
    KARAWidget()
}) {
    KaraWidgetEntry.gallery
}

#Preview("Market · Large", as: .systemLarge, widget: {
    KARAWidget()
}) {
    KaraWidgetEntry.gallery
}

#Preview("Portfolio · Large", as: .systemLarge, widget: {
    KARAWidget()
}) {
    KaraWidgetEntry.gallery
}

#Preview("Portfolio hidden", as: .systemMedium, widget: {
    KARAWidget()
}) {
    KaraWidgetEntry.galleryHidden
}
#endif
