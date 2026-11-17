import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { SearchSnapshotStore } from './SearchSnapshotStore';

const STORE_NAME = 'x_session';
const KEY_CLEAR_ON_EXIT = 'search_clear_on_exit';
const KEY_MAX_ENTRIES = 'search_history_max';
const HISTORY_FILE = 'search_history.json';
const HISTORY_TTL_MS = 10 * 24 * 60 * 60 * 1000;

export class SearchHistoryEntry {
  query: string = '';
  lastTab: number = 1;
  lastUsedAt: number = 0;
}

export class SearchHistoryStore {
  private static store: preferences.Preferences | null = null;

  private static getStore(context: common.UIAbilityContext): preferences.Preferences {
    if (SearchHistoryStore.store == null) {
      SearchHistoryStore.store = preferences.getPreferencesSync(context, { name: STORE_NAME });
    }
    return SearchHistoryStore.store;
  }

  private static path(context: common.UIAbilityContext): string {
    return `${context.filesDir}/${HISTORY_FILE}`;
  }

  private static write(context: common.UIAbilityContext, list: SearchHistoryEntry[]): void {
    try {
      const file = fileIo.openSync(SearchHistoryStore.path(context),
        fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      try { fileIo.writeSync(file.fd, JSON.stringify(list)); } finally { fileIo.closeSync(file); }
    } catch (e) {}
  }

  static maxEntries(context: common.UIAbilityContext): number {
    const value = SearchHistoryStore.getStore(context).getSync(KEY_MAX_ENTRIES, 10);
    const n = typeof value == 'number' ? value as number : 10;
    return n == 20 || n == 30 || n == 50 ? n : 10;
  }

  static setMaxEntries(context: common.UIAbilityContext, value: number): void {
    const n = value == 20 || value == 30 || value == 50 ? value : 10;
    const store = SearchHistoryStore.getStore(context);
    store.putSync(KEY_MAX_ENTRIES, n);
    store.flush();
  }

  static load(context: common.UIAbilityContext): SearchHistoryEntry[] {
    let list: SearchHistoryEntry[] = [];
    try {
      const raw = fileIo.readTextSync(SearchHistoryStore.path(context));
      if (raw.length > 0) {
        const parsed = JSON.parse(raw) as SearchHistoryEntry[];
        if (Array.isArray(parsed)) list = parsed;
      }
    } catch (e) { return []; }
    const now = Date.now();
    const result: SearchHistoryEntry[] = [];
    for (const raw of list) {
      if (raw == null || typeof raw.query != 'string' || raw.query.trim().length == 0) continue;
      if (raw.lastUsedAt <= 0 || now - raw.lastUsedAt > HISTORY_TTL_MS) continue;
      const entry = new SearchHistoryEntry();
      entry.query = raw.query.trim();
      entry.lastTab = raw.lastTab >= 1 && raw.lastTab <= 3 ? raw.lastTab : 1;
      entry.lastUsedAt = raw.lastUsedAt;
      result.push(entry);
    }
    result.sort((a: SearchHistoryEntry, b: SearchHistoryEntry) => b.lastUsedAt - a.lastUsedAt);
    const trimmed = result.slice(0, SearchHistoryStore.maxEntries(context));
    if (trimmed.length != list.length) SearchHistoryStore.write(context, trimmed);
    return trimmed;
  }

  static add(context: common.UIAbilityContext, query: string, lastTab: number): SearchHistoryEntry[] {
    const q = query.trim();
    if (q.length == 0) return SearchHistoryStore.load(context);
    const list = SearchHistoryStore.load(context);
    const normalized = q.toLowerCase();
    const filtered = list.filter((e: SearchHistoryEntry) => e.query.toLowerCase() != normalized);
    const entry = new SearchHistoryEntry();
    entry.query = q;
    entry.lastTab = lastTab >= 1 && lastTab <= 3 ? lastTab : 1;
    entry.lastUsedAt = Date.now();
    filtered.unshift(entry);
    const trimmed = filtered.slice(0, SearchHistoryStore.maxEntries(context));
    SearchHistoryStore.write(context, trimmed);
    return trimmed;
  }

  static updateTab(context: common.UIAbilityContext, query: string, tab: number): SearchHistoryEntry[] {
    const list = SearchHistoryStore.load(context);
    const q = query.trim().toLowerCase();
    let changed = false;
    for (const entry of list) {
      if (entry.query.toLowerCase() == q) {
        entry.lastTab = tab >= 1 && tab <= 3 ? tab : entry.lastTab;
        changed = true;
        break;
      }
    }
    if (changed) SearchHistoryStore.write(context, list);
    return list;
  }

  static remove(context: common.UIAbilityContext, query: string): SearchHistoryEntry[] {
    SearchSnapshotStore.removeQuery(query);
    const q = query.trim().toLowerCase();
    const list = SearchHistoryStore.load(context).filter((e: SearchHistoryEntry) =>
      e.query.toLowerCase() != q);
    SearchHistoryStore.write(context, list);
    return list;
  }

  static clear(context: common.UIAbilityContext): void {
    SearchSnapshotStore.clearAll(context);
    SearchHistoryStore.write(context, []);
    try {
      const path = SearchHistoryStore.path(context);
      if (fileIo.accessSync(path)) fileIo.unlinkSync(path);
    } catch (e) {}
  }

  static usedBytes(context: common.UIAbilityContext): number {
    try {
      const path = SearchHistoryStore.path(context);
      return fileIo.accessSync(path) ? fileIo.statSync(path).size : 0;
    } catch (e) { return 0; }
  }

  static clearOnExit(context: common.UIAbilityContext): boolean {
    const value = SearchHistoryStore.getStore(context).getSync(KEY_CLEAR_ON_EXIT, false);
    return typeof value == 'boolean' ? value as boolean : false;
  }

  static setClearOnExit(context: common.UIAbilityContext, value: boolean): void {
    const store = SearchHistoryStore.getStore(context);
    store.putSync(KEY_CLEAR_ON_EXIT, value);
    store.flush();
  }

  static purgeForRun(context: common.UIAbilityContext): void {
    if (!SearchHistoryStore.clearOnExit(context)) return;
    SearchHistoryStore.clear(context);
  }
}
