import { ASSET_CATALOG } from './catalog.generated';

export { ASSET_CATALOG, ASSET_PRESET_COMPATIBILITY } from './catalog.generated';

export const ASSET_PRESET_IDS = ASSET_CATALOG.map((entry) => entry.id) as [
	(typeof ASSET_CATALOG)[number]['id'],
	...(typeof ASSET_CATALOG)[number]['id'][]
];

export const ASSET_CATALOG_PROMPT = ASSET_CATALOG
	.map((entry) => {
		const specifications = [
			entry.weightGrams === null ? null : `${entry.weightGrams} g`,
			entry.metalKarat === null ? null : `${entry.metalKarat} karat`,
			entry.finenessPermille === null ? null : `${entry.finenessPermille}‰`
		].filter(Boolean).join(', ');
		return `${entry.id}: ${entry.name} [${entry.category}, ${entry.metal ?? 'unspecified'}${
			specifications ? `, ${specifications}` : ''
		}]`;
	})
	.join('\n');
