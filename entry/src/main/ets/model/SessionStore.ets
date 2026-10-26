import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const STORE_NAME = 'x_session';
const KEY_COOKIE = 'cookie';
const KEY_HANDLE = 'handle';
const KEY_JS_URLS = 'js_urls';
const KEY_SPLIT_RATIO = 'split_ratio';

export class SessionStore {
  private static store: preferences.Preferences | null = null;

  private static getStore(context: common.UIAbilityContext): preferences.Preferences {
    if (SessionStore.store == null) {
      SessionStore.store = preferences.getPreferencesSync(context, { name: STORE_NAME });
    }
    return SessionStore.store;
  }

  static saveCookie(context: common.UIAbilityContext, cookie: string): void {
    const store = SessionStore.getStore(context);
    store.putSync(KEY_COOKIE, cookie);
    store.flush();
  }

  static loadCookie(context: common.UIAbilityContext): string {
    return SessionStore.getStore(context).getSync(KEY_COOKIE, '') as string;
  }

  static saveJsUrls(context: common.UIAbilityContext, urls: string): void {
    const store = SessionStore.getStore(context);
    store.putSync(KEY_JS_URLS, urls);
    store.flush();
  }

  static loadJsUrls(context: common.UIAbilityContext): string {
    return SessionStore.getStore(context).getSync(KEY_JS_URLS, '') as string;
  }

  static saveSplitRatio(context: common.UIAbilityContext, ratio: number): void {
    const store = SessionStore.getStore(context);
    store.putSync(KEY_SPLIT_RATIO, ratio);
    store.flush();
  }

  static loadSplitRatio(context: common.UIAbilityContext): number {
    const value = SessionStore.getStore(context).getSync(KEY_SPLIT_RATIO, 0.5);
    if (typeof value == 'number') return value as number;
    return 0.5;
  }

  static clear(context: common.UIAbilityContext): void {
    const store = SessionStore.getStore(context);
    store.deleteSync(KEY_COOKIE);
    store.deleteSync(KEY_JS_URLS);
    store.flush();
  }

  static cookieValue(cookie: string, name: string): string {
    const parts = cookie.split(';');
    for (const part of parts) {
      const trimmed = part.trim();
      const eq = trimmed.indexOf('=');
      if (eq > 0 && trimmed.substring(0, eq) == name) {
        return trimmed.substring(eq + 1);
      }
    }
    return '';
  }
}
