import { env } from '$env/dynamic/private';
import { logger } from '../logger';
import { RedisConnection } from '../redis-connection';
import { WidgetAccessService, WIDGET_GRANT_TTL_SECONDS } from './service';
let service: WidgetAccessService | undefined;
export function widgetAccessService(): WidgetAccessService {
	if (!service) {
		if (!env.REDIS_URL) throw new Error('REDIS_URL is required');
		const redis = new RedisConnection(env.REDIS_URL, logger, {
			unavailable: 'Widget grant store unavailable', recovered: 'Widget grant store recovered',
			ready: 'Widget grant store ready'
		});
		service = new WidgetAccessService({
			put: async (hash, owner) => {
				await redis.execute(client => client.set(`kara:widget-grant:v1:${hash}`, owner, { EX: WIDGET_GRANT_TTL_SECONDS }));
			},
			// GETEX atomically renews activity without resurrecting expired grants.
			renew: hash => redis.execute(client => client.getEx(`kara:widget-grant:v1:${hash}`, { EX: WIDGET_GRANT_TTL_SECONDS }))
		});
	}
	return service;
}
