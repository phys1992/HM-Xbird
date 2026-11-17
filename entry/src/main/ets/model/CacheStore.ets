import { common } from '@kit.AbilityKit';
import { http } from '@kit.NetworkKit';
import { fileIo } from '@kit.CoreFileKit';
import { TweetItem } from './TweetItem';

const CACHE_DIR = 'tweet_cache';
const MB = 1024 * 1024;
const HARD_CAP_MB = 512;
// Cached profile timelines are immutable records of the format that produced
// them. A schema bump only updates the marker; existing entries are kept and
// rendered with their existing fields. Never migrate or delete them here.
const SCHEMA_VERSION = 4;
const SCHEMA_FILE = 'schema.txt';

class CacheEntry {
  key: string = '';
  id: string = '';
  tab: number = 0;
  handle: string = '';
  json: string = '';
  imagePath: string = '';
  bytes: number = 0;
  savedAt: number = 0;
  formatVersion: number = 0;
  expiresAt: number = 0;
}

export class CacheStore {
  private static ensureDir(dir: string): void {
    try {
      if (!fileIo.accessSync(dir)) fileIo.mkdirSync(dir);
    } catch (e) {}
  }

  private static dir(context: common.UIAbilityContext, own: boolean = false): string {
    const root = `${context.filesDir}/${CACHE_DIR}`;
    CacheStore.ensureDir(root);
    if (!own) return root;
    const self = `${root}/self`;
    CacheStore.ensureDir(self);
    return self;
  }

  private static ensureSchema(context: common.UIAbilityContext, own: boolean): void {
    const dir = CacheStore.dir(context, own);
    const path = `${dir}/${SCHEMA_FILE}`;
    let current = '';
    try { current = fileIo.readTextSync(path).trim(); } catch (e) {}
    if (current == `${SCHEMA_VERSION}`) return;
    try {
      const out = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      try { fileIo.writeSync(out.fd, `${SCHEMA_VERSION}`); } finally { fileIo.closeSync(out); }
    } catch (e) {}
  }

  static removeLegacyPostedVideos(context: common.UIAbilityContext): void {
    try {
      const dir = `${context.filesDir}/posted_videos`;
      if (!fileIo.accessSync(dir)) return;
      const files = fileIo.listFileSync(dir);
      for (const file of files) {
        try { fileIo.unlinkSync(`${dir}/${file}`); } catch (e) {}
      }
      try { fileIo.rmdirSync(dir); } catch (e) {}
    } catch (e) {}
  }

  private static indexPath(context: common.UIAbilityContext, own: boolean): string {
    return `${CacheStore.dir(context, own)}/index.json`;
  }

  private static cursorPath(context: common.UIAbilityContext, handle: string, tab: number, own: boolean): string {
    const safe = handle.replace(/[^a-zA-Z0-9_]/g, '_');
    return `${CacheStore.dir(context, own)}/cursor_${safe}_${tab}.txt`;
  }

  static loadCursor(context: common.UIAbilityContext, handle: string, tab: number, own: boolean = false): string {
    CacheStore.ensureSchema(context, own);
    try {
      return fileIo.readTextSync(CacheStore.cursorPath(context, handle, tab, own));
    } catch (e) {
      return '';
    }
  }

  static saveCursor(context: common.UIAbilityContext, handle: string, tab: number, cursor: string, own: boolean = false): void {
    CacheStore.ensureSchema(context, own);
    try {
      const path = CacheStore.cursorPath(context, handle, tab, own);
      if (cursor.length == 0) {
        if (fileIo.accessSync(path)) fileIo.unlinkSync(path);
        return;
      }
      const out = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      try { fileIo.writeSync(out.fd, cursor); } finally { fileIo.closeSync(out); }
    } catch (e) {}
  }

  private static tweetTime(item: TweetItem): number {
    const t = new Date(item.createdAt).getTime();
    return isNaN(t) ? 0 : t;
  }

  private static readIndex(context: common.UIAbilityContext, own: boolean): CacheEntry[] {
    try {
      const raw = fileIo.readTextSync(CacheStore.indexPath(context, own));
      if (raw.length == 0) return [];
      return JSON.parse(raw) as CacheEntry[];
    } catch (e) {
      return [];
    }
  }

