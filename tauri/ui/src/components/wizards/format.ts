/** The format string implied by a decimal-places choice. */
export function decimalsFormat(decimals: number): string {
  return `{value:.${decimals}f}`;
}

/** Extracts the decimal-places mode of an existing format string, if it is the simple form. */
export function formatDecimals(format: string): number | null {
  const match = /^\{value:\.(\d+)f\}$/.exec(format);
  if (!match) return null;
  const decimals = Number.parseInt(match[1], 10);
  return decimals >= 0 && decimals <= 10 ? decimals : null;
}
