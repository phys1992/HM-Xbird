import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const STORE_NAME = 'x_session';
const KEY_ITEMS = 'cache_max_items';
const KEY_MB = 'cache_max_mb';
const KEY_PROFILE_COUNT = 'cache_profile_count';
const KEY_PROFILE_MB = 'cache_profile_mb';
const KEY_OWN_ITEMS = 'cache_own_items';
const KEY_OWN_POSTS = 'cache_own_posts';
const KEY_OWN_REPLIES = 'cache_own_replies';
const KEY_OWN_REPOSTS = 'cache_own_reposts';
const KEY_CLEAR_BROWSING_ON_EXIT = 'clear_browsing_on_exit';

export class CacheSettings {
  maxItems: number = 100;
  maxMb: number = 1024;
  profileMaxCount: number = 100;
  profileMaxMb: number = 512;
  ownMaxItems: number = 100;
  ownPostsMax: number = 100;
  ownRepliesMax: number = 100;
  ownRepostsMax: number = 100;
  clearBrowsingOnExit: boolean = false;
}

export class CacheSettingsStore {
  private static store: preferences.Preferences | null = null;

  private static getStore(context: common.UIAbilityContext): preferences.Preferences {
    if (CacheSettingsStore.store == null) {
      CacheSettingsStore.store = preferences.getPreferencesSync(context, { name: STORE_NAME });
    }
    return CacheSettingsStore.store;
  }

  static load(context: common.UIAbilityContext): CacheSettings {
    const store = CacheSettingsStore.getStore(context);
    const settings = new CacheSettings();
    const items = store.getSync(KEY_ITEMS, 100);
    const mb = store.getSync(KEY_MB, 1024);
    settings.maxItems = 100;
    const mbValue = typeof mb == 'number' ? mb as number : 1024;
    const presets: number[] = [128, 256, 512, 1024];
    let nearest = 1024;
    let distance = Number.MAX_VALUE;
    for (const value of presets) {
      const d = Math.abs(value - mbValue);
      if (d < distance) { distance = d; nearest = value; }
    }
    settings.maxMb = nearest;
    settings.profileMaxCount = 100;
    settings.profileMaxMb = settings.maxMb;
    const ownItems = store.getSync(KEY_OWN_ITEMS, 100);
    const ownValue = typeof ownItems == 'number' ? ownItems as number : 100;
    settings.ownMaxItems = (ownValue == 50 || ownValue == 100 || ownValue == 200 || ownValue == 0) ?
      ownValue : 100;
    const legacyOwn = CacheSettingsStore.normalizeOwn(ownValue);
    settings.ownPostsMax = CacheSettingsStore.normalizeOwn(store.getSync(KEY_OWN_POSTS, legacyOwn));
    settings.ownRepliesMax = CacheSettingsStore.normalizeOwn(store.getSync(KEY_OWN_REPLIES, legacyOwn));
    settings.ownRepostsMax = CacheSettingsStore.normalizeOwn(store.getSync(KEY_OWN_REPOSTS, legacyOwn));
    const clearBrowsing = store.getSync(KEY_CLEAR_BROWSING_ON_EXIT, false);
    settings.clearBrowsingOnExit = typeof clearBrowsing == 'boolean' ? clearBrowsing as boolean : false;
    return settings;
  }

  private static normalizeOwn(value: Object): number {
    const n = typeof value == 'number' ? value as number : 100;
    if (n == 0 || n > 500) return 0;
    if (n <= 100) return 100;
    if (n <= 200) return 200;
    return 500;
  }

  static save(context: common.UIAbilityContext, settings: CacheSettings): void {
    const store = CacheSettingsStore.getStore(context);
    store.putSync(KEY_ITEMS, 100);
    store.putSync(KEY_MB, settings.maxMb);
    store.putSync(KEY_PROFILE_COUNT, 100);
    store.putSync(KEY_PROFILE_MB, settings.maxMb);
    store.putSync(KEY_OWN_ITEMS, settings.ownMaxItems);
    store.putSync(KEY_OWN_POSTS, settings.ownPostsMax);
    store.putSync(KEY_OWN_REPLIES, settings.ownRepliesMax);
    store.putSync(KEY_OWN_REPOSTS, settings.ownRepostsMax);
    store.putSync(KEY_CLEAR_BROWSING_ON_EXIT, settings.clearBrowsingOnExit);
    store.flush();
  }
}
