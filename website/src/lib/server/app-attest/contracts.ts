import { z } from 'zod';

const keyIdSchema = z.string().trim().regex(
	/^[A-Za-z0-9+/]{43}=$/,
	'keyId must be a canonical 32-byte App Attest key identifier'
);
const bodySHA256Schema = z.string().regex(/^[a-f0-9]{64}$/);

export const challengeRequestSchema = z.discriminatedUnion('purpose', [
	z.object({
		purpose: z.literal('registration'),
		keyId: keyIdSchema
	}).strict(),
	z.object({
		purpose: z.literal('assertion'),
		keyId: keyIdSchema,
		request: z.object({
			method: z.enum(['GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE']),
			pathname: z.string().startsWith('/v1/').max(2048),
			query: z.string().max(4096),
			bodySHA256: bodySHA256Schema
		}).strict()
	}).strict()
]);

export const registrationRequestSchema = z.object({
	challengeId: z.uuid(),
	keyId: keyIdSchema,
	attestation: z.string().min(1).max(131_072)
}).strict();
