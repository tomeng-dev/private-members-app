import { Logger } from '@nestjs/common';

/**
 * Load secrets from AWS Secrets Manager / SSM when AWS_SECRETS_ENABLED=true.
 * Falls back to process.env for local/dev. Never logs secret values.
 */
export async function loadSecretsIntoEnv(): Promise<void> {
  const logger = new Logger('SecretsLoader');
  if ((process.env.AWS_SECRETS_ENABLED ?? 'false').toLowerCase() !== 'true') {
    return;
  }
  const secretId = process.env.AWS_SECRET_ID;
  const region = process.env.AWS_REGION ?? 'us-east-1';
  if (!secretId) {
    logger.warn('AWS_SECRETS_ENABLED but AWS_SECRET_ID unset — using env only');
    return;
  }
  try {
    // Dynamic import so local builds without AWS creds still work
    const { SecretsManagerClient, GetSecretValueCommand } =
      await import('@aws-sdk/client-secrets-manager');
    const client = new SecretsManagerClient({ region });
    const res = await client.send(
      new GetSecretValueCommand({ SecretId: secretId }),
    );
    const raw = res.SecretString;
    if (!raw) return;
    const parsed = JSON.parse(raw) as Record<string, string>;
    for (const [k, v] of Object.entries(parsed)) {
      if (typeof v === 'string' && process.env[k] === undefined) {
        process.env[k] = v;
      }
    }
    logger.log(
      `Loaded secrets from ${secretId} (${Object.keys(parsed).length} keys)`,
    );
  } catch (e) {
    logger.error(`Secrets load failed: ${String(e)}`);
    throw e;
  }
}
