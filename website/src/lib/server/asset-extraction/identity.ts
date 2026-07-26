import { createHmac } from 'node:crypto';

export type PseudonymDomain = 'installation' | 'ip';

export function pseudonymize(secret: Buffer, domain: PseudonymDomain, value: string): string {
	return createHmac('sha256', secret)
		.update(`kara:asset-extraction:${domain}\0`, 'utf8')
		.update(value, 'utf8')
		.digest('hex');
}
