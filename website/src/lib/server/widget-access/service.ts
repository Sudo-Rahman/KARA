import { createHash, randomBytes } from 'node:crypto';

// Read-only market access. Never accepted by App Attest middleware or AI routes.
export const WIDGET_GRANT_TTL_SECONDS = 90 * 24 * 60 * 60;
export interface WidgetGrantStore {
	put(hash: string, owner: string): Promise<void>;
	renew(hash: string): Promise<string | null>;
}
function hashToken(token: string): string {
	return createHash('sha256').update(token).digest('hex');
}
function validToken(token: string): boolean {
	return /^[A-Za-z0-9_-]{43}$/.test(token);
}
export class WidgetAccessService {
	constructor(private readonly store: WidgetGrantStore) {}
	async issue(attestedKeyId: string, existingToken?: string | null): Promise<string> {
		if (!attestedKeyId) throw new Error('An attested app is required');
		if (existingToken && validToken(existingToken) &&
			await this.store.renew(hashToken(existingToken)) === attestedKeyId) return existingToken;
		const token = randomBytes(32).toString('base64url');
		await this.store.put(hashToken(token), attestedKeyId);
		return token;
	}
	async authenticate(authorization: string | null): Promise<boolean> {
		const token = authorization?.match(/^Bearer ([A-Za-z0-9_-]{43})$/)?.[1];
		return token !== undefined && await this.store.renew(hashToken(token)) !== null;
	}
}
