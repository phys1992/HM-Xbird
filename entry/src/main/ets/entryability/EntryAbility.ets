import { UIAbility, AbilityConstant, Configuration } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { BackDispatcher } from '../model/BackDispatcher';
import { DetailCache } from '../model/DetailCache';
import { SessionStore } from '../model/SessionStore';
import { ThemeUtil } from '../model/ThemeUtil';
import { LanguageSettingsStore } from '../model/LanguageSettings';
import { I18n } from '../model/I18n';
import { SearchHistoryStore } from '../model/SearchHistoryStore';
import { CacheSettingsStore } from '../model/CacheSettings';
import { CacheStore } from '../model/CacheStore';
import { HomeTimelineCache } from '../model/HomeTimelineCache';
import { SearchSnapshotStore } from '../model/SearchSnapshotStore';

export default class EntryAbility extends UIAbility {
  onMemoryLevel(level: AbilityConstant.MemoryLevel): void {
    DetailCache.clear();
  }

  onBackPressed(): boolean {
    return BackDispatcher.handler();
  }

  onDestroy(): void {
    if (SearchHistoryStore.clearOnExit(this.context)) {
      SearchHistoryStore.clear(this.context);
    }
    if (CacheSettingsStore.load(this.context).clearBrowsingOnExit) {
      HomeTimelineCache.clear(this.context);
      CacheStore.clearBrowsing(this.context);
    }
    SearchSnapshotStore.clearAll(this.context);
  }

  onConfigurationUpdate(config: Configuration): void {
    AppStorage.setOrCreate('themeConfigRevision', Date.now());
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    SearchHistoryStore.purgeForRun(this.context);
    SearchSnapshotStore.clearAll(this.context);
    if (CacheSettingsStore.load(this.context).clearBrowsingOnExit) {
      HomeTimelineCache.clear(this.context);
      CacheStore.clearBrowsing(this.context);
    }
    const dark = ThemeUtil.apply(this.context, SessionStore.loadThemeMode(this.context));
    LanguageSettingsStore.apply('system');
    I18n.setLanguage(LanguageSettingsStore.resolve('system'));
    AppStorage.setOrCreate('clientLang', I18n.language());
    windowStage.loadContent('pages/Index');
    windowStage.getMainWindow().then((win: window.Window) => {
      win.setWindowLayoutFullScreen(true).catch(() => {});
      // Respect the system rotation switch and all orientations it allows.
      win.setPreferredOrientation(window.Orientation.AUTO_ROTATION_UNSPECIFIED).catch(() => {});
      win.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000',
        isStatusBarLightIcon: dark,
        isNavigationBarLightIcon: dark,
        statusBarContentColor: dark ? '#FFFFFF' : '#000000',
        navigationBarContentColor: dark ? '#FFFFFF' : '#000000'
      }).catch(() => {});
    }).catch(() => {});
  }
}
