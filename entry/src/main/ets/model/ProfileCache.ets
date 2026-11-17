import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { UserProfile } from './UserProfile';
import { XApi } from '../api/XApi';
import { CacheStore } from './CacheStore';
import { http } from '@kit.NetworkKit';
import { fileIo } from '@kit.CoreFileKit';
import { CacheSettingsStore } from './CacheSettings';

const STORE_NAME = 'profile_cache';
const KEY_PROFILES = 'profiles';
const KEY_SELF = 'self';
const MEDIA_DIR = 'profile_media';
// Bump only when profile header fields/parsing change in a way that makes old
// cached self data unsafe to display. Timeline changes use CacheStore schema.
const SELF_DISPLAY_VERSION = 1;
const WEEK_MS = 7 * 24 * 60 * 60 * 1000;
const MONTH_MS = 30 * 24 * 60 * 60 * 1000;

export class ProfileCache {
  private static store: preferences.Preferences | null = null;

  private static getStore(context: common.UIAbilityContext): preferences.Preferences {
    if (ProfileCache.store == null) {
      ProfileCache.store = preferences.getPreferencesSync(context, { name: STORE_NAME });
    }
    return ProfileCache.store;
  }

  private static read(context: common.UIAbilityContext): UserProfile[] {
    try {
      const raw = ProfileCache.getStore(context).getSync(KEY_PROFILES, '[]');
      const text = typeof raw == 'string' ? raw as string : '[]';
      const list = JSON.parse(text) as UserProfile[];
      return Array.isArray(list) ? list : [];
    } catch (e) {
      return [];
    }
  }

  private static write(context: common.UIAbilityContext, list: UserProfile[]): void {
    try {
      const store = ProfileCache.getStore(context);
      store.putSync(KEY_PROFILES, JSON.stringify(list));
      store.flush();
    } catch (e) {}
  }

  private static mediaDir(context: common.UIAbilityContext): string {
    const dir = `${context.filesDir}/${MEDIA_DIR}`;
    try {
      if (!fileIo.accessSync(dir)) fileIo.mkdirSync(dir);
    } catch (e) {}
    return dir;
  }

  private static selfHandle(context: common.UIAbilityContext): string {
    try {
      const raw = ProfileCache.getStore(context).getSync(KEY_SELF, '');
      const text = typeof raw == 'string' ? raw as string : '';
      if (text.length == 0) return '';
      const wrapper = JSON.parse(text) as Record<string, Object>;
      const value = wrapper['profile'];
      if (value == null) return '';
      const profile = JSON.parse(JSON.stringify(value)) as UserProfile;
      return profile.handle != undefined ? profile.handle.toLowerCase() : '';
    } catch (e) {
      return '';
    }
  }

  private static fileExists(path: string): boolean {
    try { return path.length > 0 && fileIo.accessSync(path); } catch (e) { return false; }
  }

  private static deleteMedia(profile: UserProfile): void {
    if (profile.avatarPath.length > 0) {
      try { fileIo.unlinkSync(profile.avatarPath); } catch (e) {}
    }
    if (profile.bannerPath.length > 0) {
      try { fileIo.unlinkSync(profile.bannerPath); } catch (e) {}
    }
  }

