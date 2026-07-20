import { hashBytes, parseManifest, verifyPublication, type MetalsManifest } from './contracts';

export interface PublicationBytes {
	readonly manifestBytes: Uint8Array;
	readonly dataBytes: Uint8Array;
}

export interface CachedResource {
	readonly bytes: Uint8Array;
	readonly etag: string;
}

export interface CachedPublication {
	readonly manifest: CachedResource;
	readonly data: CachedResource;
	readonly metadata: MetalsManifest;
}

type RefreshResult = 'updated' | 'unchanged' | 'failed';

interface CacheOptions {
	readonly fallback: PublicationBytes;
	readonly manifestUrl: string;
	readonly fetcher?: typeof fetch;
	readonly logger?: Pick<Console, 'warn'>;
}

const MAX_MANIFEST_BYTES = 1024 * 1024;
const MAX_DATA_BYTES = 16 * 1024 * 1024;
const DOWNLOAD_TIMEOUT_MS = 30_000;

function publicationFrom(bytes: PublicationBytes): CachedPublication {
	const metadata = verifyPublication(bytes.manifestBytes, bytes.dataBytes);
	return {
		manifest: {
			bytes: bytes.manifestBytes,
			etag: `"${hashBytes(bytes.manifestBytes)}"`
		},
		data: {
			bytes: bytes.dataBytes,
			etag: `"${metadata.dataVersion}"`
		},
		metadata
	};
}

async function download(fetcher: typeof fetch, url: string, maxBytes: number): Promise<Uint8Array> {
	const response = await fetcher(url, {
		cache: 'no-store',
		signal: AbortSignal.timeout(DOWNLOAD_TIMEOUT_MS)
	});
	if (!response.ok) {
		throw new Error(`Source request failed with HTTP ${response.status}`);
	}
	const declaredLength = response.headers.get('content-length');
	if (declaredLength !== null && Number.isFinite(Number(declaredLength)) && Number(declaredLength) > maxBytes) {
		throw new Error('Source response is too large');
	}
	if (response.body === null) return new Uint8Array();

	const reader = response.body.getReader();
	const chunks: Uint8Array[] = [];
	let totalBytes = 0;
	while (true) {
		const { done, value } = await reader.read();
		if (done) break;
		totalBytes += value.byteLength;
		if (totalBytes > maxBytes) {
			await reader.cancel().catch(() => undefined);
			throw new Error('Source response is too large');
		}
		chunks.push(value);
	}

	const bytes = new Uint8Array(totalBytes);
	let offset = 0;
	for (const chunk of chunks) {
		bytes.set(chunk, offset);
		offset += chunk.byteLength;
	}
	return bytes;
}

export class MetalsDataCache {
	readonly #manifestUrl: string;
	readonly #snapshotUrl: string;
	readonly #fetcher: typeof fetch;
	readonly #logger: Pick<Console, 'warn'>;
	#publication: CachedPublication;
	#refreshInFlight: Promise<RefreshResult> | undefined;

	constructor(options: CacheOptions) {
		this.#publication = publicationFrom(options.fallback);
		this.#manifestUrl = new URL(options.manifestUrl).toString();
		this.#snapshotUrl = new URL('metals-monthly.json', this.#manifestUrl).toString();
		this.#fetcher = options.fetcher ?? fetch;
		this.#logger = options.logger ?? console;
	}

	current(): CachedPublication {
		return this.#publication;
	}

	refresh(): Promise<RefreshResult> {
		if (this.#refreshInFlight !== undefined) return this.#refreshInFlight;

		this.#refreshInFlight = this.#performRefresh().finally(() => {
			this.#refreshInFlight = undefined;
		});
		return this.#refreshInFlight;
	}

	async #performRefresh(): Promise<RefreshResult> {
		try {
			const manifestBytes = await download(this.#fetcher, this.#manifestUrl, MAX_MANIFEST_BYTES);
			const manifest = parseManifest(manifestBytes);
			if (manifest.dataVersion === this.#publication.metadata.dataVersion) return 'unchanged';

			const dataBytes = await download(this.#fetcher, this.#snapshotUrl, MAX_DATA_BYTES);
			const candidate = publicationFrom({ manifestBytes, dataBytes });
			if (
				candidate.metadata.coverage.from > this.#publication.metadata.coverage.from ||
				candidate.metadata.coverage.through < this.#publication.metadata.coverage.through
			) {
				throw new Error('Metals data coverage regression');
			}
			this.#publication = candidate;
			return 'updated';
		} catch (error) {
			this.#logger.warn('Metals data refresh failed; keeping the last valid publication.', error);
			return 'failed';
		}
	}
}
