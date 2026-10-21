import { describe, expect, it, vi } from 'vitest';
import { ConsoleMailer } from './console.mailer';
import { emailTemplates } from './templates/email-layout';

describe('Mail adapters + templates', () => {
  it('console mailer sends without throw', async () => {
    const mailer = new ConsoleMailer();
    await expect(
      mailer.send({
        to: 'a@b.c',
        subject: 't',
        text: 'hello',
        html: emailTemplates.approved('Ann', 'https://example.com/set'),
      }),
    ).resolves.toBeUndefined();
  });

  it('templates include gold brand shell', () => {
    const html = emailTemplates.rsvpConfirmation('Ann', 'Gala', 'going');
    expect(html).toContain('#c9a227');
    expect(html).toContain('Gala');
  });
});
