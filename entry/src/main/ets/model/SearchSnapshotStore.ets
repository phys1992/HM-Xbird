import { TweetItem } from './TweetItem';
import { UserProfile } from './UserProfile';
import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';

export class SearchPageSnapshot {
  tweets: TweetItem[] = [];
  users: UserProfile[] = [];
  cursor: string = '';
  fetchedAt: number = 0;
  scrollOffset: number = 0;
}

/**
 * Runtime-only cache for the current search query. Search history terms are
 * persisted by SearchHistoryStore, but result data is never written to disk.
 */
export class SearchSnapshotStore {
  private static cache: Map<string, SearchPageSnapshot> = new Map();
  private static currentQuery: string = '';

  static configure(context: common.UIAbilityContext): void {
    SearchSnapshotStore.cache.clear();
    SearchSnapshotStore.currentQuery = '';
    try {
      const path = `${context.filesDir}/search_snapshots.json`;
      if (fileIo.accessSync(path)) fileIo.unlinkSync(path);
    } catch (e) {}
  }

  static ttlMs(tab: number): number {
    if (tab == 0) return 90 * 60 * 1000;
    if (tab == 1) return 15 * 60 * 1000;
    return 12 * 60 * 60 * 1000;
  }

  static isStale(snapshot: SearchPageSnapshot, tab: number): boolean {
    return snapshot.fetchedAt <= 0 ||
      Date.now() - snapshot.fetchedAt >= SearchSnapshotStore.ttlMs(tab);
  }

  private static normalize(query: string): string {
    return query.trim().toLowerCase();
  }

  static get(query: string, tab: number): SearchPageSnapshot | null {
    const q = SearchSnapshotStore.normalize(query);
    if (q.length == 0 || q != SearchSnapshotStore.currentQuery) return null;
    return SearchSnapshotStore.cache.get(`${q}|${tab}`) ?? null;
  }

  static put(query: string, tab: number, tweets: TweetItem[], users: UserProfile[],
    cursor: string, fetchedAt: number, scrollOffset: number): void {
    const q = SearchSnapshotStore.normalize(query);
    if (q.length == 0) return;
    if (q != SearchSnapshotStore.currentQuery) {
      SearchSnapshotStore.cache.clear();
      SearchSnapshotStore.currentQuery = q;
    }
    const snapshot = new SearchPageSnapshot();
    snapshot.tweets = tweets.slice();
    snapshot.users = users.slice();
    snapshot.cursor = cursor;
    snapshot.fetchedAt = fetchedAt;
    snapshot.scrollOffset = scrollOffset;
    SearchSnapshotStore.cache.set(`${q}|${tab}`, snapshot);
  }

  static removeQuery(query: string): void {
    const q = SearchSnapshotStore.normalize(query);
    if (q != SearchSnapshotStore.currentQuery) return;
    SearchSnapshotStore.cache.clear();
    SearchSnapshotStore.currentQuery = '';
  }

  static clearAll(context: common.UIAbilityContext): void {
    SearchSnapshotStore.cache.clear();
    SearchSnapshotStore.currentQuery = '';
    try {
      const path = `${context.filesDir}/search_snapshots.json`;
      if (fileIo.accessSync(path)) fileIo.unlinkSync(path);
    } catch (e) {}
  }

  static usedBytes(context: common.UIAbilityContext): number {
    return 0;
  }
}
