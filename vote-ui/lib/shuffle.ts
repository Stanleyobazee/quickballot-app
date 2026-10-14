/**
 * Fisher-Yates (Knuth) shuffle. Returns a new array and leaves the input
 * untouched. Every permutation is equally likely, unlike
 * `arr.sort(() => Math.random() - 0.5)`.
 */
export function shuffle<T>(items: readonly T[]): T[] {
  const result = items.slice();
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}
