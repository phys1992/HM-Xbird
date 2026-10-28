import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const STORE_NAME = 'x_session';
const KEY_COOKIE = 'cookie';
const KEY_HANDLE = 'handle';
const KEY_JS_URLS = 'js_urls';
const KEY_SPLIT_RATIO = 'split_ratio';
const KEY_SPLIT_ENABLED = 'split_enabled';
const KEY_THEME_MODE = 'theme_mode';
const KEY_IMAGE_LIMIT = 'image_limit_mb';
const KEY_GIF_LIMIT = 'gif_limit_mb';
const KEY_MEDIA_QUALITY = 'media_quality';

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

  static saveSplitEnabled(context: common.UIAbilityContext, enabled: boolean): void {
    const store = SessionStore.getStore(context);
    store.putSync(KEY_SPLIT_ENABLED, enabled);
    store.flush();
  }

  static loadSplitEnabled(context: common.UIAbilityContext): boolean {
    const value = SessionStore.getStore(context).getSync(KEY_SPLIT_ENABLED, true);
    return typeof value == 'boolean' ? value as boolean : true;
  }

  static saveThemeMode(context: common.UIAbilityContext, mode: string): void {
    const store = SessionStore.getStore(context);
    store.putSync(KEY_THEME_MODE, mode);
    store.flush();
  }

  static loadThemeMode(context: common.UIAbilityContext): string {
    const value = SessionStore.getStore(context).getSync(KEY_THEME_MODE, 'system');
    return typeof value == 'string' ? value as string : 'system';
  }

  static saveMediaSettings(context: common.UIAbilityContext, imageLimit: number, gifLimit: number, quality: number): void {
    const store = SessionStore.getStore(context);
    store.putSync(KEY_IMAGE_LIMIT, imageLimit);
    store.putSync(KEY_GIF_LIMIT, gifLimit);
    store.putSync(KEY_MEDIA_QUALITY, quality);
    store.flush();
  }

  static loadImageLimit(context: common.UIAbilityContext): number {
    const value = SessionStore.getStore(context).getSync(KEY_IMAGE_LIMIT, 5);
    return typeof value == 'number' ? value as number : 5;
  }

  static loadGifLimit(context: common.UIAbilityContext): number {
    const value = SessionStore.getStore(context).getSync(KEY_GIF_LIMIT, 15);
    return typeof value == 'number' ? value as number : 15;
  }

  static loadMediaQuality(context: common.UIAbilityContext): number {
    const value = SessionStore.getStore(context).getSync(KEY_MEDIA_QUALITY, 2);
    return typeof value == 'number' ? value as number : 2;
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
