type RuntimeEnvironment = Readonly<Record<string, string | undefined>>;

export function goldApiKeyFromEnvironment(environment: RuntimeEnvironment): string {
	const apiKey = environment.GOLD_API_KEY?.trim();
	if (!apiKey) throw new Error('GOLD_API_KEY is required');
	return apiKey;
}
