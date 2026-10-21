/** Black / white / gold transactional email shell (inline CSS for clients). */
export function emailLayout(opts: {
  title: string;
  bodyHtml: string;
  preheader?: string;
}): string {
  return `<!DOCTYPE html><html><head><meta charset="utf-8"/><title>${escapeHtml(opts.title)}</title></head>
<body style="margin:0;padding:0;background:#0a0a0a;color:#f5f5f5;font-family:Georgia,serif;">
  <div style="display:none;max-height:0;overflow:hidden;">${escapeHtml(opts.preheader ?? '')}</div>
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#0a0a0a;">
    <tr><td align="center" style="padding:32px 16px;">
      <table role="presentation" width="560" style="max-width:560px;background:#111;border:1px solid #c9a227;">
        <tr><td style="padding:24px 28px;border-bottom:1px solid #c9a227;">
          <div style="font-size:20px;letter-spacing:0.08em;color:#c9a227;font-weight:700;">PRIVATE MEMBERS</div>
        </td></tr>
        <tr><td style="padding:28px;font-size:17px;line-height:1.55;color:#f5f5f5;">
          <h1 style="margin:0 0 16px;font-size:24px;color:#ffffff;">${escapeHtml(opts.title)}</h1>
          ${opts.bodyHtml}
        </td></tr>
        <tr><td style="padding:16px 28px;font-size:13px;color:#888;border-top:1px solid #333;">
          This message is for club members only. No marketing content.
        </td></tr>
      </table>
    </td></tr>
  </table>
</body></html>`;
}

export function escapeHtml(s: string) {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

export const emailTemplates = {
  approved: (name: string, setPasswordUrl: string) =>
    emailLayout({
      title: 'Welcome — application approved',
      preheader: 'Set your password to join',
      bodyHtml: `<p style="font-size:17px;">Hello ${escapeHtml(name)},</p>
        <p style="font-size:17px;">Your membership application was approved. Set your password to continue:</p>
        <p><a href="${escapeHtml(setPasswordUrl)}" style="display:inline-block;padding:14px 22px;background:#c9a227;color:#111;text-decoration:none;font-size:17px;font-weight:700;">Set password</a></p>`,
    }),
  resetPassword: (name: string, url: string) =>
    emailLayout({
      title: 'Password reset',
      bodyHtml: `<p style="font-size:17px;">Hello ${escapeHtml(name)},</p>
        <p style="font-size:17px;">Use this link to reset your password (expires soon):</p>
        <p><a href="${escapeHtml(url)}" style="color:#c9a227;font-size:17px;">Reset password</a></p>`,
    }),
  eventReminder: (name: string, eventTitle: string, when: string) =>
    emailLayout({
      title: 'Event reminder',
      bodyHtml: `<p style="font-size:17px;">Hello ${escapeHtml(name)},</p>
        <p style="font-size:17px;"><strong style="color:#c9a227;">${escapeHtml(eventTitle)}</strong> is coming up ${escapeHtml(when)}.</p>`,
    }),
  rsvpConfirmation: (name: string, eventTitle: string, status: string) =>
    emailLayout({
      title: 'RSVP confirmation',
      bodyHtml: `<p style="font-size:17px;">Hello ${escapeHtml(name)},</p>
        <p style="font-size:17px;">Your RSVP for <strong style="color:#c9a227;">${escapeHtml(eventTitle)}</strong> is now: <strong>${escapeHtml(status)}</strong>.</p>`,
    }),
  duesReminder: (name: string, renewal: string) =>
    emailLayout({
      title: 'Membership dues reminder',
      bodyHtml: `<p style="font-size:17px;">Hello ${escapeHtml(name)},</p>
        <p style="font-size:17px;">A dues reminder for your membership (renewal ${escapeHtml(renewal)}). An admin will mark payment when received.</p>`,
    }),
  moderation: (name: string, action: string, reason: string) =>
    emailLayout({
      title: 'Account notice',
      bodyHtml: `<p style="font-size:17px;">Hello ${escapeHtml(name)},</p>
        <p style="font-size:17px;">Your account was <strong>${escapeHtml(action)}</strong>.</p>
        <p style="font-size:17px;">Reason: ${escapeHtml(reason)}</p>`,
    }),
};
