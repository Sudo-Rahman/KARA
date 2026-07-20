import { describe, expect, test } from 'vitest';

import { goldApiKeyFromEnvironment } from './config';

describe('Gold API runtime configuration', () => {
	test('reads and trims GOLD_API_KEY from the runtime environment', () => {
		expect(goldApiKeyFromEnvironment({ GOLD_API_KEY: '  runtime-secret  ' })).toBe(
			'runtime-secret'
		);
	});

	test.each([{}, { GOLD_API_KEY: '' }, { GOLD_API_KEY: '   ' }])(
		'rejects a missing GOLD_API_KEY',
		(environment) => {
			expect(() => goldApiKeyFromEnvironment(environment)).toThrow('GOLD_API_KEY is required');
		}
	);
});
