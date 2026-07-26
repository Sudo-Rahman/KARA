import { beforeEach, describe, expect, test, vi } from 'vitest';

const mocks = vi.hoisted(() => ({
	client: {
		close: vi.fn(),
		connect: vi.fn(),
		destroy: vi.fn(),
		isOpen: false,
		isReady: false,
		on: vi.fn(),
		ping: vi.fn()
	},
	createClient: vi.fn()
}));

vi.mock('redis', () => ({ createClient: mocks.createClient }));

import { RedisConnection } from './redis-connection';

describe('Redis connection lifecycle', () => {
	beforeEach(() => {
		vi.clearAllMocks();
		mocks.client.connect.mockRejectedValue(new Error('connection refused'));
		mocks.createClient.mockReturnValue(mocks.client);
	});

	test('bounds cold-start connection attempts and disables infinite reconnects', async () => {
		const connection = new RedisConnection(
			'redis://127.0.0.1:1',
			{ error: vi.fn(), info: vi.fn() } as never,
			{ unavailable: 'down', recovered: 'back', ready: 'ready' }
		);

		expect(mocks.createClient).toHaveBeenCalledWith({
			url: 'redis://127.0.0.1:1',
			socket: { connectTimeout: 5_000, reconnectStrategy: false }
		});
		await expect(connection.ensureConnected()).rejects.toThrow('connection refused');
	});

	test('destroys and recreates a client when its handshake exceeds the deadline', async () => {
		vi.useFakeTimers();
		mocks.client.connect.mockReturnValue(new Promise(() => {}));

		try {
			const connection = new RedisConnection(
				'redis://cache.example',
				{ error: vi.fn(), info: vi.fn() } as never,
				{ unavailable: 'down', recovered: 'back', ready: 'ready' }
			);
			const connectionAttempt = expect(connection.ensureConnected()).rejects.toThrow(
				'Redis operation exceeded 5000 ms'
			);

			await vi.advanceTimersByTimeAsync(5_000);

			await connectionAttempt;
			expect(mocks.client.destroy).toHaveBeenCalledOnce();
			expect(mocks.createClient).toHaveBeenCalledTimes(2);
		} finally {
			vi.useRealTimers();
		}
	});

	test('applies the same deadline to commands after connection', async () => {
		vi.useFakeTimers();
		mocks.client.isReady = true;
		mocks.client.ping.mockReturnValue(new Promise(() => {}));

		try {
			const connection = new RedisConnection(
				'redis://cache.example',
				{ error: vi.fn(), info: vi.fn() } as never,
				{ unavailable: 'down', recovered: 'back', ready: 'ready' }
			);
			const command = expect(connection.ping()).rejects.toThrow(
				'Redis operation exceeded 5000 ms'
			);

			await vi.advanceTimersByTimeAsync(5_000);

			await command;
			expect(mocks.client.destroy).toHaveBeenCalledOnce();
			expect(mocks.createClient).toHaveBeenCalledTimes(2);
		} finally {
			mocks.client.isReady = false;
			vi.useRealTimers();
		}
	});
});
