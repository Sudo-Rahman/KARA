import { createClient } from 'redis';

import type { BackendLogger } from './logger';
import { errorSummary } from './logger';

const OPERATION_TIMEOUT_MS = 5_000;

class RedisOperationTimeoutError extends Error {
	constructor() {
		super(`Redis operation exceeded ${OPERATION_TIMEOUT_MS} ms`);
		this.name = 'RedisOperationTimeoutError';
	}
}

interface RedisConnectionMessages {
	unavailable: string;
	recovered: string;
	ready: string;
}

function createRedisClient(url: string) {
	return createClient({
		url,
		socket: {
			connectTimeout: OPERATION_TIMEOUT_MS,
			reconnectStrategy: false
		}
	});
}

type ConcreteRedisClient = ReturnType<typeof createRedisClient>;

export class RedisConnection {
	readonly #url: string;
	readonly #logger: Pick<BackendLogger, 'error' | 'info'>;
	readonly #messages: RedisConnectionMessages;
	#client: ConcreteRedisClient;
	#connectPromise: Promise<void> | null = null;
	#available: boolean | undefined;

	constructor(
		url: string,
		logger: Pick<BackendLogger, 'error' | 'info'>,
		messages: RedisConnectionMessages
	) {
		this.#url = url;
		this.#logger = logger;
		this.#messages = messages;
		this.#client = this.#createClient();
	}

	async ensureConnected(): Promise<void> {
		if (this.#client.isReady) return;
		if (!this.#connectPromise) {
			this.#connectPromise = this.#client.connect().then(() => undefined);
		}

		const client = this.#client;
		const connectPromise = this.#connectPromise;
		try {
			await this.#withDeadline(connectPromise, client);
		} finally {
			if (this.#connectPromise === connectPromise) this.#connectPromise = null;
		}
	}

	async execute<T>(operation: (client: ConcreteRedisClient) => Promise<T>): Promise<T> {
		await this.ensureConnected();
		const client = this.#client;
		return await this.#withDeadline(operation(client), client);
	}

	async ping(): Promise<void> {
		await this.execute(async (client) => {
			await client.ping();
		});
	}

	async close(): Promise<void> {
		if (this.#client.isOpen) await this.#client.close();
	}

	#createClient(): ConcreteRedisClient {
		const client = createRedisClient(this.#url);
		client.on('error', (error) => this.#reportUnavailable(error));
		client.on('ready', () => this.#reportReady());
		return client;
	}

	async #withDeadline<T>(operation: Promise<T>, client: ConcreteRedisClient): Promise<T> {
		let timeout: ReturnType<typeof setTimeout> | undefined;
		const deadline = new Promise<never>((_, reject) => {
			timeout = setTimeout(() => reject(new RedisOperationTimeoutError()), OPERATION_TIMEOUT_MS);
		});

		try {
			return await Promise.race([operation, deadline]);
		} catch (error) {
			if (error instanceof RedisOperationTimeoutError) this.#discard(client, error);
			throw error;
		} finally {
			if (timeout) clearTimeout(timeout);
		}
	}

	#discard(client: ConcreteRedisClient, error: Error): void {
		if (client !== this.#client) return;
		client.destroy();
		this.#connectPromise = null;
		this.#reportUnavailable(error);
		this.#client = this.#createClient();
	}

	#reportUnavailable(error: unknown): void {
		if (this.#available === false) return;
		this.#available = false;
		this.#logger.error({
			error: errorSummary(error),
			event: 'redis.unavailable'
		}, this.#messages.unavailable);
	}

	#reportReady(): void {
		if (this.#available === true) return;
		const recovered = this.#available === false;
		this.#available = true;
		this.#logger.info({
			event: recovered ? 'redis.recovered' : 'redis.ready'
		}, recovered ? this.#messages.recovered : this.#messages.ready);
	}
}