  private static writeIndex(context: common.UIAbilityContext, own: boolean, entries: CacheEntry[]): void {
    try {
      const path = CacheStore.indexPath(context, own);
      const out = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      try { fileIo.writeSync(out.fd, JSON.stringify(entries)); } finally { fileIo.closeSync(out); }
    } catch (e) {}
  }

  static usedMb(context: common.UIAbilityContext, own: boolean = false): number {
    CacheStore.ensureSchema(context, own);
    let bytes = 0;
    for (const entry of CacheStore.readIndex(context, own)) {
      bytes += entry.bytes > 0 ? entry.bytes : 0;
    }
    return bytes / MB;
  }

  static usedMbTotal(context: common.UIAbilityContext): number {
    return CacheStore.usedMb(context, false) + CacheStore.usedMb(context, true);
  }

  static updateHandlePolicy(context: common.UIAbilityContext, handle: string,
    following: boolean): void {
    CacheStore.ensureSchema(context, false);
    const entries = CacheStore.readIndex(context, false);
    const ttl = following ? 7 * 24 * 60 * 60 * 1000 : 24 * 60 * 60 * 1000;
    const expiresAt = Date.now() + ttl;
    let changed = false;
    for (const entry of entries) {
      if (entry.handle == handle) {
        entry.expiresAt = expiresAt;
        changed = true;
      }
    }
    if (changed) CacheStore.writeIndex(context, false, entries);
  }

  static trimToMb(context: common.UIAbilityContext, maxMb: number, own: boolean = false): void {
    CacheStore.ensureSchema(context, own);
    const entries = CacheStore.readIndex(context, own);
    const limit = Math.max(0, maxMb) * MB;
    entries.sort((a: CacheEntry, b: CacheEntry) => a.savedAt - b.savedAt);
    let used = 0;
    for (const entry of entries) used += entry.bytes;
    let changed = false;
    while (used > limit && entries.length > 0) {
      const oldest = entries.shift();
      if (oldest == undefined) break;
      changed = true;
      if (oldest.imagePath.length > 0) {
        try { fileIo.unlinkSync(oldest.imagePath); } catch (e) {}
      }
      used -= oldest.bytes;
    }
    if (changed) CacheStore.writeIndex(context, own, entries);
  }

  static loadFor(context: common.UIAbilityContext, handle: string, tab: number, own: boolean = false): TweetItem[] {
    CacheStore.ensureSchema(context, own);
    const result: TweetItem[] = [];
    const all = CacheStore.readIndex(context, own);
    const now = Date.now();
    let expired = false;
    const live: CacheEntry[] = [];
    for (const entry of all) {
      if (entry.expiresAt > 0 && entry.expiresAt <= now) {
        expired = true;
        if (entry.imagePath.length > 0) {
          try { fileIo.unlinkSync(entry.imagePath); } catch (e) {}
        }
      } else {
        live.push(entry);
      }
    }
    if (expired) CacheStore.writeIndex(context, own, live);
    const entries = live.filter((e: CacheEntry) => e.handle == handle && e.tab == tab);
    entries.sort((a: CacheEntry, b: CacheEntry) => {
      const at = CacheStore.tweetTime(JSON.parse(a.json) as TweetItem);
      const bt = CacheStore.tweetTime(JSON.parse(b.json) as TweetItem);
      return bt - at;
    });
    for (const entry of entries) {
      try {
        const item = JSON.parse(entry.json) as TweetItem;
        if (entry.imagePath.length > 0 && CacheStore.fileExists(entry.imagePath)) {
          item.imageUrl = `file://${entry.imagePath}`;
        }
        result.push(item);
      } catch (e) {}
    }
    return result;
  }

  private static fileExists(path: string): boolean {
    try { return fileIo.accessSync(path); } catch (e) { return false; }
  }

