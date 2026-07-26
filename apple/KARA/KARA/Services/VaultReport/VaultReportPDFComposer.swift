import Foundation
import UIKit

nonisolated enum VaultReportPDFLayout {
    static let pageSize = CGSize(width: 595.28, height: 841.89)
    static let horizontalMargin: CGFloat = 44
    static let topMargin: CGFloat = 34
    static let bottomMargin: CGFloat = 34
    static let headerHeight: CGFloat = 48
    static let footerHeight: CGFloat = 24
    static let contentSpacing: CGFloat = 4
}

private nonisolated enum VaultReportPDFPalette {
    static let page = UIColor.white
    static let text = UIColor(white: 0.10, alpha: 1)
    static let secondaryText = UIColor(white: 0.38, alpha: 1)
    static let card = UIColor(white: 0.95, alpha: 1)
    static let notice = UIColor(white: 0.965, alpha: 1)
    static let separator = UIColor(white: 0.78, alpha: 1)
    static let accent = UIColor(red: 0.55, green: 0.38, blue: 0.12, alpha: 1)
}

nonisolated final class VaultReportPDFComposer {
    private let context: UIGraphicsPDFRendererContext
    private let locale: Locale
    private let generatedAt: Date
    private let pageRect = CGRect(origin: .zero, size: VaultReportPDFLayout.pageSize)
    private var pageNumber = 0
    private var cursorY: CGFloat = 0
    private var continuationTitle: String?

    private var contentLeft: CGFloat { VaultReportPDFLayout.horizontalMargin }
    private var contentWidth: CGFloat {
        pageRect.width - 2 * VaultReportPDFLayout.horizontalMargin
    }
    private var contentTop: CGFloat {
        VaultReportPDFLayout.topMargin + VaultReportPDFLayout.headerHeight
    }
    private var contentBottom: CGFloat {
        pageRect.height - VaultReportPDFLayout.bottomMargin - VaultReportPDFLayout.footerHeight
    }
    private var fullContentHeight: CGFloat { contentBottom - contentTop }
    private var availableHeightAfterPageBreak: CGFloat {
        guard let continuationTitle else { return fullContentHeight }
        return max(
            0,
            fullContentHeight - continuationTitleHeight(continuationTitle) - 12
        )
    }

    init(
        context: UIGraphicsPDFRendererContext,
        locale: Locale,
        generatedAt: Date
    ) {
        self.context = context
        self.locale = locale
        self.generatedAt = generatedAt
    }

    func beginPage() throws {
        try Task.checkCancellation()
        context.beginPage()
        pageNumber += 1
        cursorY = contentTop
        VaultReportPDFPalette.page.setFill()
        context.cgContext.fill(pageRect)
        drawPageChrome()
        if let continuationTitle {
            drawContinuationTitle(continuationTitle)
        }
    }

    func beginAssetPage(_ text: String) throws {
        try Task.checkCancellation()
        continuationTitle = nil
        try beginPage()
        continuationTitle = text
        try drawAssetName(text)
    }

    func endAsset() {
        continuationTitle = nil
    }

    func drawDocumentTitle(_ text: String) throws {
        try Task.checkCancellation()
        try drawFlowingText(
            text,
            font: .systemFont(ofSize: 25, weight: .bold),
            color: VaultReportPDFPalette.text,
            spacingAfter: 20
        )
    }

    func drawAssetName(_ text: String) throws {
        try Task.checkCancellation()
        try drawFlowingText(
            text,
            font: .systemFont(ofSize: 23, weight: .bold),
            color: VaultReportPDFPalette.text,
            spacingAfter: 14
        )
    }

    func drawAssetValuations(_ fields: [VaultReportField]) throws {
        try Task.checkCancellation()
        let availableWidth = (contentWidth - 16) / CGFloat(max(fields.count, 1))
        let valueFont = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        let labelFont = UIFont.systemFont(ofSize: 8.5, weight: .semibold)
        let heights = fields.map { field in
            textHeight(field.label, width: availableWidth, font: labelFont)
                + 4
                + textHeight(field.value, width: availableWidth, font: valueFont)
        }
        let height = max(54, (heights.max() ?? 0) + 20)
        try ensureSpace(height + 14)

        let rect = CGRect(x: contentLeft, y: cursorY, width: contentWidth, height: height)
        VaultReportPDFPalette.card.setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 10).fill()

        for (index, field) in fields.enumerated() {
            try Task.checkCancellation()
            let x = rect.minX + 10 + CGFloat(index) * availableWidth
            draw(
                field.label.uppercased(with: locale),
                in: CGRect(x: x, y: rect.minY + 10, width: availableWidth - 8, height: 18),
                font: labelFont,
                color: VaultReportPDFPalette.secondaryText
            )
            draw(
                field.value,
                in: CGRect(x: x, y: rect.minY + 28, width: availableWidth - 8, height: height - 34),
                font: valueFont,
                color: VaultReportPDFPalette.text
            )
        }
        cursorY = rect.maxY + 14
    }

    func prepareSection(
        title: String,
        firstField: VaultReportField
    ) throws {
        try Task.checkCancellation()
        let titleFont = UIFont.systemFont(ofSize: 12, weight: .bold)
        let titleHeight = textHeight(title, width: contentWidth, font: titleFont) + 16
        let availableForField = max(0, fullContentHeight - titleHeight)
        let fieldHeight = requiredHeight(
            for: firstField,
            availableHeight: availableForField
        )
        try ensureSpace(titleHeight + fieldHeight)
    }

    func prepareAttachment(firstField: VaultReportField) throws {
        try Task.checkCancellation()
        let separatorHeight: CGFloat = 16
        let availableForField = max(0, fullContentHeight - separatorHeight)
        let fieldHeight = requiredHeight(
            for: firstField,
            availableHeight: availableForField
        )
        try ensureSpace(separatorHeight + fieldHeight)
    }

    func drawSectionTitle(_ text: String) throws {
        try Task.checkCancellation()
        let font = UIFont.systemFont(ofSize: 12, weight: .bold)
        let height = textHeight(text, width: contentWidth, font: font)
        try ensureSpace(height + 16)
        cursorY += 8
        draw(
            text.uppercased(with: locale),
            in: CGRect(x: contentLeft, y: cursorY, width: contentWidth, height: height),
            font: font,
            color: VaultReportPDFPalette.accent
        )
        cursorY += height + 8
    }

    func drawField(
        label: String,
        value: String,
        keepWithPrevious: Bool = false
    ) throws {
        try Task.checkCancellation()
        let metrics = fieldMetrics(label: label, value: value)

        if metrics.blockHeight <= contentBottom - cursorY {
            drawCompleteField(label: label, value: value)
            return
        }

        if metrics.blockHeight <= availableHeightAfterPageBreak, !keepWithPrevious {
            try beginPage()
            drawCompleteField(label: label, value: value)
            return
        }

        try ensureSpace(metrics.minimumHeight)
        draw(
            label,
            in: CGRect(
                x: contentLeft,
                y: cursorY,
                width: contentWidth,
                height: metrics.labelHeight
            ),
            font: metrics.labelFont,
            color: VaultReportPDFPalette.secondaryText
        )
        cursorY += metrics.labelHeight + 3
        try drawFlowingText(
            value,
            font: metrics.valueFont,
            color: VaultReportPDFPalette.text,
            spacingAfter: 10
        )
    }

    func drawNotice(_ text: String) throws {
        try Task.checkCancellation()
        let font = UIFont.italicSystemFont(ofSize: 9.5)
        let height = textHeight(text, width: contentWidth - 20, font: font)
        try ensureSpace(height + 24)
        let rect = CGRect(
            x: contentLeft,
            y: cursorY,
            width: contentWidth,
            height: height + 18
        )
        VaultReportPDFPalette.notice.setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 8).fill()
        draw(
            text,
            in: rect.insetBy(dx: 10, dy: 9),
            font: font,
            color: VaultReportPDFPalette.secondaryText
        )
        cursorY = rect.maxY + 6
    }

    func drawSeparator() throws {
        try Task.checkCancellation()
        try ensureSpace(16)
        VaultReportPDFPalette.separator.setStroke()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: contentLeft, y: cursorY + 7))
        path.addLine(to: CGPoint(x: contentLeft + contentWidth, y: cursorY + 7))
        path.lineWidth = 0.5
        path.stroke()
        cursorY += 16
    }

    private func drawPageChrome() {
        draw(
            "KARA",
            in: CGRect(
                x: contentLeft,
                y: VaultReportPDFLayout.topMargin,
                width: 90,
                height: 18
            ),
            font: .systemFont(ofSize: 13, weight: .bold),
            color: VaultReportPDFPalette.accent
        )
        draw(
            VaultReportCopy.title(locale: locale),
            in: CGRect(
                x: contentLeft + 92,
                y: VaultReportPDFLayout.topMargin,
                width: contentWidth - 92,
                height: 18
            ),
            font: .systemFont(ofSize: 10.5, weight: .semibold),
            color: VaultReportPDFPalette.text,
            alignment: .right
        )
        draw(
            VaultFormatters.reportDateTime(generatedAt, locale: locale),
            in: CGRect(
                x: contentLeft,
                y: VaultReportPDFLayout.topMargin + 20,
                width: contentWidth,
                height: 15
            ),
            font: .systemFont(ofSize: 8.5),
            color: VaultReportPDFPalette.secondaryText,
            alignment: .right
        )

        let footerY = pageRect.height - VaultReportPDFLayout.bottomMargin - 14
        draw(
            "\(VaultReportCopy.page(locale: locale)) \(pageNumber)",
            in: CGRect(x: contentLeft, y: footerY, width: contentWidth, height: 14),
            font: .systemFont(ofSize: 8.5),
            color: VaultReportPDFPalette.secondaryText,
            alignment: .right
        )
    }

    private func drawContinuationTitle(_ text: String) {
        let font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        let height = continuationTitleHeight(text)
        draw(
            text,
            in: CGRect(x: contentLeft, y: cursorY, width: contentWidth, height: height),
            font: font,
            color: VaultReportPDFPalette.accent
        )
        cursorY += height + 12
    }

    private func continuationTitleHeight(_ text: String) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        return min(
            textHeight(text, width: contentWidth, font: font),
            2 * lineHeight(for: font)
        )
    }

    private func ensureSpace(_ height: CGFloat) throws {
        try Task.checkCancellation()
        if cursorY + height > contentBottom {
            try beginPage()
        }
    }

    private func requiredHeight(
        for field: VaultReportField,
        availableHeight: CGFloat
    ) -> CGFloat {
        let metrics = fieldMetrics(label: field.label, value: field.value)
        return metrics.blockHeight <= availableHeight
            ? metrics.blockHeight
            : metrics.minimumHeight
    }

    private func fieldMetrics(
        label: String,
        value: String
    ) -> (
        labelFont: UIFont,
        valueFont: UIFont,
        labelHeight: CGFloat,
        valueHeight: CGFloat,
        blockHeight: CGFloat,
        minimumHeight: CGFloat
    ) {
        let labelFont = UIFont.systemFont(ofSize: 9.5, weight: .semibold)
        let valueFont = UIFont.systemFont(ofSize: 11.5, weight: .regular)
        let labelHeight = textHeight(label, width: contentWidth, font: labelFont)
        let valueHeight = textHeight(value, width: contentWidth, font: valueFont)
        let blockHeight = labelHeight
            + 3
            + valueHeight
            + VaultReportPDFLayout.contentSpacing
        return (
            labelFont: labelFont,
            valueFont: valueFont,
            labelHeight: labelHeight,
            valueHeight: valueHeight,
            blockHeight: blockHeight,
            minimumHeight: labelHeight + 3 + lineHeight(for: valueFont)
        )
    }

    private func drawCompleteField(label: String, value: String) {
        let metrics = fieldMetrics(label: label, value: value)
        draw(
            label,
            in: CGRect(
                x: contentLeft,
                y: cursorY,
                width: contentWidth,
                height: metrics.labelHeight
            ),
            font: metrics.labelFont,
            color: VaultReportPDFPalette.secondaryText
        )
        cursorY += metrics.labelHeight + 3
        draw(
            value,
            in: CGRect(
                x: contentLeft,
                y: cursorY,
                width: contentWidth,
                height: metrics.valueHeight
            ),
            font: metrics.valueFont,
            color: VaultReportPDFPalette.text
        )
        cursorY += metrics.valueHeight + VaultReportPDFLayout.contentSpacing
    }

    private func drawFlowingText(
        _ text: String,
        font: UIFont,
        color: UIColor,
        spacingAfter: CGFloat
    ) throws {
        try Task.checkCancellation()
        var remaining = text
        let minimumHeight = lineHeight(for: font)

        while !remaining.isEmpty {
            try Task.checkCancellation()
            if contentBottom - cursorY < minimumHeight {
                try beginPage()
            }
            let availableHeight = contentBottom - cursorY
            let prefixCount = try fittingPrefixCount(
                in: remaining,
                width: contentWidth,
                height: availableHeight,
                font: font
            )
            let count = max(1, prefixCount)
            let prefix = String(remaining.prefix(count))
            let height = min(
                availableHeight,
                textHeight(prefix, width: contentWidth, font: font)
            )
            draw(
                prefix,
                in: CGRect(x: contentLeft, y: cursorY, width: contentWidth, height: height),
                font: font,
                color: color
            )
            cursorY += height
            remaining.removeFirst(count)
            if !remaining.isEmpty {
                try beginPage()
            }
        }
        cursorY += spacingAfter
    }

    private func fittingPrefixCount(
        in text: String,
        width: CGFloat,
        height: CGFloat,
        font: UIFont
    ) throws -> Int {
        try Task.checkCancellation()
        let characters = Array(text)
        guard !characters.isEmpty else { return 0 }

        var low = 1
        var high = characters.count
        var result = 0
        while low <= high {
            try Task.checkCancellation()
            let middle = (low + high) / 2
            let candidate = String(characters.prefix(middle))
            if textHeight(candidate, width: width, font: font) <= height {
                result = middle
                low = middle + 1
            } else {
                high = middle - 1
            }
        }

        guard result > 0, result < characters.count else { return result }
        let preferredLowerBound = max(0, result / 2)
        for index in stride(from: result - 1, through: preferredLowerBound, by: -1)
        where characters[index].isWhitespace {
            return index + 1
        }
        return result
    }

    private func lineHeight(for font: UIFont) -> CGFloat {
        ceil(font.lineHeight)
    }

    private func textHeight(_ text: String, width: CGFloat, font: UIFont) -> CGFloat {
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return max(ceil(rect.height), ceil(font.lineHeight))
    }

    private func draw(
        _ text: String,
        in rect: CGRect,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment = .left
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping
        (text as NSString).draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph,
            ],
            context: nil
        )
    }
}
