import pino, { type DestinationStream, type Logger } from 'pino';

const DEFAULT_LOG_LEVEL = process.env.NODE_ENV === 'test' ? 'silent' : 'info';
const LOG_LEVELS = new Set(['trace', 'debug', 'info', 'warn', 'error', 'fatal', 'silent']);

const configuredLevel = process.env.LOG_LEVEL?.trim().toLowerCase();
const level = configuredLevel && LOG_LEVELS.has(configuredLevel)
	? configuredLevel
	: DEFAULT_LOG_LEVEL;

export function createBackendLogger(options: {
	destination?: DestinationStream;
	level?: string;
} = {}): Logger {
	const configuration = {
		base: {
			environment: process.env.NODE_ENV ?? 'development',
			service: 'kara-backend'
		},
		formatters: {
			level: (label: string) => ({ level: label })
		},
		level: options.level ?? level,
		redact: {
			censor: '[REDACTED]',
			paths: [
				'authorization',
				'cookie',
				'password',
				'secret',
				'token',
				'apiKey',
				'keyId',
				'installationId',
				'ipId',
				'headers.authorization',
				'headers.cookie',
				'headers["x-api-key"]',
				'headers["x-kara-app-attest-key-id"]',
				'headers["x-kara-app-attest-challenge-id"]',
				'headers["x-kara-app-attest-assertion"]',
				'*.password',
				'*.secret',
				'*.token',
				'*.apiKey',
				'*.keyId',
				'*.installationId',
				'*.ipId'
			]
		},
		serializers: {
			err: pino.stdSerializers.err
		},
		timestamp: pino.stdTimeFunctions.isoTime
	};
	return options.destination
		? pino(configuration, options.destination)
		: pino(configuration);
}

export const logger = createBackendLogger();

if (configuredLevel && configuredLevel !== level) {
	logger.warn({
		event: 'logger.invalid_level',
		configuredLevel,
		fallbackLevel: level
	}, 'Invalid LOG_LEVEL; using the default level');
}

export type BackendLogger = Logger;

export function errorSummary(error: unknown, depth = 0): Record<string, unknown> {
	if (!(error instanceof Error)) {
		return { name: 'NonError', message: String(error) };
	}

	const candidate = error as Error & {
		code?: unknown;
		errno?: unknown;
		hostname?: unknown;
		requestID?: unknown;
		status?: unknown;
		statusText?: unknown;
		syscall?: unknown;
	};
	const summary: Record<string, unknown> = {
		name: error.name,
		message: error.message
	};
	for (const key of ['code', 'errno', 'hostname', 'requestID', 'status', 'statusText', 'syscall'] as const) {
		const value = candidate[key];
		if (typeof value === 'string' || typeof value === 'number') summary[key] = value;
	}
	if (error.cause !== undefined && depth < 3) {
		summary.cause = errorSummary(error.cause, depth + 1);
	}
	return summary;
}
