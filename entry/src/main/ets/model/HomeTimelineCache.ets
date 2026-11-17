import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { TweetItem } from './TweetItem';

export class HomeTimelineSnapshot {
  tweets: TweetItem[] = [];
  cursor: string = '';
}

export class HomeTimelineCache {
  private static path(context: common.UIAbilityContext, mode: number): string {
    return `${context.filesDir}/home_timeline_${mode == 0 ? 'for_you' : 'following'}.json`;
  }

  static load(context: common.UIAbilityContext, mode: number): HomeTimelineSnapshot {
    const snapshot = new HomeTimelineSnapshot();
    try {
      const raw = fileIo.readTextSync(HomeTimelineCache.path(context, mode));
      if (raw.length == 0) return snapshot;
      const obj = JSON.parse(raw) as Record<string, Object>;
      const rows = obj['tweets'];
      if (Array.isArray(rows)) {
        snapshot.tweets = (rows as Object[]).map((x: Object) =>
          JSON.parse(JSON.stringify(x)) as TweetItem).slice(0, 50);
      }
      snapshot.cursor = typeof obj['cursor'] == 'string' ? obj['cursor'] as string : '';
    } catch (e) {}
    return snapshot;
  }

  static save(context: common.UIAbilityContext, mode: number, tweets: TweetItem[], cursor: string): void {
    try {
      const payload: Record<string, Object> = {};
      payload['tweets'] = tweets.slice(0, 50);
      payload['cursor'] = cursor;
      const file = fileIo.openSync(HomeTimelineCache.path(context, mode),
        fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      try { fileIo.writeSync(file.fd, JSON.stringify(payload)); } finally { fileIo.closeSync(file); }
    } catch (e) {}
  }

  static usedBytes(context: common.UIAbilityContext): number {
    let bytes = 0;
    for (let mode = 0; mode < 2; mode++) {
      try {
        const path = HomeTimelineCache.path(context, mode);
        if (fileIo.accessSync(path)) bytes += fileIo.statSync(path).size;
      } catch (e) {}
    }
    return bytes;
  }

  static clear(context: common.UIAbilityContext): void {
    for (let mode = 0; mode < 2; mode++) {
      try {
        const path = HomeTimelineCache.path(context, mode);
        if (fileIo.accessSync(path)) fileIo.unlinkSync(path);
      } catch (e) {}
    }
  }
}
