export class MediaQuality {
  // Three sending tiers. Quality values follow common JPEG guidance:
  // 省流 60, 标准 75, 原画 100 (original bytes are kept when under the cap).
  static readonly positions: number[] = [0, 0.5, 1];
  static readonly values: number[] = [60, 75, 100];
  static readonly labels: string[] = ['省流', '标准', '原画'];

  static valueAt(position: number): number {
    const p = Math.max(0, Math.min(1, position));
    for (let i = 0; i < MediaQuality.positions.length - 1; i++) {
      const a = MediaQuality.positions[i];
      const b = MediaQuality.positions[i + 1];
      if (p <= b) {
        const t = b == a ? 0 : (p - a) / (b - a);
        return Math.round(MediaQuality.values[i] + t * (MediaQuality.values[i + 1] - MediaQuality.values[i]));
      }
    }
    return 100;
  }

  static presetLabelAt(position: number): string {
    for (let i = 0; i < MediaQuality.positions.length; i++) {
      if (Math.abs(position - MediaQuality.positions[i]) < 0.012) {
        return MediaQuality.labels[i];
      }
    }
    return '';
  }

  static compressionAt(position: number): number {
    return Math.max(0, Math.min(100, 100 - MediaQuality.valueAt(position)));
  }

  static isOriginal(position: number): boolean {
    return position >= 0.999;
  }
}
