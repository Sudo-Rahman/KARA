export interface CanonicalRequestInput {
	challenge: string;
	method: string;
	pathname: string;
	query: string;
	bodySHA256: string;
}

export function normalizeQuery(url: URL): string {
	return [...url.searchParams.entries()]
		.map(([key, value]) => [percentEncode(key), percentEncode(value)] as const)
		.sort(([leftKey, leftValue], [rightKey, rightValue]) =>
			compareASCII(leftKey, rightKey) || compareASCII(leftValue, rightValue)
		)
		.map(([key, value]) => `${key}=${value}`)
		.join('&');
}

function compareASCII(left: string, right: string): number {
	return left < right ? -1 : left > right ? 1 : 0;
}

function percentEncode(value: string): string {
	return encodeURIComponent(value).replace(/[!'()*]/g, (character) =>
		`%${character.charCodeAt(0).toString(16).toUpperCase()}`
	);
}

export function canonicalRequest(input: CanonicalRequestInput): string {
	return [
		'KARA-APP-ATTEST-V1',
		input.challenge,
		input.method.toUpperCase(),
		input.pathname,
		input.query,
		input.bodySHA256.toLowerCase()
	].join('\n');
}
