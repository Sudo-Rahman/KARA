import type { AuthenticatedAppAttestRequest } from '$lib/server/app-attest/types';

// See https://svelte.dev/docs/kit/types#app.d.ts
// for information about these interfaces
declare global {
	namespace App {
		// interface Error {}
		interface Locals {
			appAttest?: AuthenticatedAppAttestRequest;
		}
		// interface PageData {}
		// interface PageState {}
		// interface Platform {}
	}
}

export {};
