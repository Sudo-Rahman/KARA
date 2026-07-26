import { describe, expect, test } from 'vitest';

import { createBackendLogger, errorSummary } from './logger';

describe('backend logger', () => {
	test('emits structured JSON and redacts sensitive identifiers defensively', () => {
		let output = '';
		const logger = createBackendLogger({
			destination: { write: (chunk) => { output += chunk; } },
			level: 'info'
		});

		logger.info({
			event: 'test.completed',
			headers: {
				authorization: 'Bearer raw-token',
				'x-api-key': 'raw-api-key'
			},
			keyId: 'raw-app-attest-key',
			requestId: 'safe-request-id'
		}, 'Test event');

		const event = JSON.parse(output);
		expect(event).toMatchObject({
			event: 'test.completed',
			headers: {
				authorization: '[REDACTED]',
				'x-api-key': '[REDACTED]'
			},
			keyId: '[REDACTED]',
			level: 'info',
			msg: 'Test event',
			requestId: 'safe-request-id',
			service: 'kara-backend'
		});
		expect(output).not.toContain('raw-token');
		expect(output).not.toContain('raw-api-key');
		expect(output).not.toContain('raw-app-attest-key');
	});

	test('keeps useful operational diagnostics while ignoring arbitrary error fields', () => {
		const error = Object.assign(new Error('connection failed'), {
			apiKey: 'must-not-be-copied',
			code: 'ECONNREFUSED',
			status: 503
		});

		expect(errorSummary(error)).toEqual({
			code: 'ECONNREFUSED',
			message: 'connection failed',
			name: 'Error',
			status: 503
		});
	});
});
