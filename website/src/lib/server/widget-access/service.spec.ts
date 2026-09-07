import { describe, expect, it } from 'vitest';
import { WidgetAccessService, type WidgetGrantStore } from './service';

function fixture() {
	const grants = new Map<string, string>();
	const store: WidgetGrantStore = {
		put: async (hash, owner) => { grants.set(hash, owner); },
		renew: async (hash) => grants.get(hash) ?? null
	};
	return { grants, service: new WidgetAccessService(store) };
}
describe('widget access independent of host app', () => {
	it('issues an opaque grant to an attested app and accepts it on later widget refreshes', async () => {
		const { service, grants } = fixture();
		const token = await service.issue('attested-device');
		expect(await service.authenticate(`Bearer ${token}`)).toBe(true);
		expect(await service.authenticate(`Bearer ${token}`)).toBe(true);
		expect([...grants.keys()]).not.toContain(token);
	});
	it('rejects missing, forged and expired credentials', async () => {
		const { service, grants } = fixture();
		const token = await service.issue('attested-device');
		expect(await service.authenticate(null)).toBe(false);
		expect(await service.authenticate(`Bearer ${'a'.repeat(43)}`)).toBe(false);
		grants.clear();
		expect(await service.authenticate(`Bearer ${token}`)).toBe(false);
	});
	it('reuses a grant only for its original attested owner', async () => {
		const { service } = fixture();
		const token = await service.issue('owner');
		expect(await service.issue('owner', token)).toBe(token);
		expect(await service.issue('other-owner', token)).not.toBe(token);
	});
});
