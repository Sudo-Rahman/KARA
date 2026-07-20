export type KaraLocale = 'fr' | 'en';

function intlLocale(locale: KaraLocale): string {
	return locale === 'fr' ? 'fr-FR' : 'en-GB';
}

export function formatCurrency(
	value: number,
	locale: KaraLocale,
	fractionDigits = 0
): string {
	return new Intl.NumberFormat(intlLocale(locale), {
		style: 'currency',
		currency: 'EUR',
		minimumFractionDigits: fractionDigits,
		maximumFractionDigits: fractionDigits
	}).format(value);
}

export function formatNumber(value: number, locale: KaraLocale, fractionDigits = 0): string {
	return new Intl.NumberFormat(intlLocale(locale), {
		minimumFractionDigits: fractionDigits,
		maximumFractionDigits: fractionDigits
	}).format(value);
}

export function formatPercent(value: number, locale: KaraLocale, fractionDigits = 0): string {
	return new Intl.NumberFormat(intlLocale(locale), {
		style: 'percent',
		minimumFractionDigits: fractionDigits,
		maximumFractionDigits: fractionDigits
	}).format(value);
}

export function formatReportDate(locale: KaraLocale): string {
	return new Intl.DateTimeFormat(intlLocale(locale), {
		day: '2-digit',
		month: 'short',
		year: 'numeric',
		timeZone: 'UTC'
	}).format(new Date(Date.UTC(2026, 6, 20)));
}
