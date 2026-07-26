export const ASSET_CATALOG = [
	['gold-bar-1g', 'Lingotin or 1 g', 'bar', 'gold'],
	['gold-bar-2-5g', 'Lingotin or 2,5 g', 'bar', 'gold'],
	['gold-bar-5g', 'Lingotin or 5 g', 'bar', 'gold'],
	['gold-bar-10g', 'Lingotin or 10 g', 'bar', 'gold'],
	['gold-bar-20g', 'Lingotin or 20 g', 'bar', 'gold'],
	['gold-bar-1oz', 'Lingotin or 1 oz', 'bar', 'gold'],
	['gold-bar-50g', 'Lingotin or 50 g', 'bar', 'gold'],
	['gold-bar-100g', 'Lingot or 100 g', 'bar', 'gold'],
	['gold-bar-250g', 'Lingot or 250 g', 'bar', 'gold'],
	['gold-bar-500g', 'Lingot or 500 g', 'bar', 'gold'],
	['gold-bar-1kg', 'Lingot or 1 kg', 'bar', 'gold'],
	['gold-coin-20-francs-napoleon', '20 Francs Napoléon', 'coin', 'gold'],
	['gold-coin-20-francs-marianne-coq', '20 Francs Marianne Coq', 'coin', 'gold'],
	['gold-coin-sovereign', 'Souverain britannique', 'coin', 'gold'],
	['gold-coin-britannia-1-10oz', 'Britannia or 1/10 oz', 'coin', 'gold'],
	['gold-coin-britannia-1-4oz', 'Britannia or 1/4 oz', 'coin', 'gold'],
	['gold-coin-britannia-1-2oz', 'Britannia or 1/2 oz', 'coin', 'gold'],
	['gold-coin-britannia-1oz', 'Britannia or 1 oz', 'coin', 'gold'],
	['gold-coin-krugerrand-1oz', 'Krugerrand or 1 oz', 'coin', 'gold'],
	['gold-coin-maple-leaf-1oz', 'Maple Leaf or 1 oz', 'coin', 'gold'],
	['gold-coin-american-eagle-1oz', 'American Eagle or 1 oz', 'coin', 'gold'],
	['gold-coin-vienna-philharmonic-1oz', 'Philharmonique de Vienne or 1 oz', 'coin', 'gold'],
	['gold-coin-mexico-50-pesos', '50 Pesos mexicains', 'coin', 'gold'],
	['silver-bar-1oz', 'Lingot argent 1 oz', 'bar', 'silver'],
	['silver-bar-100g', 'Lingot argent 100 g', 'bar', 'silver'],
	['silver-bar-250g', 'Lingot argent 250 g', 'bar', 'silver'],
	['silver-bar-500g', 'Lingot argent 500 g', 'bar', 'silver'],
	['silver-bar-1kg', 'Lingot argent 1 kg', 'bar', 'silver'],
	['silver-coin-britannia-1oz', 'Britannia argent 1 oz', 'coin', 'silver'],
	['silver-coin-maple-leaf-1oz', 'Maple Leaf argent 1 oz', 'coin', 'silver'],
	['silver-coin-american-eagle-1oz', 'American Eagle argent 1 oz', 'coin', 'silver'],
	['silver-coin-vienna-philharmonic-1oz', 'Philharmonique de Vienne argent 1 oz', 'coin', 'silver'],
	['platinum-bar-1oz', 'Lingot platine 1 oz', 'bar', 'platinum'],
	['platinum-bar-100g', 'Lingot platine 100 g', 'bar', 'platinum'],
	['palladium-bar-1oz', 'Lingot palladium 1 oz', 'bar', 'palladium'],
	['jewelry-custom', 'Bijou', 'jewelry', null],
	['asset-custom', 'Autre', 'custom', null]
] as const;

export const ASSET_PRESET_IDS = ASSET_CATALOG.map((entry) => entry[0]) as [
	(typeof ASSET_CATALOG)[number][0],
	...(typeof ASSET_CATALOG)[number][0][]
];

export const ASSET_CATALOG_PROMPT = ASSET_CATALOG
	.map(([id, name, category, metal]) => `${id}: ${name} [${category}, ${metal ?? 'unspecified'}]`)
	.join('\n');

