/** Strip obvious script tags from member-authored rich text. */
export function stripScripts(
  input: string | undefined | null,
): string | undefined {
  if (input == null) return undefined;
  return input.replace(/<script[\s\S]*?>[\s\S]*?<\/script>/gi, '').trim();
}
