export class TweetLength {
  static readonly MAX = 280;

  static count(text: string): number {
    const urlRegex = /https?:\/\/[^\s]+/g;
    const urls = text.match(urlRegex) ?? [];
    const withoutUrls = text.replace(urlRegex, ' ');
    let count = urls.length * 23;
    let i = 0;
    while (i < withoutUrls.length) {
      const code = withoutUrls.codePointAt(i) ?? 0;
      if (code == 0xFE0F || code == 0xFE0E || code == 0x20E3 ||
          (code >= 0xE0020 && code <= 0xE007F) || code == 0x200D) {
        i += code > 0xFFFF ? 2 : 1;
        continue;
      }
      if (code >= 0x1F1E6 && code <= 0x1F1FF) {
        // A flag is a pair of regional indicators; count the pair as one emoji.
        count += 2;
        i += 2;
        const next = withoutUrls.codePointAt(i) ?? 0;
        if (next >= 0x1F1E6 && next <= 0x1F1FF) i += 2;
        continue;
      }
      count += TweetLength.width(code);
      i += code > 0xFFFF ? 2 : 1;
    }
    return count;
  }

  private static width(code: number): number {
    // CJK, Hangul, Hiragana/Katakana and full-width forms count as 2.
    if ((code >= 0x1100 && code <= 0x11FF) ||
        (code >= 0x2E80 && code <= 0xA4CF) ||
        (code >= 0xAC00 && code <= 0xD7A3) ||
        (code >= 0xF900 && code <= 0xFAFF) ||
        (code >= 0xFE30 && code <= 0xFE4F) ||
        (code >= 0xFF00 && code <= 0xFF60) ||
        (code >= 0xFFE0 && code <= 0xFFE6) ||
        code >= 0x1F000) {
      return 2;
    }
    return 1;
  }
}
