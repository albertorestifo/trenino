/** I2C address helpers mirroring Trenino.Hardware.I2cModule. */

/** Parses decimal (112) or hex (0x70) addresses in 0..255; returns null when invalid. */
export function parseI2cAddress(raw: string): number | null {
  const trimmed = raw.trim();
  if (trimmed === '') return null;
  const hex = /^0x([0-9a-f]+)$/i.exec(trimmed);
  const parsed = hex ? Number.parseInt(hex[1], 16) : /^\d+$/.test(trimmed) ? Number.parseInt(trimmed, 10) : NaN;
  if (Number.isNaN(parsed) || parsed < 0 || parsed > 255) return null;
  return parsed;
}

/** Formats an integer i2c address as '112 (0x70)'. */
export function formatI2cAddress(address: number): string {
  return `${address} (0x${address.toString(16).padStart(2, '0')})`;
}
