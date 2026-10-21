/** Pure policy: whether a new founding badge may be granted. */
export function canGrantFoundingMember(
  currentFoundingCount: number,
  cap: number,
  requested: boolean | undefined,
): boolean {
  if (currentFoundingCount >= cap) return false;
  if (requested === false) return false;
  // undefined or true → grant while under cap
  return true;
}
