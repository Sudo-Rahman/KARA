import { z } from 'zod';

import { manifestSchema } from '../metals-data/contracts';
import { spotQuoteSchema } from '../metals-spot/contracts';

const eurQuote = spotQuoteSchema.extend({ currency: z.literal('EUR') });

export const marketDataBootstrapSchema = z.object({
	schemaVersion: z.literal(1),
	manifest: manifestSchema,
	spots: z.tuple([
		eurQuote.extend({ metal: z.literal('XAU') }),
		eurQuote.extend({ metal: z.literal('XAG') }),
		eurQuote.extend({ metal: z.literal('XPT') }),
		eurQuote.extend({ metal: z.literal('XPD') })
	])
});

export type MarketDataBootstrap = z.infer<typeof marketDataBootstrapSchema>;
