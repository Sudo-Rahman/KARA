import type { AuthenticatedAppAttestRequest } from '$lib/server/app-attest/types';
import type { BackendLogger } from '$lib/server/logger';

// See https://svelte.dev/docs/kit/types#app.d.ts
// for information about these interfaces
declare global {
	namespace App {
		// interface Error {}
		interface Locals {
			appAttest?: AuthenticatedAppAttestRequest;
			logger: BackendLogger;
			requestId: string;
		}
		// interface PageData {}
		// interface PageState {}
		// interface Platform {}
	}
}

export {};