  private static async download(context: common.UIAbilityContext, url: string, key: string, own: boolean): Promise<string> {
    if (url.length == 0) return '';
    const request = http.createHttp();
    try {
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        header: { 'Referer': 'https://x.com/', 'User-Agent': 'Mozilla/5.0' },
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 15000,
        readTimeout: 30000
      });
      if (response.responseCode < 200 || response.responseCode >= 300) return '';
      const data = response.result as ArrayBuffer;
      if (data.byteLength == 0 || data.byteLength > 12 * MB) return '';
      const safe = key.replace(/[^a-zA-Z0-9_]/g, '_');
      const path = `${CacheStore.dir(context, own)}/${safe}.jpg`;
      const out = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      try { fileIo.writeSync(out.fd, data); } finally { fileIo.closeSync(out); }
      return path;
    } catch (e) {
      return '';
    } finally {
      request.destroy();
    }
  }


  static async cacheTweets(context: common.UIAbilityContext, handle: string, tab: number,
    tweets: TweetItem[], maxItems: number, maxMb: number, maxBytesLimit: number = -1,
    replaceExisting: boolean = false, ttlMs: number = 0, own: boolean = false): Promise<void> {
    CacheStore.ensureSchema(context, own);
    const entries = CacheStore.readIndex(context, own);
    const keys = entries.map((e: CacheEntry) => e.key);
    const capMb = own ? (maxMb <= 0 ? 2048 : maxMb) :
      (maxMb <= 0 ? HARD_CAP_MB : Math.min(maxMb, HARD_CAP_MB));
    const maxBytes = maxBytesLimit > 0 ? Math.min(maxBytesLimit, (own ? 2048 : HARD_CAP_MB) * MB) : capMb * MB;
    let used = 0;
    for (const entry of entries) used += entry.bytes;
    entries.sort((a: CacheEntry, b: CacheEntry) => a.savedAt - b.savedAt);
    while (!own && used > maxBytes * 0.9 && entries.length > 0) {
      const oldest = entries.shift();
      if (oldest == undefined) break;
      if (oldest.imagePath.length > 0) {
        try { fileIo.unlinkSync(oldest.imagePath); } catch (e) {}
      }
      used -= oldest.bytes;
    }
    let added = 0;
    for (const tweet of tweets) {
      if (maxItems > 0 && added >= maxItems) break;
      if (!own && used >= maxBytes) break;
      const key = `${tab}:${tweet.id}`;
      const existing = entries.find((e: CacheEntry) => e.key == key);
      if (existing != undefined) {
        if (replaceExisting) {
          const copy = JSON.parse(JSON.stringify(tweet)) as TweetItem;
          let oldUrl = '';
          try {
            const old = JSON.parse(existing.json) as TweetItem;
            oldUrl = old.imageUrl;
          } catch (e) {}
          let imagePath = existing.imagePath;
          let imageBytes = 0;
          if (imagePath.length > 0 && !CacheStore.fileExists(imagePath)) {
            imagePath = '';
          }
          if (copy.imageUrl.length == 0) {
            if (imagePath.length > 0) {
              try { fileIo.unlinkSync(imagePath); } catch (e) {}
            }
            imagePath = '';
          } else if (imagePath.length == 0 || oldUrl != copy.imageUrl) {
            const posterPath = await CacheStore.download(context, copy.imageUrl, key, own);
            if (posterPath.length > 0) {
              imagePath = posterPath;
            }
          }
          if (imagePath.length > 0) {
            try { imageBytes = fileIo.statSync(imagePath).size; } catch (e) { imageBytes = 0; }
          }
          const before = existing.bytes;
          existing.json = JSON.stringify(copy);
          existing.imagePath = imagePath;
          existing.bytes = imageBytes + existing.json.length;
          existing.savedAt = Date.now() + added;
          existing.formatVersion = SCHEMA_VERSION;
          existing.expiresAt = ttlMs > 0 ? Date.now() + ttlMs : 0;
          used += existing.bytes - before;
          continue;
        }
        // Older caches skipped video posters. Fill them in without duplicating
        // the tweet entry, so profile video cards can show a still immediately.
        if ((existing.imagePath.length == 0 || !CacheStore.fileExists(existing.imagePath)) &&
          tweet.imageUrl.length > 0 &&
          !tweet.imageUrl.startsWith('file://')) {
          const posterPath = await CacheStore.download(context, tweet.imageUrl, key, own);
          if (posterPath.length > 0) {
            let posterBytes = 0;
            try { posterBytes = fileIo.statSync(posterPath).size; } catch (e) {}
            existing.imagePath = posterPath;
            existing.bytes += posterBytes;
            used += posterBytes;
          }
        }
        continue;
      }
      const copy = JSON.parse(JSON.stringify(tweet)) as TweetItem;
      let imagePath = '';
      let imageBytes = 0;
      if (copy.imageUrl.length > 0 && !copy.imageUrl.startsWith('file://')) {
        imagePath = await CacheStore.download(context, copy.imageUrl, key, own);
        if (imagePath.length > 0) {
          try { imageBytes = fileIo.statSync(imagePath).size; } catch (e) { imageBytes = 0; }
        }
      }
      const json = JSON.stringify(copy);
      const entry = new CacheEntry();
      entry.key = key;
      entry.id = copy.id;
      entry.tab = tab;
      entry.handle = handle;
      entry.json = json;
      entry.imagePath = imagePath;
      entry.bytes = imageBytes + json.length;
      entry.savedAt = Date.now() + added;
      entry.formatVersion = SCHEMA_VERSION;
      entry.expiresAt = ttlMs > 0 ? Date.now() + ttlMs : 0;
      entries.push(entry);
      keys.push(key);
      used += entry.bytes;
      added += 1;
    }
    // Evict oldest entries when over count or size.
    entries.sort((a: CacheEntry, b: CacheEntry) => a.savedAt - b.savedAt);
    if (own && maxItems > 0) {
      for (let tab = 0; tab < 3; tab++) {
        const tabEntries = entries.filter((e: CacheEntry) => e.tab == tab);
        let excess = tabEntries.length - maxItems;
        for (const victim of tabEntries) {
          if (excess <= 0) break;
          const at = entries.findIndex((e: CacheEntry) => e.key == victim.key);
          if (at >= 0) {
            entries.splice(at, 1);
            excess -= 1;
            if (victim.imagePath.length > 0) {
              try { fileIo.unlinkSync(victim.imagePath); } catch (e) {}
            }
          }
        }
      }
    }
    while ((!own && maxItems > 0 && entries.length > maxItems) ||
      (!own && entries.reduce((sum: number, e: CacheEntry) => sum + e.bytes, 0) > maxBytes)) {
      const oldest = entries.shift();
      if (oldest == undefined) break;
      if (oldest.imagePath.length > 0) {
        try { fileIo.unlinkSync(oldest.imagePath); } catch (e) {}
      }
    }
    CacheStore.writeIndex(context, own, entries);
  }

  private static clearFiles(context: common.UIAbilityContext, keepSchema: boolean, own: boolean): void {
    const dir = CacheStore.dir(context, own);
    try {
      for (const file of fileIo.listFileSync(dir)) {
        if (keepSchema && file == SCHEMA_FILE) continue;
        try { fileIo.unlinkSync(`${dir}/${file}`); } catch (e) {}
      }
    } catch (e) {}
  }

  static clearOwn(context: common.UIAbilityContext): void {
    CacheStore.clearFiles(context, true, true);
  }

  static clearBrowsing(context: common.UIAbilityContext): void {
    CacheStore.clearFiles(context, true, false);
    CacheStore.removeLegacyPostedVideos(context);
  }

  static ownCount(context: common.UIAbilityContext, tab: number): number {
    return CacheStore.readIndex(context, true).filter((e: CacheEntry) => e.tab == tab).length;
  }

  static clearOwnTab(context: common.UIAbilityContext, tab: number): void {
    CacheStore.ensureSchema(context, true);
    const entries = CacheStore.readIndex(context, true);
    const kept: CacheEntry[] = [];
    for (const entry of entries) {
      if (entry.tab == tab) {
        if (entry.imagePath.length > 0) {
          try { fileIo.unlinkSync(entry.imagePath); } catch (e) {}
        }
      } else {
        kept.push(entry);
      }
    }
    CacheStore.writeIndex(context, true, kept);
  }

  static clear(context: common.UIAbilityContext): void {
    CacheStore.clearFiles(context, true, false);
    CacheStore.clearFiles(context, true, true);
    CacheStore.removeLegacyPostedVideos(context);
  }
}
