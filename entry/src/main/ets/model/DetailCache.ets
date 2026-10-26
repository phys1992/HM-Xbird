import { TweetItem } from './TweetItem';

/** Small LRU cache for native tweet detail + replies. */
export class DetailCache {
  private static data: Map<string, TweetItem[]> = new Map();
  private static order: string[] = [];
  private static readonly LIMIT: number = 20;

  static get(id: string): TweetItem[] | null {
    const value = DetailCache.data.get(id);
    if (value == undefined) return null;
    const at = DetailCache.order.indexOf(id);
    if (at >= 0) DetailCache.order.splice(at, 1);
    DetailCache.order.push(id);
    return value;
  }

  static put(id: string, tweets: TweetItem[]): void {
    DetailCache.data.set(id, tweets);
    const at = DetailCache.order.indexOf(id);
    if (at >= 0) DetailCache.order.splice(at, 1);
    DetailCache.order.push(id);
    while (DetailCache.order.length > DetailCache.LIMIT) {
      const oldest = DetailCache.order.shift();
      if (oldest != undefined) DetailCache.data.delete(oldest);
    }
  }

  static clear(): void {
    DetailCache.data.clear();
    DetailCache.order = [];
  }
}