  private static async download(context: common.UIAbilityContext, url: string,
    path: string): Promise<number> {
    if (url.length == 0) return 0;
    const request = http.createHttp();
    try {
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        header: { 'Referer': 'https://x.com/', 'User-Agent': 'Mozilla/5.0' },
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 15000,
        readTimeout: 30000
      });
      if (response.responseCode < 200 || response.responseCode >= 300) return 0;
      const data = response.result as ArrayBuffer;
      if (data.byteLength == 0 || data.byteLength > 8 * 1024 * 1024) return 0;
      const out = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      try { fileIo.writeSync(out.fd, data); } finally { fileIo.closeSync(out); }
      return data.byteLength;
    } catch (e) {
      return 0;
    } finally {
      request.destroy();
    }
  }

  private static async cacheMedia(context: common.UIAbilityContext, basic: UserProfile): Promise<void> {
    if (basic.isSelf) return;
    const safe = basic.handle.replace(/[^a-zA-Z0-9_]/g, '_');
    const dir = ProfileCache.mediaDir(context);
    let changed = false;
    if (basic.avatarSource.length > 0 &&
      !ProfileCache.fileExists(basic.avatarPath)) {
      const path = `${dir}/${safe}_avatar.jpg`;
      const bytes = await ProfileCache.download(context, basic.avatarSource, path);
      if (bytes > 0) {
        basic.avatarPath = path;
        basic.avatarBytes = bytes;
        changed = true;
      }
    }
    if (basic.bannerSource.length > 0 && !ProfileCache.fileExists(basic.bannerPath)) {
      const path = `${dir}/${safe}_banner.jpg`;
      const bytes = await ProfileCache.download(context, basic.bannerSource, path);
      if (bytes > 0) {
        basic.bannerPath = path;
        basic.bannerBytes = bytes;
        changed = true;
      }
    }
    if (!changed) return;
    const list = ProfileCache.read(context);
    for (const item of list) {
      if (item.handle != null && item.handle.toLowerCase() == basic.handle.toLowerCase()) {
        item.avatarPath = basic.avatarPath;
        item.bannerPath = basic.bannerPath;
        item.avatarBytes = basic.avatarBytes;
        item.bannerBytes = basic.bannerBytes;
      }
    }
    ProfileCache.write(context, list);
    ProfileCache.enforceLimits(context, list);
  }

  private static enforceLimits(context: common.UIAbilityContext, source: UserProfile[]): void {
    const list = source.slice();
    const settings = CacheSettingsStore.load(context);
    const maxProfiles = settings.profileMaxCount <= 0 ? Number.MAX_VALUE : settings.profileMaxCount;
    const budgetMb = settings.profileMaxMb <= 0 ? 2048 : settings.profileMaxMb;
    const self = ProfileCache.selfHandle(context);
    const nonFollowed = list.filter((p: UserProfile) =>
      !p.isSelf && p.handle.toLowerCase() != self && !p.isFollowing);
    nonFollowed.sort((a: UserProfile, b: UserProfile) => a.cachedAt - b.cachedAt);
    let excess = nonFollowed.length - maxProfiles;
    for (let i = 0; i < nonFollowed.length && excess > 0; i++) {
      const victim = nonFollowed[i];
      ProfileCache.deleteMedia(victim);
      const index = list.findIndex((p: UserProfile) => p.handle == victim.handle);
      if (index >= 0) list.splice(index, 1);
      excess -= 1;
    }
    let mediaBytes = 0;
    for (const item of list) {
      if (!item.isSelf && item.handle.toLowerCase() != self && !item.isFollowing) {
        mediaBytes += item.avatarBytes + item.bannerBytes;
      }
    }
    const maxBytes = budgetMb * 1024 * 1024;
    const timelineMb = CacheStore.usedMb(context, false);
    if (mediaBytes + timelineMb * 1024 * 1024 > maxBytes * 0.95) {
      const mediaOnly = list.filter((p: UserProfile) =>
        !p.isSelf && p.handle.toLowerCase() != self && !p.isFollowing &&
        (p.avatarBytes > 0 || p.bannerBytes > 0));
      mediaOnly.sort((a: UserProfile, b: UserProfile) => a.cachedAt - b.cachedAt);
      for (const victim of mediaOnly) {
        if (mediaBytes + timelineMb * 1024 * 1024 <= maxBytes * 0.9) break;
        ProfileCache.deleteMedia(victim);
        mediaBytes -= victim.avatarBytes + victim.bannerBytes;
        victim.avatarPath = '';
        victim.bannerPath = '';
        victim.avatarBytes = 0;
        victim.bannerBytes = 0;
      }
      const availableMb = Math.max(0, (maxBytes - mediaBytes) / (1024 * 1024));
      CacheStore.trimToMb(context, availableMb, false);
    }
    ProfileCache.write(context, list);
  }

  static count(context: common.UIAbilityContext): number {
    return ProfileCache.read(context).length;
  }

  static usedMb(context: common.UIAbilityContext): number {
    let bytes = 0;
    for (const item of ProfileCache.read(context)) {
      const avatar = item.avatarBytes > 0 ? item.avatarBytes : 0;
      const banner = item.bannerBytes > 0 ? item.bannerBytes : 0;
      bytes += avatar + banner;
    }
    return bytes / (1024 * 1024);
  }

  static clearSelf(context: common.UIAbilityContext): void {
    const list = ProfileCache.read(context);
    const kept: UserProfile[] = [];
    for (const item of list) {
      if (item.isSelf) ProfileCache.deleteMedia(item);
      else kept.push(item);
    }
    ProfileCache.write(context, kept);
  }

  static applyLimits(context: common.UIAbilityContext): void {
    ProfileCache.enforceLimits(context, ProfileCache.read(context));
  }

  static clearAll(context: common.UIAbilityContext): void {
    const list = ProfileCache.read(context);
    for (const item of list) ProfileCache.deleteMedia(item);
    ProfileCache.write(context, []);
    try {
      const dir = ProfileCache.mediaDir(context);
      for (const file of fileIo.listFileSync(dir)) {
        try { fileIo.unlinkSync(`${dir}/${file}`); } catch (e) {}
      }
    } catch (e) {}
  }

  static load(context: common.UIAbilityContext, handle: string): UserProfile | null {
    const key = handle.trim().toLowerCase();
    if (key.length == 0) return null;
    const list = ProfileCache.read(context);
    const now = Date.now();
    let removed = false;
    for (let i = 0; i < list.length; i++) {
      const item = list[i];
      const ttl = item.isFollowing ? MONTH_MS : WEEK_MS;
      if (item.cachedAt > 0 && now - item.cachedAt > ttl) {
        ProfileCache.deleteMedia(item);
        list.splice(i, 1);
        i -= 1;
        removed = true;
        continue;
      }
      if (item.handle != null && item.handle.toLowerCase() == key) {
        if (i != list.length - 1) {
          list.splice(i, 1);
          list.push(item);
          ProfileCache.write(context, list);
        } else if (removed) {
          ProfileCache.write(context, list);
        }
        const display = JSON.parse(JSON.stringify(item)) as UserProfile;
        if (ProfileCache.fileExists(display.avatarPath)) display.avatarUrl = `file://${display.avatarPath}`;
        if (ProfileCache.fileExists(display.bannerPath)) display.bannerUrl = `file://${display.bannerPath}`;
        return display;
      }
    }
    if (removed) ProfileCache.write(context, list);
    return null;
  }

  static save(context: common.UIAbilityContext, profile: UserProfile): void {
    const handle = profile.handle.trim();
    if (handle.length == 0) return;
    const all = ProfileCache.read(context);
    const prior = all.find((item: UserProfile) =>
      item.handle != null && item.handle.toLowerCase() == handle.toLowerCase());
    const list = all.filter((item: UserProfile) =>
      item.handle != null && item.handle.toLowerCase() != handle.toLowerCase());
    const basic = new UserProfile();
    basic.id = profile.id;
    basic.name = profile.name;
    basic.handle = profile.handle;
    basic.description = profile.description;
    basic.followers = profile.followers;
    basic.following = profile.following;
    basic.verified = profile.verified;
    basic.createdAt = profile.createdAt;
    basic.location = profile.location;
    basic.website = profile.website;
    basic.birthDate = profile.birthDate;
    basic.isFollowing = profile.isFollowing;
    basic.isSelf = prior != null && prior.isSelf;
    basic.cachedAt = Date.now();
    basic.avatarSource = profile.avatarSource.length > 0 ? profile.avatarSource :
      (profile.avatarUrl.startsWith('file://') ? (prior != null ? prior.avatarSource : '') : profile.avatarUrl);
    basic.bannerSource = profile.bannerSource.length > 0 ? profile.bannerSource :
      (profile.bannerUrl.startsWith('file://') ? (prior != null ? prior.bannerSource : '') : profile.bannerUrl);
    basic.avatarUrl = basic.avatarSource;
    basic.bannerUrl = basic.bannerSource;
    if (prior != null && prior.avatarSource == basic.avatarSource &&
      ProfileCache.fileExists(prior.avatarPath)) {
      basic.avatarPath = prior.avatarPath;
      basic.avatarBytes = prior.avatarBytes;
    }
    if (prior != null && prior.bannerSource == basic.bannerSource &&
      ProfileCache.fileExists(prior.bannerPath)) {
      basic.bannerPath = prior.bannerPath;
      basic.bannerBytes = prior.bannerBytes;
    }
    list.push(basic);
    ProfileCache.enforceLimits(context, list);
    ProfileCache.cacheMedia(context, basic);
  }

  static setFollowing(context: common.UIAbilityContext, handle: string, following: boolean,
    name: string = '', avatarUrl: string = ''): void {
    const key = handle.trim();
    if (key.length == 0) return;
    const list = ProfileCache.read(context);
    let item = list.find((p: UserProfile) =>
      p.handle != null && p.handle.toLowerCase() == key.toLowerCase());
    if (item == undefined) {
      item = new UserProfile();
      item.handle = key;
      item.name = name;
      item.avatarUrl = avatarUrl;
      item.avatarSource = avatarUrl;
      list.push(item);
    }
    item.isFollowing = following;
    item.cachedAt = Date.now();
    ProfileCache.enforceLimits(context, list);
    CacheStore.updateHandlePolicy(context, key, following);
    AppStorage.setOrCreate('profileCacheUpdated', Date.now());
  }

  static loadSelf(context: common.UIAbilityContext): UserProfile | null {
    try {
      const raw = ProfileCache.getStore(context).getSync(KEY_SELF, '');
      const text = typeof raw == 'string' ? raw as string : '';
      if (text.length == 0) return null;
      const wrapper = JSON.parse(text) as Record<string, Object>;
      if (wrapper == null || Number(wrapper['version']) != SELF_DISPLAY_VERSION) return null;
      const value = wrapper['profile'];
      if (value == null) return null;
      const profile = JSON.parse(JSON.stringify(value)) as UserProfile;
      if (profile.handle == undefined || profile.handle.length == 0) return null;
      return profile;
    } catch (e) {
      return null;
    }
  }

  static saveSelf(context: common.UIAbilityContext, profile: UserProfile): void {
    if (profile.handle.length == 0) return;
    try {
      const store = ProfileCache.getStore(context);
      const wrapper: Record<string, Object> = {
        'version': SELF_DISPLAY_VERSION,
        'profile': profile
      };
      store.putSync(KEY_SELF, JSON.stringify(wrapper));
      store.flush();
      const list = ProfileCache.read(context);
      for (const item of list) {
        if (item.handle != null && item.handle.toLowerCase() == profile.handle.toLowerCase()) {
          item.isSelf = true;
        }
      }
      ProfileCache.write(context, list);
    } catch (e) {}
  }

  static notifyChanged(): void {
    AppStorage.setOrCreate('profileCacheDirty', Date.now());
  }

  private static async updateBasic(context: common.UIAbilityContext,
    cookie: string, handle: string): Promise<void> {
    try {
      const profile = await XApi.userByScreenName(cookie, handle);
      ProfileCache.save(context, profile);
      AppStorage.setOrCreate('profileCacheUpdated', Date.now());
    } catch (e) {
      AppStorage.setOrCreate('profileCacheUpdated', Date.now());
    }
  }

  static async recache(context: common.UIAbilityContext, cookie: string,
    handle: string, settings: Object): Promise<void> {
    await ProfileCache.updateBasic(context, cookie, handle);
  }

  static async refresh(context: common.UIAbilityContext, cookie: string,
    handle: string, settings: Object): Promise<void> {
    await ProfileCache.updateBasic(context, cookie, handle);
  }
}
