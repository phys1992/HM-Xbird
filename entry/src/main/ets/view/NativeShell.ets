import { display, window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { resourceManager } from '@kit.LocalizationKit';
import { promptAction } from '@kit.ArkUI';
import { TweetItem } from '../model/TweetItem';
import { SessionStore } from '../model/SessionStore';
import { DraftStore } from '../model/DraftStore';
import { ThemeUtil } from '../model/ThemeUtil';
import { QueryIds } from '../api/QueryIds';
import { BackDispatcher } from '../model/BackDispatcher';
import { LoginView } from './LoginView';
import { NativeLogin } from './NativeLogin';
import { ProfilePage } from './ProfilePage';
import { FullscreenVideo } from './FullscreenVideo';
import { ActionSheetDialog, DialogOption } from './ActionSheetDialog';
import { FullscreenImageViewer } from './FullscreenImageViewer';
import { HomeFeed } from './HomeFeed';
import { SearchView } from './SearchView';
import { XApi } from '../api/XApi';
import { DetailCache } from '../model/DetailCache';
import { NotificationItem } from '../model/NotificationItem';
import { UserProfile } from '../model/UserProfile';
import { TweetCard } from './TweetCard';
import { ComposeView } from './ComposeView';
import { ThemeSettingsPage } from './ThemeSettingsPage';
import { AccountStore, SavedAccount } from '../model/AccountStore';
import { SystemAuth } from '../model/SystemAuth';
import { UserListPage } from './UserListPage';
import { EditProfilePage } from './EditProfilePage';
import { MediaSettingsPage } from './MediaSettingsPage';
import { AboutPage } from './AboutPage';
import { GestureSettingsPage } from './GestureSettingsPage';
import { CacheSettingsPage } from './CacheSettingsPage';
import { PlaybackSettings, PlaybackSettingsStore } from '../model/PlaybackSettings';
import { CacheSettings, CacheSettingsStore } from '../model/CacheSettings';
import { CacheStore } from '../model/CacheStore';
import { SearchHistoryStore } from '../model/SearchHistoryStore';
import { SearchSnapshotStore } from '../model/SearchSnapshotStore';
import { HomeTimelineCache } from '../model/HomeTimelineCache';
import { I18n } from '../model/I18n';
import { LanguageSettingsStore } from '../model/LanguageSettings';
import { LanguageSettingsPage } from './LanguageSettingsPage';
import { SettingsPageHeader } from './SettingsPageHeader';
import { ProfileCache } from '../model/ProfileCache';
import { VideoAutoplay } from '../model/VideoAutoplay';
import { RelationStore } from '../model/RelationStore';
import { TranslationSettings, TranslationSettingsStore } from '../model/TranslationSettings';
import { TranslationSettingsPage } from './TranslationSettingsPage';
import { PublishBrowseSettingsPage } from './PublishBrowseSettingsPage';

const SPLIT_BREAKPOINT_VP: number = 600;

@Component
export struct NativeShell {
  @StorageProp('clientLang') clientLanguage: string = 'zh';
  @StorageProp('profileCacheDirty') @Watch('onProfileCacheDirty') profileCacheDirty: number = 0;
  private tr(value: string): string {
    return this.clientLanguage.length >= 0 ? I18n.t(value) : I18n.t(value);
  }

  @State cookie: string = '';
  @State loggedIn: boolean = false;
  @State tab: number = 0;
  @State paneWidth: number = 360;
  @State paneHeight: number = 800;
  @State barMode: number = 1;
  @State barX: number = 20;
  @State notifications: NotificationItem[] = [];
  @State notificationsLoading: boolean = false;
  @State notificationsError: string = '';
  @State notificationsLoaded: boolean = false;
  @State notificationsCursor: string = '';
  @State profile: UserProfile | null = null;
  @State profileLoading: boolean = false;
  @State myTweets: TweetItem[] = [];
  @State myLoading: boolean = false;
  @State splitEnabled: boolean = true;
  @State playingVideo: string = '';
  @State playingVideoStart: number = 0;
  @State playingVideoPoster: string = '';
  @State viewingImage: string = '';
  @State showWebLogin: boolean = false;
  @State profileHandle: string = '';
  @State private profileDetailReturn: string = '';
  @State private settingsDetailOnTop: boolean = false;
  @State translationSettings: TranslationSettings = new TranslationSettings();
  @State translationEnabled: boolean = true;
  @State translationTarget: string = '';
  @State translationException: string = '';
  @State showTranslationSettings: boolean = false;
  @State showPublishBrowseSettings: boolean = false;
  @State sheenX: number = -120;
  @State barOpaque: boolean = false;
  @State lightX: number = 0;
  @State lightOpacity: number = 0;
  @State videoError: string = '';
  @State keyboardHeight: number = 0;
  private mainWin: window.Window | null = null;
  private logoutDialog: CustomDialogController = new CustomDialogController({
    builder: ActionSheetDialog({
      title: '退出登录',
      message: '退出后当前账号将不再保持登录。你可以保留本机保存的账号，或同时删除本机账号数据。',
      options: [
        new DialogOption('仅退出登录', '保留本机账号和缓存数据', false, () => this.logout(true),
          $r('app.media.ic_dialog_logout')),
        new DialogOption('删除本机账号并退出', '同时删除账号和本机缓存数据', true, () => this.confirmDeleteSavedAccount(),
          $r('app.media.ic_dialog_delete'))
      ]
    }),
    autoCancel: true,
    alignment: DialogAlignment.Bottom,
    customStyle: true,
    offset: { dx: 0, dy: -12 }
  });
  private touchStartX: number = 0;
  private touchStartY: number = 0;
  private touchMoved: boolean = false;
  @State barHeight: number = 56;
  @State safeBottom: number = 0;
  @State safeTop: number = 0;
  @State barGap: number = 12;
  @State menuZone: number = 48;
  @State barWidth: number = 288;
  @State homeTapTick: number = 0;
  @State searchFocusTick: number = 0;
  @State previousTab: number = 0;
  @State themeMode: string = 'system';
  @State isDarkTheme: boolean = false;
  @State imageLimitMb: number = 5;
  @State gifLimitMb: number = 15;
  @State imageQuality: number = 0.5;
  @State gifQuality: number = 0.5;
  @State showThemeSettings: boolean = false;
  @State showLanguageSettings: boolean = false;
  @State showEditProfile: boolean = false;
  @State showMediaSettings: boolean = false;
  @State showAbout: boolean = false;
  @State settingsSection: string = 'profile';
  @State languageMode: string = 'system';
  @State settingsDetail: TweetItem | null = null;
  @State settingsDetailTweets: TweetItem[] = [];
  @State settingsDetailLoading: boolean = false;
  @State settingsDetailError: string = '';
  @State showGestureSettings: boolean = false;
  private lastSettingsSplit: boolean = false;
  private settingsSplitInitialized: boolean = false;
  private restoreSettingsAfterDetail: boolean = false;
  @State private settingsPanePinned: boolean = false;
  @State showCacheSettings: boolean = false;
  @State autoPlay: boolean = false;
  @State autoPlayMuted: boolean = true;
  @State fullscreenMuted: boolean = true;
  @State volumeRatio: number = 0.5;
  @State fullscreenVolumeRatio: number = 0.5;
  @State fullscreenGestures: boolean = true;
  @State cacheMaxItems: number = 100;
  @State cacheMaxMb: number = 1024;
  @State cacheOwnPostsMax: number = 100;
  @State cacheOwnRepliesMax: number = 100;
  @State cacheOwnRepostsMax: number = 100;
  @State cacheClearBrowsingOnExit: boolean = false;
  @State cacheUsedMb: number = 0;
  @State cacheOwnUsedMb: number = 0;
  private cacheRefreshed: boolean = false;
  private cacheRefreshing: boolean = false;
  private cacheRefreshTimer: number = -1;
  private homeReady: boolean = false;
  @State aboutPage: string = 'main';
  @State savedAccounts: SavedAccount[] = [];
  @State pendingSaveAccount: boolean = false;
  @State loginPage: string = 'home';
  @State userListVisible: boolean = false;
  @State userListKind: string = 'followers';
  @State userListId: string = '';
  @State userListTitle: string = this.tr('关注者');
  @State splitRatio: number = 0.5;
  @State splitUserAdjusted: boolean = false;
  private splitStartRatio: number = 0.5;
  @State trendsHomeTick: number = 0;
  @State expanded: boolean = false;
  @State selected: TweetItem | null = null;
  @State detailTweets: TweetItem[] = [];
  private detailHistory: TweetItem[] = [];
  private detailScrollHistory: number[] = [];
  private detailScroller: Scroller = new Scroller();
  @State private detailOffsetX: number = 0;
  @State private detailPageOpacity: number = 1;
  @State private settingsDetailOpacity: number = 1;
  private settingsDetailHistory: TweetItem[] = [];
  private settingsDetailScrollHistory: number[] = [];
  private settingsDetailScroller: Scroller = new Scroller();
  @State private settingsDetailOffsetX: number = 0;
  @State detailLoading: boolean = false;
  @State detailError: string = '';
  @State composing: boolean = false;
  @State replyId: string = '';
  @State replyHandle: string = '';
  @State quoteId: string = '';
  @State quoteHandle: string = '';
  @State quoteText: string = '';

  aboutToAppear(): void {
    BackDispatcher.handler = () => this.handleBack();
    const context = getContext(this) as common.UIAbilityContext;
    this.translationSettings = TranslationSettingsStore.load(context);
    this.translationEnabled = this.translationSettings.enabled;
    this.translationTarget = this.translationSettings.targetLang;
    this.translationException = this.translationSettings.exceptionLang;
    this.savedAccounts = AccountStore.load(context);
    const savedJs = SessionStore.loadJsUrls(context);
    if (savedJs.length > 2) {
      try {
        QueryIds.setBundleUrls(JSON.parse(savedJs) as string[]);
      } catch (e) {}
    }
    const saved = SessionStore.loadCookie(context);
    if (saved.length > 0) {
      this.cookie = saved;
      this.loggedIn = true;
      const cachedSelf = ProfileCache.loadSelf(context);
      if (cachedSelf != null) {
        this.profile = cachedSelf;
        RelationStore.setViewer(cachedSelf.id);
      } else {
        this.loadProfile(true);
      }
    }
    this.splitEnabled = SessionStore.loadSplitEnabled(context);
    this.themeMode = SessionStore.loadThemeMode(context);
    this.languageMode = 'system';
    AppStorage.setOrCreate('clientLang', I18n.language());
    this.isDarkTheme = ThemeUtil.isDark(context, this.themeMode);
    AppStorage.setOrCreate('tuichuang_dark', this.isDarkTheme);
    this.imageLimitMb = SessionStore.loadImageLimit(context);
    this.gifLimitMb = SessionStore.loadGifLimit(context);
    this.imageQuality = SessionStore.loadImageQuality(context);
    this.gifQuality = SessionStore.loadGifQuality(context);
    const playback = PlaybackSettingsStore.load(context);
    this.autoPlay = playback.autoPlay;
    this.autoPlayMuted = playback.autoPlayMuted;
    this.fullscreenMuted = playback.fullscreenMuted;
    this.volumeRatio = playback.volumeRatio;
    this.fullscreenVolumeRatio = playback.fullscreenVolumeRatio;
    this.fullscreenGestures = playback.fullscreenGestures;
    const cacheSettings = CacheSettingsStore.load(context);
    this.cacheMaxItems = 100;
    this.cacheMaxMb = cacheSettings.maxMb;
    this.cacheOwnPostsMax = cacheSettings.ownPostsMax;
    this.cacheOwnRepliesMax = cacheSettings.ownRepliesMax;
    this.cacheOwnRepostsMax = cacheSettings.ownRepostsMax;
    this.cacheClearBrowsingOnExit = cacheSettings.clearBrowsingOnExit;
    CacheStore.removeLegacyPostedVideos(context);
    this.refreshCacheUsage();
    this.configureAutoplay();
    try {
      const sys = resourceManager.getSystemResourceManager();
      const h = sys.getNumberByName('ohos_id_navigation_bar_height');
      if (h > 0) this.barHeight = h;
      const gap = sys.getNumberByName('ohos_id_default_padding_start');
      if (gap > 0) this.barGap = gap;
      const zone = sys.getNumberByName('ohos_id_navigation_bar_menu_zone_size');
      if (zone > 0) this.menuZone = zone;
    } catch (e) {}
    window.getLastWindow(context).then((win: window.Window) => {
      this.mainWin = win;
      const area = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      try {
        const density = display.getDefaultDisplaySync().densityPixels;
        this.safeBottom = area.bottomRect.height / density;
        this.safeTop = area.topRect.height / density;
      } catch (e) {}
      this.applySystemBars();
      win.on('keyboardHeightChange', (height: number) => {
        try {
          this.keyboardHeight = height / display.getDefaultDisplaySync().densityPixels;
        } catch (e) {}
      });
    }).catch(() => {});
    animateTo({
      duration: 2600,
      curve: Curve.EaseInOut,
      iterations: -1,
      playMode: PlayMode.Alternate
    }, () => {
      this.sheenX = 300;
    });
    try {
      if (display.isFoldable()) {
        this.expanded = display.getFoldDisplayMode() == display.FoldDisplayMode.FOLD_DISPLAY_MODE_FULL;
      }
      display.on('foldDisplayModeChange', (mode: number) => {
        this.expanded = mode == display.FoldDisplayMode.FOLD_DISPLAY_MODE_FULL;
        if (!this.expanded) this.barMode = 1;
        this.updateBarX();
      });
    } catch (e) {}
  }

  aboutToDisappear(): void {
    try {
      display.off('foldDisplayModeChange');
    } catch (e) {}
    if (this.mainWin != null) {
      this.mainWin.off('keyboardHeightChange');
    }
  }

  private closeImage(): void {
    animateTo({ duration: 220, curve: Curve.FastOutSlowIn }, () => {
      this.viewingImage = '';
    });
  }

  private closeVideo(): void {
    VideoAutoplay.exitFullscreen();
    animateTo({ duration: 220, curve: Curve.FastOutSlowIn }, () => {
      this.playingVideo = '';
      this.playingVideoStart = 0;
      this.playingVideoPoster = '';
    });
    this.configureAutoplay();
  }

  private closeProfile(): void {
    animateTo({ duration: 280, curve: Curve.FastOutSlowIn }, () => {
      this.profileHandle = '';
    });
  }

  private closeComposeIfOpen(): void {
    if (this.composing) this.closeCompose();
  }

  private closeCompose(): void {
    DraftStore.flush(getContext(this) as common.UIAbilityContext);
    animateTo({ duration: 280, curve: Curve.FastOutSlowIn }, () => {
      this.composing = false;
    });
  }

  private handleBack(): boolean {
    if (!this.loggedIn) {
      if (this.showWebLogin) {
        this.showWebLogin = false;
        return true;
      }
      if (this.loginPage != 'home') {
        this.loginPage = 'home';
        return true;
      }
      return false;
    }
    if (this.viewingImage.length > 0) {
      animateTo({ duration: 220, curve: Curve.FastOutSlowIn }, () => {
        this.viewingImage = '';
      });
      return true;
    }
    if (this.playingVideo.length > 0) {
      VideoAutoplay.exitFullscreen();
      animateTo({ duration: 220, curve: Curve.FastOutSlowIn }, () => {
        this.playingVideo = '';
        this.playingVideoStart = 0;
        this.playingVideoPoster = '';
      });
      this.configureAutoplay();
      return true;
    }
    if (this.showTranslationSettings) {
      this.showTranslationSettings = false;
      return true;
    }
    if (this.showGestureSettings) {
      this.showGestureSettings = false;
      return true;
    }
    if (this.showPublishBrowseSettings) {
      this.showPublishBrowseSettings = false;
      return true;
    }
    if (this.settingsPanePinned && this.selected != null) {
      this.selected = null;
      this.detailTweets = [];
      this.detailError = '';
      VideoAutoplay.setSelected('');
      return true;
    }
    if (this.settingsSplitActive() && this.settingsDetailOnTop) {
      if (this.settingsDetailHistory.length > 0) {
        const previous = this.settingsDetailHistory.pop();
        if (previous != undefined) {
          const offset = this.settingsDetailScrollHistory.pop() ?? 0;
          this.openSettingsDetail(previous, false, true, offset);
          return true;
        }
      }
      this.closeSettingsDetail();
      this.settingsDetailOnTop = false;
      return true;
    }
    if (this.detailHistory.length > 0) {
      const previous = this.detailHistory.pop();
      if (previous != undefined) {
        this.openDetail(previous, false, true);
        return true;
      }
    }
    if (this.userListVisible) {
      this.userListVisible = false;
      return true;
    }
    if (this.profileDetailReturn.length > 0 && this.selected != null) {
      const handle = this.profileDetailReturn;
      this.profileDetailReturn = '';
      this.selected = null;
      this.detailTweets = [];
      this.detailError = '';
      VideoAutoplay.setSelected('');
      this.profileHandle = handle;
      return true;
    }
    if (this.profileHandle.length > 0) {
      this.closeProfile();
      return true;
    }
    if (this.showEditProfile) {
      this.showEditProfile = false;
      this.loadProfile(true);
      return true;
    }
    if (this.settingsSplitActive() && this.settingsDetail != null) {
      this.closeSettingsDetail();
      return true;
    }
    if (this.settingsSplitActive() && this.settingsSection != 'profile') {
      if (this.settingsSection == 'about' && this.aboutPage != 'main') this.aboutPage = 'main';
      else this.settingsSection = 'profile';
      return true;
    }
    if (this.settingsSplitActive() && this.settingsPanePinned && this.tab != 3) {
      this.settingsPanePinned = false;
      return true;
    }
    if (this.showLanguageSettings) {
      this.showLanguageSettings = false;
      return true;
    }
    if (this.showCacheSettings) {
      this.showCacheSettings = false;
      return true;
    }
    if (this.showAbout) {
      if (this.aboutPage != 'main') this.aboutPage = 'main';
      else this.showAbout = false;
      return true;
    }
    if (this.showMediaSettings) {
      this.showMediaSettings = false;
      return true;
    }
    if (this.showEditProfile) {
      this.showEditProfile = false;
      return true;
    }
    if (this.showThemeSettings) {
      this.showThemeSettings = false;
      return true;
    }
    if (this.profileHandle.length > 0) {
      animateTo({ duration: 280, curve: Curve.FastOutSlowIn }, () => {
        this.profileHandle = '';
      });
      return true;
    }
    if (this.composing) {
      animateTo({ duration: 280, curve: Curve.FastOutSlowIn }, () => {
        this.composing = false;
      });
      return true;
    }
    if (this.selected != null) {
      animateTo({ duration: 280, curve: Curve.FastOutSlowIn }, () => {
        this.selected = null;
        VideoAutoplay.setSelected('');
        this.detailTweets = [];
        this.detailError = '';
      });
      return true;
    }
    if (this.tab != 0) {
      this.tab = 0;
      return true;
    }
    return false;
  }

  private pillWidth(): number {
    const max = Math.max(0, this.paneWidth - this.barGap * 2);
    const natural = this.menuZone * 5 + this.barGap * 4;
    return Math.min(max, natural);
  }

  private bottomInset(): number {
    return this.barHeight + this.barGap * 2 + this.safeBottom;
  }

  private applySplitEnabled(value: boolean): void {
    const wasSplit = this.settingsSplitActive();
    this.splitEnabled = value;
    SessionStore.saveSplitEnabled(getContext(this) as common.UIAbilityContext, value);
    if (!this.navCanSlide()) {
      this.barMode = 1;
      this.updateBarX();
    }
    const isSplit = this.settingsSplitActive();
    this.syncSettingsMode(wasSplit, isSplit);
  }

  private navCanSlide(): boolean {
    return this.contentSplitActive() || this.settingsSplitActive();
  }

  private updateBarX(): void {
    const mode = this.navCanSlide() ? this.barMode : 1;
    let x = (this.paneWidth - this.barWidth) / 2;
    if (mode == 0) x = this.barGap;
    if (mode == 2) x = this.paneWidth - this.barWidth - this.barGap;
    this.barX = Math.max(this.barGap, x);
  }

  private moveBar(target: number): void {
    if (!this.navCanSlide() || target == this.barMode) return;
    animateTo({ duration: 300, curve: Curve.Friction }, () => {
      this.barMode = target;
      this.updateBarX();
    });
  }

  private isInsideNavBar(x: number, y: number): boolean {
    const barBottom = this.paneHeight - this.safeBottom - this.barGap;
    const barTop = barBottom - this.barHeight;
    return y >= barTop && y <= barBottom &&
      x >= this.barX && x <= this.barX + this.barWidth;
  }

  private tapPaneBar(x: number): void {
    if (!this.navCanSlide()) return;
    // Trigger zones are screen thirds, independent of whether split is on
    // and independent of which pane contains the touch.
    if (x < this.paneWidth / 3) this.moveBar(0);
    else if (x > this.paneWidth * 2 / 3) this.moveBar(2);
  }

  private twid(): string {
    const marker = 'twid=';
    const at = this.cookie.indexOf(marker);
    if (at < 0) return '';
    let value = this.cookie.substring(at + marker.length);
    const semi = value.indexOf(';');
    if (semi >= 0) value = value.substring(0, semi);
    try { value = decodeURIComponent(value); } catch (e) {}
    const u = value.indexOf('u=');
    if (u < 0) return '';
    const id = value.substring(u + 2);
    let out = '';
    for (let i = 0; i < id.length; i++) {
      const c = id.charAt(i);
      if (c >= '0' && c <= '9') out += c;
      else break;
    }
    return out;
  }

  private async loadProfile(force: boolean = false): Promise<void> {
    if (this.profileLoading) return;
    if (!force && this.profile != null) return;
    this.profileLoading = true;
    try {
      // Viewer works for both WebView and manually imported cookies. The old
      // UserByRestId queryId is stale and returns 403, so prefer Viewer.
      try {
        this.profile = await XApi.viewerProfile(this.cookie);
        if (this.profile != null) {
          ProfileCache.save(getContext(this) as common.UIAbilityContext, this.profile);
          ProfileCache.saveSelf(getContext(this) as common.UIAbilityContext, this.profile);
          RelationStore.setViewer(this.profile.id);
          this.loadMyTweets(this.profile.id);
          if (this.pendingSaveAccount) {
            const account = new SavedAccount();
            account.id = this.profile.id;
            account.handle = this.profile.handle;
            account.name = this.profile.name;
            account.avatarUrl = this.profile.avatarUrl;
            const ok = await AccountStore.save(getContext(this) as common.UIAbilityContext, account, this.cookie);
            this.pendingSaveAccount = false;
            this.savedAccounts = AccountStore.load(getContext(this) as common.UIAbilityContext);
            if (!ok) promptAction.showToast({ message: this.tr('账号保存失败') });
          }
        }
      } catch (e) {
        const id = this.twid();
        if (id.length > 0) {
          this.profile = await XApi.userByRestId(this.cookie, id);
          if (this.profile != null) {
            ProfileCache.save(getContext(this) as common.UIAbilityContext, this.profile);
            ProfileCache.saveSelf(getContext(this) as common.UIAbilityContext, this.profile);
          }
          this.loadMyTweets(id);
        }
      }
      if (this.homeReady && this.profile != null) this.refreshProfileCache();
    } catch (e) {
      // Keep the page usable; the header can retry.
    } finally {
      this.profileLoading = false;
    }
  }

  private async loadMyTweets(id: string): Promise<void> {
    if (this.myLoading) return;
    this.myLoading = true;
    try {
      const page = await XApi.userTweets(this.cookie, id, '');
      this.myTweets = page.tweets;
    } catch (e) {
      this.myTweets = [];
    } finally {
      this.myLoading = false;
    }
  }

  private async loadNotifications(more: boolean = false): Promise<void> {
    if (this.notificationsLoading) return;
    if (more && this.notificationsCursor.length == 0) return;
    this.notificationsLoading = true;
    this.notificationsError = '';
    try {
      const page = await XApi.notificationsPage(this.cookie, more ? this.notificationsCursor : '');
      this.notifications = more ? this.notifications.concat(page.items) : page.items;
      this.notificationsCursor = page.cursor;
      this.notificationsLoaded = true;
    } catch (e) {
      this.notificationsError = `${e}`;
    } finally {
      this.notificationsLoading = false;
    }
  }

  private openNotification(item: NotificationItem): void {
    if (item.tweetId.length == 0) return;
    const tweet = new TweetItem();
    tweet.id = item.tweetId;
    tweet.authorName = item.authorName;
    tweet.authorHandle = item.authorHandle;
    this.openContentDetail(tweet);
  }

  private openQuoted(id: string): void {
    if (id.length == 0) return;
    const tweet = new TweetItem();
    tweet.id = id;
    this.openDetail(tweet, this.selected != null);
  }

  private openContentDetail(item: TweetItem): void {
    this.userListVisible = false;
    this.profileDetailReturn = '';
    this.settingsDetailOnTop = false;
    this.profileHandle = '';
    this.openDetail(item, false);
  }

  private openNestedProfile(handle: string): void {
    this.userListVisible = false;
    this.profileDetailReturn = '';
    this.settingsDetailOnTop = false;
    this.profileHandle = handle;
  }

  private openContentProfile(handle: string): void {
    this.userListVisible = false;
    this.profileDetailReturn = '';
    this.settingsDetailOnTop = false;
    this.profileHandle = handle;
  }

  private openProfileTweet(item: TweetItem): void {
    if (this.settingsSplitActive()) {
      this.settingsDetailOnTop = true;
      this.openSettingsDetail(item, false);
      return;
    }
    if (this.profileHandle.length > 0) this.profileDetailReturn = this.profileHandle;
    this.profileHandle = '';
    this.userListVisible = false;
    this.openDetail(item, false);
  }

  private focalFirst(item: TweetItem, tweets: TweetItem[]): TweetItem[] {
    const rows = tweets.slice();
    for (let i = 0; i < rows.length; i++) {
      if (rows[i].id == item.id) {
        const found = rows.splice(i, 1)[0];
        const display = found.text.length > 0 ? found : item;
        rows.unshift(display);
        return rows;
      }
    }
    rows.unshift(item);
    return rows;
  }

  private async openDetail(item: TweetItem, push: boolean = true,
    preserveHistory: boolean = false, restoreOffset: number = -1): Promise<void> {
    // Opening a post detail is an explicit right-pane navigation. Release
    // the settings pane first so the detail renderer is mounted immediately.
    if (this.settingsPanePinned) {
      this.settingsPanePinned = false;
      this.restoreSettingsAfterDetail = true;
    }
    const same = this.selected != null && this.selected.id == item.id;
    if (!same) {
      if (push && this.selected != null) {
        let offset = 0;
        try { offset = this.detailScroller.currentOffset().yOffset; } catch (e) {}
        this.detailHistory.push(this.selected);
        this.detailScrollHistory.push(offset);
        while (this.detailHistory.length > 7) {
          this.detailHistory.shift();
          this.detailScrollHistory.shift();
        }
      } else if (!preserveHistory) {
        this.detailHistory = [];
        this.detailScrollHistory = [];
      }
    }
    this.detailOffsetX = 18;
    this.detailPageOpacity = 0.2;
    animateTo({ duration: 280, curve: Curve.FastOutSlowIn }, () => {
      this.selected = item;
      this.detailOffsetX = 0;
      this.detailPageOpacity = 1;
    });
    VideoAutoplay.setSelected(item.id);
    this.detailError = '';
    const cached = DetailCache.get(item.id);
    if (cached != null) {
      this.detailTweets = this.focalFirst(item, cached);
      this.detailLoading = false;
      this.settleDetailScroll(restoreOffset);
      return;
    }
    this.detailTweets = [item];
    this.detailLoading = true;
    try {
      const page = await XApi.tweetDetail(this.cookie, item.id);
      if (page.tweets.length > 0) {
        this.detailTweets = this.focalFirst(item, page.tweets);
        DetailCache.put(item.id, this.detailTweets);
      }
    } catch (e) {
      this.detailError = `${e}`;
    } finally {
      this.detailLoading = false;
    }
  }

  private settleDetailScroll(offset: number): void {
    setTimeout(() => {
      try {
        if (offset > 0) {
          this.detailScroller.scrollTo({ xOffset: 0, yOffset: offset, animation: false });
        } else {
          this.detailScroller.scrollToIndex(0, false, ScrollAlign.START);
        }
      } catch (e) {}
    }, 80);
  }

  private settingsDetailFade(): void {
    this.settingsDetailOffsetX = 18;
    this.settingsDetailOpacity = 0.2;
    animateTo({ duration: 280, curve: Curve.FastOutSlowIn }, () => {
      this.settingsDetailOffsetX = 0;
      this.settingsDetailOpacity = 1;
    });
  }

  private async openSettingsDetail(item: TweetItem, push: boolean = true,
    preserveHistory: boolean = false, restoreOffset: number = -1): Promise<void> {
    const same = this.settingsDetail != null && this.settingsDetail.id == item.id;
    if (!same) {
      if (push && this.settingsDetail != null) {
        let offset = 0;
        try { offset = this.settingsDetailScroller.currentOffset().yOffset; } catch (e) {}
        this.settingsDetailHistory.push(this.settingsDetail);
        this.settingsDetailScrollHistory.push(offset);
        while (this.settingsDetailHistory.length > 7) {
          this.settingsDetailHistory.shift();
          this.settingsDetailScrollHistory.shift();
        }
      } else if (!preserveHistory) {
        this.settingsDetailHistory = [];
        this.settingsDetailScrollHistory = [];
      }
    }
    this.settingsDetailOnTop = true;
    this.settingsDetailFade();
    this.settingsDetail = item;
    this.settingsDetailError = '';
    const cached = DetailCache.get(item.id);
    if (cached != null) {
      this.settingsDetailTweets = this.focalFirst(item, cached);
      this.settingsDetailLoading = false;
      this.settleSettingsDetailScroll(restoreOffset);
      return;
    }
    this.settingsDetailTweets = [item];
    this.settingsDetailLoading = true;
    try {
      const page = await XApi.tweetDetail(this.cookie, item.id);
      if (page.tweets.length > 0) {
        this.settingsDetailTweets = this.focalFirst(item, page.tweets);
        DetailCache.put(item.id, this.settingsDetailTweets);
      }
    } catch (e) {
      this.settingsDetailError = `${e}`;
    } finally {
      this.settingsDetailLoading = false;
      this.settleSettingsDetailScroll(restoreOffset);
    }
  }

  private settleSettingsDetailScroll(offset: number): void {
    setTimeout(() => {
      try {
        if (offset > 0) {
          this.settingsDetailScroller.scrollTo({ xOffset: 0, yOffset: offset, animation: false });
        } else {
          this.settingsDetailScroller.scrollToIndex(0, false, ScrollAlign.START);
        }
      } catch (e) {}
    }, 80);
  }

  private closeSettingsDetail(): void {
    this.settingsDetailOnTop = false;
    this.settingsDetail = null;
    this.settingsDetailHistory = [];
    this.settingsDetailScrollHistory = [];
    this.settingsDetailTweets = [];
    this.settingsDetailError = '';
    this.settingsDetailLoading = false;
  }

  private openSettingsQuoted(id: string): void {
    if (id.length == 0) return;
    const tweet = new TweetItem();
    tweet.id = id;
    this.openSettingsDetail(tweet, this.settingsDetail != null);
  }

  private prefetchDetail(item: TweetItem): void {
    if (DetailCache.get(item.id) != null) return;
    XApi.tweetDetail(this.cookie, item.id).then((page) => {
      if (page.tweets.length > 0) DetailCache.put(item.id, page.tweets);
    }).catch(() => {});
  }

  private openReply(item: TweetItem): void {
    this.replyId = item.id;
    this.replyHandle = item.authorHandle;
    this.quoteId = '';
    this.quoteText = '';
    this.composing = true;
  }

  private openQuote(item: TweetItem): void {
    this.quoteId = item.id;
    this.quoteHandle = item.authorHandle;
    this.quoteText = item.text;
    this.replyId = '';
    this.replyHandle = '';
    this.composing = true;
  }

  private async useSavedAccount(account: SavedAccount): Promise<void> {
    try {
      const authorized = await SystemAuth.authenticate(getContext(this) as common.UIAbilityContext,
        this.tr('验证身份以使用保存的账号'));
      if (!authorized) {
        promptAction.showToast({ message: this.tr('系统认证未通过，无法使用保存的账号') });
        return;
      }
      const cookie = await AccountStore.cookie(account);
      if (cookie.length == 0) throw new Error(this.tr('保存的登录信息不存在'));
      const profile = await XApi.viewerProfile(cookie);
      this.cookie = cookie;
      this.profile = profile;
      this.loggedIn = true;
      ProfileCache.save(getContext(this) as common.UIAbilityContext, profile);
      ProfileCache.saveSelf(getContext(this) as common.UIAbilityContext, profile);
      RelationStore.setViewer(profile.id);
      SessionStore.saveCookie(getContext(this) as common.UIAbilityContext, cookie);
      this.loadMyTweets(profile.id);
    } catch (e) {
      promptAction.showToast({ message: this.tr(`恢复账号失败：${e}`), duration: 3000 });
    }
  }

  private confirmClearBrowsing(): void {
    AlertDialog.show({
      title: this.tr('清除浏览历史'),
      message: this.tr('将删除主页时间线缓存和其他浏览缓存；不会删除搜索历史和我的资料。'),
      autoCancel: true,
      primaryButton: { value: this.tr('取消'), action: () => {} },
      secondaryButton: { value: this.tr('清除'), fontColor: '#F4212E', action: () => {
        const context = getContext(this) as common.UIAbilityContext;
        CacheStore.clearBrowsing(context);
        HomeTimelineCache.clear(context);
        this.refreshCacheUsage();
        promptAction.showToast({ message: this.tr('浏览历史已清除') });
      } }
    });
  }

  private confirmClearSearch(): void {
    AlertDialog.show({
      title: this.tr('清除搜索历史'),
      message: this.tr('将删除搜索词条和当前搜索结果的运行时快照。'),
      autoCancel: true,
      primaryButton: { value: this.tr('取消'), action: () => {} },
      secondaryButton: { value: this.tr('清除'), fontColor: '#F4212E', action: () => {
        const context = getContext(this) as common.UIAbilityContext;
        SearchHistoryStore.clear(context);
        SearchSnapshotStore.clearAll(context);
        this.refreshCacheUsage();
        promptAction.showToast({ message: this.tr('搜索历史已清除') });
      } }
    });
  }

  private confirmClearMyData(): void {
    AlertDialog.show({
      title: this.tr('清除我的资料'),
      message: this.tr('将删除我的发帖、回复、转帖三个子标签的本地缓存。'),
      autoCancel: true,
      primaryButton: { value: this.tr('取消'), action: () => {} },
      secondaryButton: { value: this.tr('清理'), fontColor: '#F4212E', action: () => {
        const context = getContext(this) as common.UIAbilityContext;
        CacheStore.clearOwn(context);
        this.refreshCacheUsage();
        promptAction.showToast({ message: this.tr('我的资料缓存已清除') });
      } }
    });
  }

  private confirmClearAll(): void {
    AlertDialog.show({
      title: this.tr('清除全部缓存'),
      message: this.tr('将清除浏览历史、搜索历史和我的资料缓存；登录凭据、账号信息和设置会保留。'),
      autoCancel: true,
      primaryButton: { value: this.tr('取消'), action: () => {} },
      secondaryButton: { value: this.tr('清除'), fontColor: '#F4212E', action: () => {
        const context = getContext(this) as common.UIAbilityContext;
        CacheStore.clearBrowsing(context);
        HomeTimelineCache.clear(context);
        CacheStore.clearOwn(context);
        SearchHistoryStore.clear(context);
        SearchSnapshotStore.clearAll(context);
        this.refreshCacheUsage();
        promptAction.showToast({ message: this.tr('全部缓存已清除') });
      } }
    });
  }

  private confirmClearCache(): void {
    AlertDialog.show({
      title: this.tr('清理本地缓存'),
      message: this.tr('将删除资料页帖子/回复/转贴缓存和已缓存图片；登录凭据、账号信息和设置会保留。'),
      autoCancel: true,
      primaryButton: { value: this.tr('取消'), action: () => {} },
      secondaryButton: { value: this.tr('清理'), fontColor: '#F4212E', action: () => this.clearCacheNow() }
    });
  }

  private async clearCacheNow(): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext;
    CacheStore.clear(context);
    this.cacheUsedMb = 0;
    this.cacheRefreshed = false;
    promptAction.showToast({ message: this.tr('缓存已清理，正在重新缓存') });
    if (this.profile != null) {
      const settings = new CacheSettings();
      settings.maxItems = 100;
      settings.maxMb = this.cacheMaxMb;
      settings.profileMaxCount = 100;
      settings.profileMaxMb = this.cacheMaxMb;
      await ProfileCache.recache(context, this.cookie, this.profile.handle, settings);
      this.refreshCacheUsage();
    }
  }

  private confirmLogout(): void {
    this.logoutDialog.open();
  }

  private confirmDeleteSavedAccount(): void {
    AlertDialog.show({
      title: this.tr('删除本机账号？'),
      message: this.tr('将删除本机保存的 Cookie、登录状态和账号信息。此操作无法恢复，之后需要重新登录。'),
      autoCancel: true,
      primaryButton: { value: this.tr('取消'), action: () => {} },
      secondaryButton: { value: this.tr('删除并退出'), fontColor: '#F4212E', action: () => { this.logout(false); } }
    });
  }

  private async logout(preserveSaved: boolean): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext;
    if (!preserveSaved && this.profile != null) {
      const account = this.savedAccounts.find((a: SavedAccount) => a.handle == this.profile!.handle);
      if (account != undefined) await AccountStore.remove(context, account);
    }
    SessionStore.clear(context);
    if (!preserveSaved) {
      ProfileCache.clearAll(context);
      CacheStore.clear(context);
      HomeTimelineCache.clear(context);
      SearchHistoryStore.clear(context);
      this.cacheUsedMb = 0;
      this.cacheOwnUsedMb = 0;
    }
    this.cookie = '';
    this.loggedIn = false;
    this.selected = null;
    VideoAutoplay.setSelected('');
    this.cacheRefreshed = false;
    this.homeReady = false;
    this.tab = 0;
    this.profile = null;
    this.myTweets = [];
    this.notifications = [];
    this.notificationsLoaded = false;
    this.notificationsCursor = '';
    this.detailTweets = [];
    this.pendingSaveAccount = false;
    this.showWebLogin = false;
    this.loginPage = 'home';
    this.savedAccounts = AccountStore.load(context);
    DetailCache.clear();
    AppStorage.setOrCreate('tuichuang_home_offset', 0);
  }

  private saveMediaSettings(): void {
    SessionStore.saveMediaSettings(getContext(this) as common.UIAbilityContext,
      this.imageLimitMb, this.gifLimitMb, this.imageQuality, this.gifQuality);
  }

  private savePlaybackSettings(): void {
    const settings = new PlaybackSettings();
    settings.autoPlay = this.autoPlay;
    settings.autoPlayMuted = this.autoPlayMuted;
    settings.fullscreenMuted = this.fullscreenMuted;
    settings.volumeRatio = this.volumeRatio;
    settings.fullscreenVolumeRatio = this.fullscreenVolumeRatio;
    settings.fullscreenGestures = this.fullscreenGestures;
    PlaybackSettingsStore.save(getContext(this) as common.UIAbilityContext, settings);
    this.configureAutoplay();
  }

  private configureAutoplay(): void {
    const settings = new PlaybackSettings();
    settings.autoPlay = this.autoPlay;
    settings.autoPlayMuted = this.autoPlayMuted;
    settings.fullscreenMuted = this.fullscreenMuted;
    settings.volumeRatio = this.volumeRatio;
    settings.fullscreenVolumeRatio = this.fullscreenVolumeRatio;
    settings.fullscreenGestures = this.fullscreenGestures;
    VideoAutoplay.configure(settings, this.selected != null ? this.selected.id : '', this.playingVideo.length > 0);
  }

  private saveCacheSettings(): void {
    const settings = new CacheSettings();
    settings.maxItems = 100;
    settings.maxMb = this.cacheMaxMb;
    settings.ownMaxItems = 100;
    settings.ownPostsMax = this.cacheOwnPostsMax;
    settings.ownRepliesMax = this.cacheOwnRepliesMax;
    settings.ownRepostsMax = this.cacheOwnRepostsMax;
    settings.clearBrowsingOnExit = this.cacheClearBrowsingOnExit;
    settings.profileMaxCount = 100;
    settings.profileMaxMb = this.cacheMaxMb;
    CacheSettingsStore.save(getContext(this) as common.UIAbilityContext, settings);
  }

  private refreshCacheUsage(): void {
    const context = getContext(this) as common.UIAbilityContext;
    this.cacheOwnUsedMb = CacheStore.usedMb(context, true);
    this.cacheUsedMb = CacheStore.usedMb(context, false) + ProfileCache.usedMb(context) +
      (SearchHistoryStore.usedBytes(context) + HomeTimelineCache.usedBytes(context)) / (1024 * 1024);
  }

  private onProfileCacheDirty(): void {
    if (this.cacheRefreshTimer >= 0) clearTimeout(this.cacheRefreshTimer);
    this.cacheRefreshTimer = setTimeout(() => {
      this.cacheRefreshTimer = -1;
      this.refreshProfileCache(true);
    }, 1800);
  }

  private async refreshProfileCache(force: boolean = false): Promise<void> {
    if (this.profile == null || this.cookie.length == 0 || this.cacheRefreshing) return;
    if (!force && this.cacheRefreshed) return;
    this.cacheRefreshing = true;
    this.cacheRefreshed = true;
    const settings = new CacheSettings();
    settings.maxItems = 100;
    settings.maxMb = this.cacheMaxMb;
    settings.ownMaxItems = 100;
    settings.ownPostsMax = this.cacheOwnPostsMax;
    settings.ownRepliesMax = this.cacheOwnRepliesMax;
    settings.ownRepostsMax = this.cacheOwnRepostsMax;
    settings.clearBrowsingOnExit = this.cacheClearBrowsingOnExit;
    settings.profileMaxCount = 100;
    settings.profileMaxMb = this.cacheMaxMb;
    try {
      await ProfileCache.refresh(getContext(this) as common.UIAbilityContext, this.cookie, this.profile.handle, settings);
      this.refreshCacheUsage();
      AppStorage.setOrCreate('profileCacheUpdated', Date.now());
    } finally {
      this.cacheRefreshing = false;
    }
  }


  private refreshRelations(): void {
    if (this.profile == null || this.cookie.length == 0) return;
    RelationStore.setViewer(this.profile.id);
    RelationStore.refreshIfStale(this.cookie, this.profile.id, false).catch(() => {});
  }

  private translationSummary(): string {
    if (!this.translationEnabled) return '已关闭';
    const target = this.languageLabel(this.translationTarget);
    const exception = this.languageLabel(this.translationException);
    return `目标 ${target} · 例外 ${exception}`;
  }

  private languageLabel(code: string): string {
    if (code == 'ar') return '阿拉伯语';
    if (code == 'zh-cn') return '中文';
    if (code == 'en') return 'English';
    if (code == 'fr') return '法语';
    if (code == 'ru') return '俄语';
    if (code == 'es') return '西班牙语';
    return code;
  }

  private saveTranslationSettings(): void {
    const next = new TranslationSettings();
    next.enabled = this.translationEnabled;
    next.targetLang = this.translationTarget;
    next.exceptionLang = this.translationException;
    TranslationSettingsStore.save(getContext(this) as common.UIAbilityContext, next);
  }

  private setTranslationEnabled(value: boolean): void {
    this.translationEnabled = value;
    this.saveTranslationSettings();
  }

  private setTranslationTarget(code: string): void {
    this.translationTarget = code;
    this.saveTranslationSettings();
  }

  private setTranslationException(code: string): void {
    this.translationException = code;
    this.saveTranslationSettings();
  }

  private updateTranslationSettings(next: TranslationSettings): void {
    this.translationSettings = next;
    this.translationEnabled = next.enabled;
    this.translationTarget = next.targetLang;
    this.translationException = next.exceptionLang;
    TranslationSettingsStore.save(getContext(this) as common.UIAbilityContext, next);
  }

  private applySystemBars(): void {
    if (this.mainWin == null) return;
    try {
      this.mainWin.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000',
        isStatusBarLightIcon: this.isDarkTheme,
        isNavigationBarLightIcon: this.isDarkTheme,
        statusBarContentColor: this.isDarkTheme ? '#FFFFFF' : '#000000',
        navigationBarContentColor: this.isDarkTheme ? '#FFFFFF' : '#000000'
      }).catch(() => {});
    } catch (e) {}
  }

  private changeLanguage(mode: string): void {
    const context = getContext(this) as common.UIAbilityContext;
    LanguageSettingsStore.save(context, mode);
    // Switch the shared translator before mutating UI state so that the
    // rebuild triggered by languageMode already reads the new language.
    LanguageSettingsStore.apply(mode);
    this.languageMode = mode;
    AppStorage.setOrCreate('clientLang', I18n.language());
  }

  private setThemeMode(mode: string): void {
    this.themeMode = mode;
    const context = getContext(this) as common.UIAbilityContext;
    SessionStore.saveThemeMode(context, mode);
    this.isDarkTheme = ThemeUtil.apply(context, mode);
    AppStorage.setOrCreate('tuichuang_dark', this.isDarkTheme);
    this.applySystemBars();
  }

  private splitWidth(): number {
    if (this.paneWidth <= 0) return 0;
    const min = 300;
    if (!this.splitUserAdjusted) {
      const preferred = this.settingsSideWidth();
      return Math.max(min, Math.min(this.paneWidth - min, preferred));
    }
    return Math.max(min, Math.min(this.paneWidth - min, this.paneWidth * this.splitRatio));
  }

  private leftPaneWidth(): number {
    // Width follows the right pane's content mode, not the left tab.
    // A detail pane keeps its existing draggable split; only a settings
    // pane uses the fixed 4:6 settings layout.
    if (this.settingsPanePinned) return this.settingsSideWidth();
    if (this.contentSplitActive()) return this.splitWidth();
    return this.paneWidth;
  }

  private settingsSideWidth(): number {
    if (this.paneWidth <= 0) return 0;
    // 4:6 by default, while keeping both panes at least 300vp.
    return Math.max(300, Math.min(this.paneWidth - 300, this.paneWidth * 0.4));
  }

  private wideEnoughForSplit(): boolean {
    // Layout follows the current window, not the fold state: a narrow window
    // on an unfolded device stays single-column, while a wide tablet window
    // can split without being foldable.
    return this.paneWidth >= SPLIT_BREAKPOINT_VP;
  }

  private contentSplitActive(): boolean {
    return this.wideEnoughForSplit() && this.splitEnabled;
  }

  private settingsSplitActive(): boolean {
    return this.wideEnoughForSplit() && this.splitEnabled &&
      (this.tab == 3 || this.settingsPanePinned);
  }

  private anySettingsOverlayOpen(): boolean {
    return this.showThemeSettings || this.showLanguageSettings ||
      this.showPublishBrowseSettings || this.showMediaSettings ||
      this.showCacheSettings || this.showAbout || this.showGestureSettings ||
      this.showTranslationSettings;
  }

  private closeSettingsOverlays(): void {
    this.showThemeSettings = false;
    this.showLanguageSettings = false;
    this.showPublishBrowseSettings = false;
    this.showMediaSettings = false;
    this.showCacheSettings = false;
    this.showAbout = false;
    this.showGestureSettings = false;
    this.showTranslationSettings = false;
    this.settingsSection = 'profile';
  }

  private syncSettingsMode(wasSplit: boolean, isSplit: boolean): void {
    if (wasSplit == isSplit) return;
    if (isSplit) this.moveSettingsIntoSplit();
    else { this.settingsPanePinned = false; this.moveSettingsIntoSingle(); }
    this.lastSettingsSplit = isSplit;
  }

  private moveSettingsIntoSplit(): void {
    const editOpen = this.showEditProfile;
    const gestureOpen = this.showGestureSettings;
    const translationOpen = this.showTranslationSettings;
    const publishOpen = this.showPublishBrowseSettings;
    const themeOpen = this.showThemeSettings;
    const languageOpen = this.showLanguageSettings;
    const mediaOpen = this.showMediaSettings;
    const cacheOpen = this.showCacheSettings;
    const aboutOpen = this.showAbout;

    if (this.userListVisible) this.settingsSection = 'profile';
    else if (editOpen) this.settingsSection = 'profile';
    else if (gestureOpen) this.settingsSection = 'multimedia';
    else if (publishOpen) this.settingsSection = 'publish';
    else if (translationOpen) this.settingsSection = 'translate';
    else if (themeOpen) this.settingsSection = 'theme';
    else if (languageOpen) this.settingsSection = 'language';
    else if (mediaOpen) this.settingsSection = 'media';
    else if (cacheOpen) this.settingsSection = 'cache';
    else if (aboutOpen) this.settingsSection = 'about';
    else this.settingsSection = 'profile';

    this.showThemeSettings = false;
    this.showLanguageSettings = false;
    this.showMediaSettings = false;
    this.showCacheSettings = false;
    this.showAbout = false;
    this.showGestureSettings = gestureOpen;
    this.showTranslationSettings = translationOpen;
    this.showPublishBrowseSettings = publishOpen;
    this.showEditProfile = editOpen;
  }

  private moveSettingsIntoSingle(): void {
    const section = this.settingsSection;
    this.showThemeSettings = section == 'theme';
    this.showLanguageSettings = section == 'language';
    this.showMediaSettings = section == 'media';
    this.showCacheSettings = section == 'cache';
    this.showAbout = section == 'about';
    this.showGestureSettings = section == 'multimedia' && this.showGestureSettings;
    this.showTranslationSettings = section == 'multimedia' && this.showTranslationSettings;
    this.showPublishBrowseSettings = section == 'publish' || section == 'multimedia';
    this.showEditProfile = section == 'profile' && this.showEditProfile;
  }

  private navDisplayLabel(index: number, label: string): string {
    // System navigation bars keep short labels. “Notifications” is too wide
    // for a five-slot floating bar, so use the concise “Alerts” in English.
    if (index == 2 && I18n.isEnglish()) return 'Alerts';
    return this.tr(label);
  }

  @Builder
  navItem(index: number, icon: Resource, label: string) {
    Column() {
      Image(icon).width(24).height(24)
        .fillColor(this.tab == index ? $r('app.color.nav_active') : $r('app.color.text_secondary'))
      Text(this.navDisplayLabel(index, label)).fontSize(10)
        .fontColor(this.tab == index ? $r('app.color.nav_active') : $r('app.color.text_secondary'))
        .maxLines(1).margin({ top: 2 })
    }
    .layoutWeight(1).height(52).justifyContent(FlexAlign.Center)
    .accessibilityText(this.tr(label))
    .onClick(() => {
      const splitBefore = this.settingsSplitActive();
      const overlayOpen = this.anySettingsOverlayOpen();

      // Single-column settings subpages are overlays. A nav-bar tap must
      // dismiss them before switching the visible page.
      if (!splitBefore && overlayOpen) this.closeSettingsOverlays();

      // A profile page opened from the home timeline or from the profile
      // summary is an overlay above the tab content. Clear it as well,
      // otherwise the tab selection changes underneath a page that still
      // covers the whole content area.
      if (!splitBefore) {
        this.profileHandle = '';
        this.profileDetailReturn = '';
        this.showEditProfile = false;
        this.userListVisible = false;
        this.settingsDetailOnTop = false;
      }

      // In split mode the right pane is independent from the left tab.
      // A pinned settings pane survives tab changes; a detail pane is left
      // untouched because its own state is not modified here.

      if (index == 3) this.refreshRelations();

      if (this.selected != null && !this.contentSplitActive()) {
        animateTo({ duration: 280, curve: Curve.FastOutSlowIn }, () => {
          this.selected = null;
          VideoAutoplay.setSelected('');
          this.detailTweets = [];
          this.detailError = '';
        });
        if (index == 0) {
          this.tab = 0;
          VideoAutoplay.setActive(true);
          return;
        }
      }

      if (index == 0) {
        this.closeComposeIfOpen();
        if (this.tab == 0) this.homeTapTick += 1;
        else this.tab = 0;
        VideoAutoplay.setActive(true);
        return;
      }

      this.closeComposeIfOpen();

      if (index == 3) {
        // Entering the profile/settings tab in split mode opens the settings
        // pane. If it was already open, keep its current right-page state.
        if (this.wideEnoughForSplit() && this.splitEnabled) {
          const rightHasDetail = this.selected != null || this.settingsDetail != null ||
            this.profileHandle.length > 0 || this.userListVisible;
          if (!this.settingsPanePinned && !rightHasDetail) {
            this.settingsPanePinned = true;
          }
          if (this.tab != 3) this.previousTab = this.tab;
          this.tab = 3;
          return;
        }
        // A single-column settings subpage was just dismissed: land on the
        // settings menu instead of toggling back to the previous tab.
        if (overlayOpen) {
          this.tab = 3;
          this.settingsSection = 'profile';
          return;
        }
        this.settingsSection = 'profile';
        if (this.tab == 3) {
          this.tab = this.previousTab;
        } else {
          this.previousTab = this.tab;
          this.tab = 3;
        }
        this.selected = null;
        VideoAutoplay.setSelected('');
        this.detailTweets = [];
        VideoAutoplay.setActive(this.tab == 0 || this.tab == 1);
        return;
      }

      const wasTab = this.tab;
      this.tab = index;
      VideoAutoplay.setActive(index == 1);
      if (index == 1 && wasTab == 1) this.trendsHomeTick += 1;
      if (index == 2) {
        if (wasTab == 2) this.loadNotifications(false);
        else if (!this.notificationsLoaded) this.loadNotifications(false);
      }
    })
  }

  @Builder
  bottomBar() {
    Stack({ alignContent: Alignment.Start }) {

      Row()
        .width('100%').height('100%')
        .radialGradient({
          center: [this.lightX, this.barHeight / 2],
          radius: 80,
          colors: [['#80FFFFFF', 0.0], ['#00FFFFFF', 1.0]]
        })
        .opacity(this.lightOpacity)
        .hitTestBehavior(HitTestMode.None)

      Row()
        .width(90).height('100%')
        .linearGradient({
          angle: 90,
          colors: [['#00FFFFFF', 0.0], ['#80FFFFFF', 0.5], ['#00FFFFFF', 1.0]]
        })
        .blur(8).opacity(0.22)
        .offset({ x: this.sheenX })
        .hitTestBehavior(HitTestMode.None)

      Row() {
        this.navItem(0, $r('app.media.ic_home'), '主页')
        this.navItem(1, $r('app.media.ic_search'), '趋势')
        Column() {
          Button() {
            Image($r('app.media.ic_plus')).width(23).height(23).fillColor($r('app.color.plus_icon'))
          }
          .width(44).height(44).borderRadius(22).backgroundColor($r('app.color.plus_bg'))
          .onClick(() => {
            if (this.composing) this.closeCompose();
            else { this.replyId = ''; this.quoteId = ''; this.composing = true; }
          })
        }.layoutWeight(1).height(52).justifyContent(FlexAlign.Center)
        this.navItem(2, $r('app.media.ic_bell'), '通知')
        this.navItem(3, $r('app.media.ic_user'), '我的')
      }
      .width('100%').height('100%').padding({ left: 6, right: 6 })
    }
    .width(this.barWidth).height(this.barHeight).borderRadius(this.barHeight / 2)
    .clip(true)
    .backgroundColor(this.barOpaque ? $r('app.color.bar_bg') : Color.Transparent)
    .backgroundBlurStyle(this.barOpaque ? BlurStyle.NONE : BlurStyle.BACKGROUND_ULTRA_THICK, {
      colorMode: this.isDarkTheme ? ThemeColorMode.DARK : ThemeColorMode.LIGHT,
      adaptiveColor: AdaptiveColor.AVERAGE,
      scale: 1.0,
      policy: BlurStyleActivePolicy.FOLLOWS_WINDOW_ACTIVE_STATE,
      inactiveColor: $r('app.color.bar_inactive')
    })
    .border({ width: 1, color: $r('app.color.bar_border') })
    .shadow({ radius: 18, color: '#26000000', offsetY: 5 })
    .margin({ bottom: this.barGap + this.safeBottom })
    .onTouchIntercept((event: TouchEvent) => {
      if (event.touches.length > 0) {
        const x = event.touches[0].x;
        if (event.type == TouchType.Down || event.type == TouchType.Move) {
          this.lightX = x;
          this.lightOpacity = 0.9;
        }
      }
      if (event.type == TouchType.Up || event.type == TouchType.Cancel) {
        animateTo({ duration: 320, curve: Curve.EaseOut }, () => { this.lightOpacity = 0; });
      }
      return HitTestMode.Default;
    })
    .onAreaChange((oldValue: Area, newValue: Area) => {
      const w = parseFloat(`${newValue.width}`);
      // onAreaChange also fires when the bar moves. Only recenter when its
      // width actually changes; otherwise every drag would snap it back.
      if (!isNaN(w) && w > 0 && Math.abs(w - this.barWidth) > 0.5) {
        this.barWidth = w;
        this.updateBarX();
      }
    })
  }


  @Builder
  settingsMenuRow(id: string, title: string) {
    Row() {
      Text(this.tr(title)).fontSize(16).fontColor($r('app.color.text_primary')).layoutWeight(1)
      Text('›').fontSize(20).fontColor($r('app.color.text_secondary'))
    }
    .width('100%').padding(16).borderRadius(14)
    .backgroundColor(this.settingsSection == id ? $r('app.color.accent_soft') : Color.Transparent)
    .onClick(() => {
      this.closeSettingsDetail();
      this.settingsDetailOnTop = false;
      this.userListVisible = false;
      this.showGestureSettings = false;
      this.showTranslationSettings = false;
      this.showPublishBrowseSettings = false;
      this.profileHandle = '';
      this.settingsSection = id;
      this.settingsPanePinned = true;
      this.restoreSettingsAfterDetail = false;
      this.selected = null;
      this.detailTweets = [];
      this.detailError = '';
      VideoAutoplay.setSelected('');
      if (id == 'about') this.aboutPage = 'main';
      if (id == 'cache') this.refreshCacheUsage();
    })
  }

  @Builder
  settingsMenuPage() {
    Column() {
      Text(this.tr('设置')).fontSize(30).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%').padding({ left: 20, right: 20, top: 10, bottom: 14 })

      Scroll() {
        Column() {
          this.myProfileSummary()

          Column() {
            this.settingsMenuRow('theme', '外观')
          }
          .width('100%').backgroundColor($r('app.color.surface')).borderRadius(20)
          .margin({ top: 12 }).clip(true)

          Column() {
            this.settingsMenuRow('publish', '发送与播放')
            Divider().strokeWidth(1.5).color($r('app.color.divider')).margin({ left: 16, right: 16 })
            this.settingsMenuRow('translate', '自动翻译')
          }
          .width('100%').backgroundColor($r('app.color.surface')).borderRadius(20)
          .margin({ top: 12 }).clip(true)

          Column() {
            this.settingsMenuRow('cache', '本地缓存')
          }
          .width('100%').backgroundColor($r('app.color.surface')).borderRadius(20)
          .margin({ top: 12 }).clip(true)

          Column() {
            this.settingsMenuRow('about', '关于')
          }
          .width('100%').backgroundColor($r('app.color.surface')).borderRadius(20)
          .margin({ top: 12 }).clip(true)

          Row() {
            Text(this.tr('退出登录'))
              .fontSize(16).fontColor('#F4212E')
              .width('100%').textAlign(TextAlign.Center)
          }
          .width('100%').height(52)
          .backgroundColor($r('app.color.surface')).borderRadius(20)
          .margin({ top: 12 })
          .onClick(() => this.confirmLogout())

          Blank().height(this.bottomInset() + 20)
        }
        .width('100%').padding({ left: 16, right: 16 })
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off).align(Alignment.Top)
    }
    .width('100%').height('100%')
    .justifyContent(FlexAlign.Start)
    .backgroundColor($r('app.color.grouped_bg'))
  }

  @Builder
  settingsDetailContent() {
    Column() {
      SettingsPageHeader({
        title: '帖子',
        showBack: true,
        onBack: () => this.closeSettingsDetail()
      })

      if (this.settingsDetailError.length > 0) {
        Column() {
          Text(this.settingsDetailError).fontSize(13).fontColor('#F4212E').padding(16)
          Button(this.tr('重试')).onClick(() => {
            if (this.settingsDetail != null) this.openSettingsDetail(this.settingsDetail);
          })
        }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else {
        List({ scroller: this.settingsDetailScroller }) {
          ForEach(this.settingsDetailTweets, (item: TweetItem) => {
            ListItem() {
              Column() {
                TweetCard({
                  item: item,
                  cookie: this.cookie,
                  onReply: (value: TweetItem) => this.openReply(value),
                  onQuote: (value: TweetItem) => this.openQuote(value),
                  onOpen: (value: TweetItem) => this.openSettingsDetail(value, true),
                  onPlay: (value: TweetItem, startTime: number) => {
                    this.playingVideoStart = startTime;
                    this.playingVideoPoster = value.imageUrl;
                    this.playingVideo = value.videoUrl;
                    VideoAutoplay.enterFullscreen(value.id);
                  },
                  onImage: (url: string) => { this.viewingImage = url; },
                  onOpenQuoted: (id: string) => this.openSettingsQuoted(id),
                  onOpenUser: (handle: string) => { this.settingsDetailOnTop = false; this.profileHandle = handle; },
                  videoPane: 'right',
                  videoIndex: 0
                })
                Divider().strokeWidth(1).color($r('app.color.divider'))
              }
              .onClick(() => this.openSettingsDetail(item, true))
            }
          }, (item: TweetItem) => item.id)
        }
        .layoutWeight(1).width('100%')
        .contentEndOffset(this.bottomInset())
        .onReachEnd(() => {})
      }

      if (this.settingsDetailLoading) {
        Row() {
          LoadingProgress().width(20).height(20)
          Text(this.tr('加载评论…')).fontSize(12).fontColor($r('app.color.text_secondary')).margin({ left: 8 })
        }.height(32)
      }
    }.width('100%').height('100%')
      .opacity(this.settingsDetailOpacity)
      .translate({ x: this.settingsDetailOffsetX })
      .transition(this.rightPageTransition())
  }

  private rightPageTransition(): TransitionEffect {
    return TransitionEffect.translate({ x: 18 })
      .combine(TransitionEffect.OPACITY)
      .animation({ duration: 280, curve: Curve.FastOutSlowIn });
  }

  @Builder
  settingsRightPane() {
    if (this.settingsDetailOnTop && this.settingsDetail != null) {
      this.settingsDetailContent()
    } else if (this.profileHandle.length > 0) {
      if (this.showEditProfile && this.profile != null) {
        EditProfilePage({
          cookie: this.cookie,
          profile: this.profile,
          onClose: () => {
            this.showEditProfile = false;
            this.loadProfile(true);
          },
          onSaved: (updated: UserProfile) => {
            this.profile = updated;
            ProfileCache.save(getContext(this) as common.UIAbilityContext, updated);
            ProfileCache.saveSelf(getContext(this) as common.UIAbilityContext, updated);
            this.showEditProfile = false;
          }
        })
        .width('100%').height('100%')
        .transition(this.rightPageTransition())
      } else {
        ProfilePage({
          bottomInset: this.bottomInset(),
          embedded: true,
          videoPane: 'right',
          cookie: this.cookie,
          handle: this.profileHandle,
          knownProfile: this.profile != null && this.profileHandle == this.profile!.handle ? this.profile : null,
          onClose: () => this.closeProfile(),
          onEditProfile: () => { this.showEditProfile = true; },
          onOpenConnections: (kind: string, userId: string, title: string) => {
            this.userListKind = kind;
            this.userListId = userId;
            this.userListTitle = title;
            this.userListVisible = true;
          },
          onOpenTweet: (item: TweetItem) => { this.settingsDetailOnTop = true; this.openSettingsDetail(item); },
          onReply: (item: TweetItem) => this.openReply(item),
          onQuote: (item: TweetItem) => this.openQuote(item),
          onPlay: (item: TweetItem, startTime: number) => {
            this.playingVideoStart = startTime;
            this.playingVideoPoster = item.imageUrl;
            this.playingVideo = item.videoUrl;
            VideoAutoplay.enterFullscreen(item.id);
          },
          onImage: (url: string) => { this.viewingImage = url; },
          onOpenQuoted: (id: string) => this.openSettingsQuoted(id),
          onOpenUser: (handle: string) => this.openNestedProfile(handle)
        })
        .width('100%').height('100%')
        .transition(this.rightPageTransition())
      }
    } else if (this.settingsSection == 'publish') {
      if (this.showGestureSettings) {
        GestureSettingsPage({ bottomInset: this.bottomInset(),
          fullscreenGestures: this.fullscreenGestures,
          onGesturesChange: (value: boolean) => { this.fullscreenGestures = value; this.savePlaybackSettings(); },
          onBack: () => { this.showGestureSettings = false; }
        })
          .transition(this.rightPageTransition())
      } else {
        PublishBrowseSettingsPage({ bottomInset: this.bottomInset(),
          imageQuality: this.imageQuality,
          gifQuality: this.gifQuality,
          autoPlay: this.autoPlay,
          autoPlayMuted: this.autoPlayMuted,
          onImageQualityChange: (value: number) => { this.imageQuality = value; this.saveMediaSettings(); },
          onGifQualityChange: (value: number) => { this.gifQuality = value; this.saveMediaSettings(); },
          onAutoPlayChange: (value: boolean) => { this.autoPlay = value; this.savePlaybackSettings(); },
          onAutoPlayMutedChange: (value: boolean) => { this.autoPlayMuted = value; this.savePlaybackSettings(); },
          onOpenGestureSettings: () => { this.showGestureSettings = true; },
          onClose: () => { this.settingsSection = 'profile'; }
        })
          .transition(this.rightPageTransition())
      }
    } else if (this.settingsSection == 'translate') {
      TranslationSettingsPage({ bottomInset: this.bottomInset(),
        showBack: false,
        autoEnabled: this.translationEnabled,
        targetLang: this.translationTarget,
        exceptionLang: this.translationException,
        onEnabledChange: (value: boolean) => this.setTranslationEnabled(value),
        onTargetSelect: (code: string) => this.setTranslationTarget(code),
        onExceptionSelect: (code: string) => this.setTranslationException(code),
        onClose: () => { this.settingsSection = 'profile'; }
      })
        .transition(this.rightPageTransition())
    } else if (this.settingsSection == 'language') {
      LanguageSettingsPage({ bottomInset: this.bottomInset(),
        mode: this.languageMode,
        onSelect: (mode: string) => this.changeLanguage(mode)
      })
        .transition(this.rightPageTransition())
    } else if (this.settingsSection == 'theme') {
      ThemeSettingsPage({ bottomInset: this.bottomInset(),
        mode: this.themeMode,
        splitEnabled: this.splitEnabled,
        barOpaque: this.barOpaque,
        onSplitChange: (value: boolean) => {
          this.applySplitEnabled(value);
        },
        onBarOpaqueChange: (value: boolean) => { this.barOpaque = value; },
        onSelect: (mode: string) => this.setThemeMode(mode),
        onClose: () => { this.settingsSection = 'profile'; }
      })
        .transition(this.rightPageTransition())
    } else if (this.settingsSection == 'media') {
      MediaSettingsPage({ bottomInset: this.bottomInset(),
        imageLimitMb: this.imageLimitMb,
        gifLimitMb: this.gifLimitMb,
        imageQuality: this.imageQuality,
        gifQuality: this.gifQuality,
        onImageLimitChange: (value: number) => { this.imageLimitMb = value; this.saveMediaSettings(); },
        onGifLimitChange: (value: number) => { this.gifLimitMb = value; this.saveMediaSettings(); },
        onImageQualityChange: (value: number) => { this.imageQuality = value; this.saveMediaSettings(); },
        onGifQualityChange: (value: number) => { this.gifQuality = value; this.saveMediaSettings(); },
        onClose: () => { this.settingsSection = 'profile'; }
      })
        .transition(this.rightPageTransition())
    } else if (this.settingsSection == 'multimedia') {
      if (this.showGestureSettings) {
        GestureSettingsPage({ bottomInset: this.bottomInset(),
          fullscreenGestures: this.fullscreenGestures,
          onGesturesChange: (value: boolean) => { this.fullscreenGestures = value; this.savePlaybackSettings(); },
          onBack: () => { this.showGestureSettings = false; }
        })
          .transition(this.rightPageTransition())
      } else if (this.showTranslationSettings) {
        TranslationSettingsPage({ bottomInset: this.bottomInset(),
          showBack: false,
          autoEnabled: this.translationEnabled,
          targetLang: this.translationTarget,
          exceptionLang: this.translationException,
          onEnabledChange: (value: boolean) => this.setTranslationEnabled(value),
          onTargetSelect: (code: string) => this.setTranslationTarget(code),
          onExceptionSelect: (code: string) => this.setTranslationException(code),
          onClose: () => { this.showTranslationSettings = false; }
        })
          .transition(this.rightPageTransition())
      } else {
        PublishBrowseSettingsPage({ bottomInset: this.bottomInset(),
          imageQuality: this.imageQuality,
          gifQuality: this.gifQuality,
          autoPlay: this.autoPlay,
          autoPlayMuted: this.autoPlayMuted,
          onImageQualityChange: (value: number) => { this.imageQuality = value; this.saveMediaSettings(); },
          onGifQualityChange: (value: number) => { this.gifQuality = value; this.saveMediaSettings(); },
          onAutoPlayChange: (value: boolean) => { this.autoPlay = value; this.savePlaybackSettings(); },
          onAutoPlayMutedChange: (value: boolean) => { this.autoPlayMuted = value; this.savePlaybackSettings(); },
          onOpenGestureSettings: () => {
            this.showTranslationSettings = false;
            this.showGestureSettings = true;
          },
          onClose: () => { this.settingsSection = 'profile'; }
        })
          .transition(this.rightPageTransition())
      }
    } else if (this.settingsSection == 'cache') {
      CacheSettingsPage({ bottomInset: this.bottomInset(),
        maxMb: this.cacheMaxMb,
        usedMb: this.cacheUsedMb,
        ownUsedMb: this.cacheOwnUsedMb,
        ownPostsMax: this.cacheOwnPostsMax,
        ownRepliesMax: this.cacheOwnRepliesMax,
        ownRepostsMax: this.cacheOwnRepostsMax,
        clearBrowsingOnExit: this.cacheClearBrowsingOnExit,
        onMaxMbChange: (value: number) => { this.cacheMaxMb = value; this.saveCacheSettings(); ProfileCache.applyLimits(getContext(this) as common.UIAbilityContext); this.refreshCacheUsage(); },
        onOwnPostsMaxChange: (value: number) => { this.cacheOwnPostsMax = value; this.saveCacheSettings(); },
        onOwnRepliesMaxChange: (value: number) => { this.cacheOwnRepliesMax = value; this.saveCacheSettings(); },
        onOwnRepostsMaxChange: (value: number) => { this.cacheOwnRepostsMax = value; this.saveCacheSettings(); },
        onClearBrowsingOnExitChange: (value: boolean) => { this.cacheClearBrowsingOnExit = value; this.saveCacheSettings(); },
        onClearBrowsing: () => this.confirmClearBrowsing(),
        onClearSearch: () => this.confirmClearSearch(),
        onClearMyData: () => this.confirmClearMyData(),
        onClearAll: () => this.confirmClearAll()
      })
        .transition(this.rightPageTransition())
    } else if (this.settingsSection == 'about') {
      AboutPage({ bottomInset: this.bottomInset(),
        page: $aboutPage,
        onClose: () => { this.settingsSection = 'profile'; this.aboutPage = 'main'; }
      })
        .transition(this.rightPageTransition())
    } else {
      if (this.profile != null) {
        Column() {
          Column() {
            if (this.userListVisible) {
              UserListPage({
                cookie: this.cookie,
                userId: this.userListId,
                kind: this.userListKind,
                title: this.userListTitle,
                onClose: () => { this.userListVisible = false; },
                onOpenUser: (handle: string) => {
                  this.userListVisible = false;
                  this.profileHandle = handle;
                }
              })
                .width('100%').height('100%')
                .transition(this.rightPageTransition())
            } else if (this.showEditProfile && this.profile != null) {
              EditProfilePage({
                cookie: this.cookie,
                profile: this.profile,
                onClose: () => {
                  this.showEditProfile = false;
                  this.loadProfile(true);
                },
                onSaved: (updated: UserProfile) => {
                  this.profile = updated;
                  ProfileCache.save(getContext(this) as common.UIAbilityContext, updated);
                  ProfileCache.saveSelf(getContext(this) as common.UIAbilityContext, updated);
                  this.showEditProfile = false;
                }
              })
                .width('100%').height('100%')
                .transition(this.rightPageTransition())
            } else if (this.settingsDetail != null) {
              this.settingsDetailContent()
            } else {
              ProfilePage({
                bottomInset: this.bottomInset(),
                embedded: true,
                videoPane: this.settingsSplitActive() ? 'right' : 'detail',
                cookie: this.cookie,
                handle: this.profile!.handle,
                knownProfile: this.profile,
                onClose: () => {},
                onEditProfile: () => { this.showEditProfile = true; },
                onOpenConnections: (kind: string, userId: string, title: string) => {
                  this.userListKind = kind;
                  this.userListId = userId;
                  this.userListTitle = title;
                  this.userListVisible = true;
                },
                onOpenTweet: (item: TweetItem) => { this.settingsDetailOnTop = true; this.openSettingsDetail(item); },
                onReply: (item: TweetItem) => this.openReply(item),
                onQuote: (item: TweetItem) => this.openQuote(item),
                onPlay: (item: TweetItem, startTime: number) => {
                  this.playingVideoStart = startTime;
                  this.playingVideoPoster = item.imageUrl;
                  this.playingVideo = item.videoUrl; VideoAutoplay.enterFullscreen(item.id);
                },
                onImage: (url: string) => { this.viewingImage = url; },
                onOpenQuoted: (id: string) => this.openSettingsQuoted(id),
                onOpenUser: (handle: string) => this.openNestedProfile(handle)
              })
              .width('100%').height('100%')
              .transition(this.rightPageTransition())
            }
          }
          .layoutWeight(1).width('100%')
          .backgroundColor(Color.Transparent)
        }
        .width('100%').height('100%')
      } else {
        Column() {
          LoadingProgress().width(28).height(28)
          Text(this.tr('正在加载资料…')).fontSize(13).fontColor($r('app.color.text_secondary')).margin({ top: 8 })
        }.width('100%').height('100%').justifyContent(FlexAlign.Center)
      }
    }
  }

  @Builder
  myProfileSummary() {
    Column() {
      Row() {
        if (this.profile != null && this.profile.avatarUrl.length > 0) {
          Image(this.profile.avatarUrl).width(64).height(64).borderRadius(32)
        } else {
          Stack({ alignContent: Alignment.Center }) {
            Circle({ width: 64, height: 64 }).fill($r('app.color.accent_soft'))
            Text('H').fontSize(24).fontWeight(FontWeight.Bold).fontColor($r('app.color.accent'))
          }.width(64).height(64)
        }
        Column() {
          Text(this.profile != null ? this.profile.name : 'HM-Xbird')
            .fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
          Text(this.profile != null ? `@${this.profile.handle}` : this.tr('正在加载资料…'))
            .fontSize(14).fontColor($r('app.color.text_secondary')).margin({ top: 3 })
        }.alignItems(HorizontalAlign.Start).margin({ left: 14 }).layoutWeight(1)
        Text('›').fontSize(22).fontColor($r('app.color.text_secondary'))
      }.width('100%')
      .onClick(() => {
        if (this.profile == null) return;
        if (this.settingsSplitActive()) {
          this.closeSettingsDetail();
          this.settingsDetailOnTop = false;
          this.userListVisible = false;
          this.settingsSection = 'profile';
        } else {
          this.profileHandle = this.profile.handle;
        }
      })

      if (this.profile != null) {
        Row() {
          Text(this.tr(`${this.profile.following} 正在关注`))
            .fontSize(13).fontColor($r('app.color.text_secondary'))
            .padding({ left: 12, right: 12, top: 7, bottom: 7 })
            .backgroundColor($r('app.color.surface_secondary')).borderRadius(14)
            .onClick(() => {
              this.userListKind = 'following';
              this.userListId = this.profile!.id;
              this.userListTitle = this.tr('正在关注');
              this.closeSettingsDetail();
              this.settingsDetailOnTop = false;
              this.settingsSection = 'profile';
              this.userListVisible = true;
            })
          Text(this.tr(`${this.profile.followers} 关注者`))
            .fontSize(13).fontColor($r('app.color.text_secondary'))
            .padding({ left: 12, right: 12, top: 7, bottom: 7 })
            .backgroundColor($r('app.color.surface_secondary')).borderRadius(14)
            .margin({ left: 8 })
            .onClick(() => {
              this.userListKind = 'followers';
              this.userListId = this.profile!.id;
              this.userListTitle = this.tr('关注者');
              this.closeSettingsDetail();
              this.settingsDetailOnTop = false;
              this.settingsSection = 'profile';
              this.userListVisible = true;
            })
        }.margin({ top: 12 })
      }
    }
    .width('100%').padding(18)
    .backgroundColor($r('app.color.surface')).borderRadius(20)
  }

  @Builder
  mePage() {
    Column() {
      Text(this.tr('我的'))
        .fontSize(30).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%').padding({ left: 20, right: 20, top: 10, bottom: 14 })

      Scroll() {
        Column() {
          this.myProfileSummary()

          Column() {
            Row() {
              Text(this.tr('外观')).fontSize(16).fontColor($r('app.color.text_primary')).layoutWeight(1)
              Text('›').fontSize(20).fontColor($r('app.color.text_secondary'))
            }
            .width('100%').padding(16)
            .onClick(() => this.showThemeSettings = true)
          }
          .width('100%').backgroundColor($r('app.color.surface')).borderRadius(20)
          .margin({ top: 12 })

          Column() {
            Row() {
              Text(this.tr('发送与播放')).fontSize(16).fontColor($r('app.color.text_primary')).layoutWeight(1)
              Text('›').fontSize(20).fontColor($r('app.color.text_secondary'))
            }
            .width('100%').padding(16)
            .onClick(() => this.showPublishBrowseSettings = true)

            Divider().strokeWidth(1.5).color($r('app.color.divider')).margin({ left: 16, right: 16 })

            Row() {
              Text(this.tr('自动翻译')).fontSize(16).fontColor($r('app.color.text_primary')).layoutWeight(1)
              Text('›').fontSize(20).fontColor($r('app.color.text_secondary'))
            }
            .width('100%').padding(16)
            .onClick(() => this.showTranslationSettings = true)
          }
          .width('100%').backgroundColor($r('app.color.surface')).borderRadius(20)
          .margin({ top: 12 })

          Column() {
            Row() {
              Text(this.tr('本地缓存')).fontSize(16).fontColor($r('app.color.text_primary')).layoutWeight(1)
              Text('›').fontSize(20).fontColor($r('app.color.text_secondary'))
            }
            .width('100%').padding(16)
            .onClick(() => { this.refreshCacheUsage(); this.showCacheSettings = true; })
          }
          .width('100%').backgroundColor($r('app.color.surface')).borderRadius(20)
          .margin({ top: 12 })

          Row() {
            Text(this.tr('关于')).fontSize(16).fontColor($r('app.color.text_primary')).layoutWeight(1)
            Text('›').fontSize(20).fontColor($r('app.color.text_secondary'))
          }
          .width('100%').padding(16)
          .backgroundColor($r('app.color.surface')).borderRadius(20)
          .margin({ top: 12 })
          .onClick(() => { this.aboutPage = 'main'; this.showAbout = true; })

          Row() {
            Text(this.tr('退出登录'))
              .fontSize(16).fontColor('#F4212E')
              .width('100%').textAlign(TextAlign.Center)
          }
          .width('100%').height(52)
          .backgroundColor($r('app.color.surface')).borderRadius(20)
          .margin({ top: 12 })
          .onClick(() => this.confirmLogout())

          Blank().height(this.bottomInset() + 20)
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
      .layoutWeight(1).width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%').height('100%')
    .backgroundColor($r('app.color.grouped_bg'))
  }

  @Builder
  notificationsPage() {
    Column() {
      Text(this.tr('通知')).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary')).width('100%').padding(16)

      if (this.notificationsLoading && this.notifications.length == 0) {
        Column() { LoadingProgress().width(28).height(28) }
          .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else if (this.notificationsError.length > 0 && this.notifications.length == 0) {
        Column() {
          Text(this.notificationsError).fontSize(13).fontColor('#F4212E')
            .width('100%').textAlign(TextAlign.Center).padding(16)
          Button(this.tr('重试')).onClick(() => this.loadNotifications(false))
        }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else if (this.notifications.length == 0) {
        Column() {
          Text(this.notificationsLoaded ? this.tr('暂无通知') : this.tr('打开通知时加载')).fontSize(14).fontColor($r('app.color.text_secondary'))
            .width('100%').textAlign(TextAlign.Center)
        }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.notifications, (item: NotificationItem) => {
            ListItem() {
              Column() {
              Row() {
                if (item.avatarUrl.length > 0) {
                  Image(item.avatarUrl).width(36).height(36).borderRadius(18)
                } else {
                  Circle({ width: 36, height: 36 }).fill('#E1E8ED')
                }
                Column() {
                  Text(item.message.length > 0 ? item.message : item.type)
                    .fontSize(14).fontColor($r('app.color.text_primary')).maxLines(4).textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(item.authorName.length > 0 ? `@${item.authorHandle}` : '')
                    .fontSize(12).fontColor($r('app.color.text_secondary')).margin({ top: 3 })
                }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 10 })
              }
              .width('100%').padding(14)
              .onClick(() => this.openNotification(item))
              Divider().strokeWidth(1).color($r('app.color.divider'))
              }.width('100%')
            }
          }, (item: NotificationItem) => item.id)
        }
        .layoutWeight(1).width('100%')
        .onReachEnd(() => this.loadNotifications(true))
      }
    }.width('100%').height('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  detailPane() {
    Column() {
      if (this.userListVisible) {
        UserListPage({
          cookie: this.cookie,
          userId: this.userListId,
          kind: this.userListKind,
          title: this.userListTitle,
          onClose: () => { this.userListVisible = false; },
          onOpenUser: (handle: string) => {
            this.userListVisible = false;
            this.profileHandle = handle;
          }
        })
          .width('100%').height('100%')
          .transition(this.rightPageTransition())
      } else if (this.profileHandle.length > 0) {
        ProfilePage({
          bottomInset: this.bottomInset(),
          embedded: true,
          videoPane: 'right',
          cookie: this.cookie,
          handle: this.profileHandle,
          knownProfile: this.profile != null && this.profileHandle == this.profile!.handle ? this.profile : null,
          onClose: () => this.closeProfile(),
          onEditProfile: () => { this.showEditProfile = true; },
          onOpenConnections: (kind: string, userId: string, title: string) => {
            this.userListKind = kind;
            this.userListId = userId;
            this.userListTitle = title;
            this.userListVisible = true;
          },
          onOpenTweet: (item: TweetItem) => this.openProfileTweet(item),
          onReply: (item: TweetItem) => this.openReply(item),
          onQuote: (item: TweetItem) => this.openQuote(item),
          onPlay: (item: TweetItem, startTime: number) => {
            this.playingVideoStart = startTime;
            this.playingVideoPoster = item.imageUrl;
            this.playingVideo = item.videoUrl;
            VideoAutoplay.enterFullscreen(item.id);
          },
          onImage: (url: string) => { this.viewingImage = url; },
          onOpenQuoted: (id: string) => this.openQuoted(id),
          onOpenUser: (handle: string) => this.openNestedProfile(handle)
        })
          .width('100%').height('100%')
          .transition(this.rightPageTransition())
      } else if (this.selected == null) {
        Text(this.tr('选择左侧推文')).fontSize(15).fontColor($r('app.color.text_secondary'))
          .transition(this.rightPageTransition())
      } else {
        Column() {
        Row() {
          if (!this.contentSplitActive()) {
            Button('‹').backgroundColor('#00000000').fontColor($r('app.color.text_primary')).fontSize(22)
              .onClick(() => { this.handleBack(); })
          }
          Text(this.tr('帖子')).fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary')).layoutWeight(1)
        }.width('100%').height(48).padding({ left: 8, right: 12 })

        if (this.detailError.length > 0) {
          Column() {
            Text(this.detailError).fontSize(13).fontColor('#F4212E').padding(16)
            Button(this.tr('重试')).onClick(() => {
              if (this.selected != null) this.openDetail(this.selected);
            })
          }.layoutWeight(1).justifyContent(FlexAlign.Center)
        } else {
          List({ scroller: this.detailScroller }) {
            ForEach(this.detailTweets, (item: TweetItem) => {
              ListItem() {
                Column() {
                  TweetCard({
                    item: item,
                    cookie: this.cookie,
                    onReply: (value: TweetItem) => this.openReply(value),
                    onQuote: (value: TweetItem) => this.openQuote(value),
                    onOpen: (value: TweetItem) => this.openDetail(value, true),
                    onPlay: (value: TweetItem, startTime: number) => { this.playingVideoStart = startTime; this.playingVideoPoster = value.imageUrl; this.playingVideo = value.videoUrl; VideoAutoplay.enterFullscreen(value.id); },
                    onImage: (url: string) => { this.viewingImage = url; },
                    onOpenQuoted: (id: string) => this.openQuoted(id),
                    onOpenUser: (handle: string) => this.openNestedProfile(handle),
                    videoPane: this.contentSplitActive() ? 'right' : 'detail',
                    videoIndex: 0
                  })
                  Divider().strokeWidth(1).color($r('app.color.divider'))
                }
                .onClick(() => this.openDetail(item, true))
              }
            }, (item: TweetItem) => item.id)
          }
          .layoutWeight(1).width('100%')
          .contentEndOffset(this.bottomInset())
          .onReachEnd(() => {})
        }

        if (this.detailLoading) {
          Row() {
            LoadingProgress().width(20).height(20)
            Text(this.tr('加载评论…')).fontSize(12).fontColor($r('app.color.text_secondary')).margin({ left: 8 })
          }.height(32)
        }
        }
        .width('100%').height('100%')
        .opacity(this.detailPageOpacity)
        .translate({ x: this.detailOffsetX })
        .transition(this.rightPageTransition())
      }
    }.width('100%').height('100%')
  }

  @Builder
  contentStack() {
    Stack() {
      Column() {
        HomeFeed({
          bottomInset: this.bottomInset(),
          scrollTopTick: this.homeTapTick,
          cookie: this.cookie,
          viewerHandle: this.profile != null ? this.profile.handle : '',
          onReply: (item: TweetItem) => this.openReply(item),
          onQuote: (item: TweetItem) => this.openQuote(item),
          onOpen: (item: TweetItem) => this.openContentDetail(item),
          onPrefetch: (item: TweetItem) => this.prefetchDetail(item),
          onReady: () => {
            AppStorage.setOrCreate('tuichuang_ready', true);
            this.homeReady = true;
            this.refreshProfileCache();
          },
          onPlay: (item: TweetItem, startTime: number) => { this.playingVideoStart = startTime; this.playingVideoPoster = item.imageUrl; this.playingVideo = item.videoUrl; VideoAutoplay.enterFullscreen(item.id); },
          onImage: (url: string) => { this.viewingImage = url; },
          onOpenQuoted: (id: string) => this.openQuoted(id),
          onOpenUser: (handle: string) => this.openContentProfile(handle)
        })
      }.width('100%').height('100%')
      .visibility(this.tab == 0 ? Visibility.Visible : Visibility.None)

      Column() {
        SearchView({
          bottomInset: this.bottomInset(),
          focusTick: this.searchFocusTick,
          trendsHomeTick: this.trendsHomeTick,
          active: this.tab == 1,
          cookie: this.cookie,
          onReply: (item: TweetItem) => this.openReply(item),
          onQuote: (item: TweetItem) => this.openQuote(item),
          onOpen: (item: TweetItem) => this.openContentDetail(item),
          onPlay: (item: TweetItem, startTime: number) => { this.playingVideoStart = startTime; this.playingVideoPoster = item.imageUrl; this.playingVideo = item.videoUrl; VideoAutoplay.enterFullscreen(item.id); },
          onImage: (url: string) => { this.viewingImage = url; },
          onOpenQuoted: (id: string) => this.openQuoted(id),
          onOpenUser: (handle: string) => this.openContentProfile(handle)
        })
      }.width('100%').height('100%')
      .visibility(this.tab == 1 ? Visibility.Visible : Visibility.None)

      Column() { this.notificationsPage() }.width('100%').height('100%')
      .visibility(this.tab == 2 ? Visibility.Visible : Visibility.None)

      Column() {
        if (this.settingsSplitActive()) this.settingsMenuPage()
        else this.mePage()
      }.width('100%').height('100%')
      .visibility(this.tab == 3 ? Visibility.Visible : Visibility.None)
    }.width('100%').height('100%')
  }

  @Builder
  barLayer() {
    Column() {
      this.bottomBar()
    }
    .width('100%').height(this.bottomInset())
    .padding({ left: this.barX })
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      if (!this.loggedIn) {
        if (this.showWebLogin) {
          LoginView({
            onBack: () => { this.showWebLogin = false; },
            onManualLogin: () => this.showWebLogin = false,
            onLoggedIn: (cookie: string, jsUrls: string, save: boolean) => {
              const context = getContext(this) as common.UIAbilityContext;
              this.pendingSaveAccount = save;
              SessionStore.saveCookie(context, cookie);
              SessionStore.saveJsUrls(context, jsUrls);
              try { QueryIds.setBundleUrls(JSON.parse(jsUrls) as string[]); } catch (e) {}
              this.cookie = cookie;
              this.loggedIn = true;
              this.showWebLogin = false;
              this.loadProfile(true);
            }
          })
          .padding({ top: this.safeTop, bottom: this.safeBottom })
          .transition(
            TransitionEffect.translate({ x: 18 })
              .combine(TransitionEffect.OPACITY)
              .animation({ duration: 280, curve: Curve.FastOutSlowIn })
          )
        } else {
          NativeLogin({
            onLoggedIn: (cookie: string, save: boolean) => {
              SessionStore.saveCookie(getContext(this) as common.UIAbilityContext, cookie);
              this.pendingSaveAccount = save;
              this.cookie = cookie;
              this.loggedIn = true;
              this.loadProfile(true);
            },
            onWebLogin: () => this.showWebLogin = true,
            savedAccounts: this.savedAccounts,
            onUseSaved: (account: SavedAccount) => { this.useSavedAccount(account); },
            page: $loginPage
          })
          .padding({ top: this.safeTop, bottom: this.safeBottom })
        }
      } else {
        SideBarContainer(SideBarContainerType.Embed) {
          Column() {
            this.contentStack()
          }.width('100%').height('100%').padding({ top: this.safeTop })
          .backgroundColor(this.settingsSplitActive() ? $r('app.color.grouped_bg') : Color.Transparent)

          Column() {
            if (this.settingsPanePinned && this.selected == null) this.settingsRightPane()
            else this.detailPane()
          }.width('100%').height('100%').padding({ top: this.safeTop })
          .backgroundColor(this.settingsPanePinned && this.selected == null ?
            (this.settingsSection == 'profile' ? $r('app.color.bg') : $r('app.color.grouped_bg')) :
            $r('app.color.bg'))
        }
        .showSideBar(this.settingsSplitActive() || this.tab == 3 ? true : (this.selected == null || this.contentSplitActive()))
        .sideBarWidth(this.leftPaneWidth())
        .minSideBarWidth(1)
        .maxSideBarWidth(this.paneWidth)
        .minContentWidth(0)
        .showControlButton(false)
        .divider({ strokeWidth: 0, color: Color.Transparent })
        .autoHide(false)
        .width('100%').height('100%')
        .onAreaChange((oldValue: Area, newValue: Area) => {
          const w = parseFloat(`${newValue.width}`);
          const h = parseFloat(`${newValue.height}`);
          if (!isNaN(w)) {
            const wasSplit = this.settingsSplitActive();
            this.paneWidth = w;
            this.barWidth = this.pillWidth();
            if (!this.navCanSlide()) this.barMode = 1;
            let foldable = false;
            try { foldable = display.isFoldable(); } catch (e) {}
            if (!foldable) {
              this.expanded = w >= 600;
              if (!this.expanded) this.barMode = 1;
            }
            this.updateBarX();
            const isSplit = this.settingsSplitActive();
            if (!this.settingsSplitInitialized) {
              this.settingsSplitInitialized = true;
              this.lastSettingsSplit = isSplit;
              if (isSplit) this.moveSettingsIntoSplit();
            } else if (wasSplit != isSplit) {
              this.syncSettingsMode(wasSplit, isSplit);
            }
          }
          if (!isNaN(h)) this.paneHeight = h;
        })
        .onTouch((event: TouchEvent) => {
          if (event.type != TouchType.Down || event.touches.length == 0) return;
          const x = event.touches[0].windowX;
          const y = event.touches[0].windowY;
          // The floating navigation bar owns its own touches; do not move it
          // when the user taps one of its buttons.
          if (this.isInsideNavBar(x, y)) return;
          this.tapPaneBar(x);
        })

        if (this.settingsSplitActive()) {
          Column()
            .width(1.5).height('100%')
            .backgroundColor('#C8C8CD')
            .position({ x: this.leftPaneWidth() - 1, y: 0 })
        }

        if (this.contentSplitActive() && !this.settingsSplitActive()) {
          Stack({ alignContent: Alignment.Center }) {
            Column()
              .width(1).height('100%')
              .backgroundColor($r('app.color.divider'))

            Column() {
              Circle({ width: 3, height: 3 }).fill('#8A8A8A')
              Circle({ width: 3, height: 3 }).fill('#8A8A8A').margin({ top: 4 })
              Circle({ width: 3, height: 3 }).fill('#8A8A8A').margin({ top: 4 })
            }
            .width(12).height(38)
            .justifyContent(FlexAlign.Center)
            .backgroundColor('#F2FFFFFF')
            .backgroundBlurStyle(BlurStyle.BACKGROUND_THIN)
            .borderRadius(6)
            .border({ width: 1, color: '#1A000000' })
            .shadow({ radius: 6, color: '#1F000000', offsetY: 1 })
          }
          .width(20).height('100%')
          .position({ x: this.splitWidth() - 10, y: 0 })
          .gesture(
            PanGesture()
              .onActionStart(() => {
                if (this.paneWidth <= 0) return;
                this.splitRatio = this.splitWidth() / this.paneWidth;
                this.splitStartRatio = this.splitRatio;
                this.splitUserAdjusted = true;
              })
              .onActionUpdate((event: GestureEvent) => {
                if (this.paneWidth <= 0) return;
                const ratio = this.splitStartRatio + event.offsetX / this.paneWidth;
                const minRatio = 300 / this.paneWidth;
                const maxRatio = (this.paneWidth - 300) / this.paneWidth;
                this.splitRatio = Math.max(minRatio, Math.min(maxRatio, ratio));
              })
          )
        }

        if (this.profileHandle.length > 0 && !this.settingsSplitActive() && !this.contentSplitActive()) {
          ProfilePage({
            bottomInset: this.bottomInset(),
            cookie: this.cookie,
            handle: this.profileHandle,
            knownProfile: this.profile,
            onClose: () => this.closeProfile(),
            onEditProfile: () => { this.showEditProfile = true; },
            onOpenConnections: (kind: string, userId: string, title: string) => {
              this.userListKind = kind;
              this.userListId = userId;
              this.userListTitle = title;
              this.userListVisible = true;
            },
            onOpenTweet: (item: TweetItem) => this.openProfileTweet(item),
            onReply: (item: TweetItem) => this.openReply(item),
            onQuote: (item: TweetItem) => this.openQuote(item),
            onPlay: (item: TweetItem, startTime: number) => { this.playingVideoStart = startTime; this.playingVideoPoster = item.imageUrl; this.playingVideo = item.videoUrl; VideoAutoplay.enterFullscreen(item.id); },
            onImage: (url: string) => { this.viewingImage = url; },
            onOpenQuoted: (id: string) => this.openQuoted(id),
            onOpenUser: (handle: string) => this.openNestedProfile(handle)
          })
          .width('100%').height('100%')
          .padding({ top: this.safeTop })
          .transition(
            TransitionEffect.translate({ x: '100%' })
              .combine(TransitionEffect.OPACITY)
              .animation({ duration: 280, curve: Curve.FastOutSlowIn })
          )
        }

        if (this.showEditProfile && this.profile != null && !this.settingsSplitActive()) {
          EditProfilePage({
            cookie: this.cookie,
            profile: this.profile,
            onClose: () => {
              this.showEditProfile = false;
              this.loadProfile(true);
            },
            onSaved: (updated: UserProfile) => {
              this.profile = updated;
              ProfileCache.save(getContext(this) as common.UIAbilityContext, updated);
              ProfileCache.saveSelf(getContext(this) as common.UIAbilityContext, updated);
              this.showEditProfile = false;
            }
          })
            .width('100%').height('100%')
            .padding({ top: this.safeTop, bottom: this.bottomInset() })
            .transition(
              TransitionEffect.translate({ x: '100%' })
                .combine(TransitionEffect.OPACITY)
                .animation({ duration: 280, curve: Curve.FastOutSlowIn })
            )
        }

        if (this.userListVisible && !this.settingsSplitActive() && !this.contentSplitActive()) {
          UserListPage({
            cookie: this.cookie,
            userId: this.userListId,
            kind: this.userListKind,
            title: this.userListTitle,
            onClose: () => { this.userListVisible = false; },
            onOpenUser: (handle: string) => {
              this.userListVisible = false;
              this.profileHandle = handle;
            }
          })
            .width('100%').height('100%')
            .padding({ top: this.safeTop })
            .transition(
              TransitionEffect.translate({ x: '100%' })
                .combine(TransitionEffect.OPACITY)
                .animation({ duration: 280, curve: Curve.FastOutSlowIn })
            )
        }

        if (this.showTranslationSettings && !this.settingsSplitActive()) {
          TranslationSettingsPage({ bottomInset: this.bottomInset(),
            showBack: true,
            autoEnabled: this.translationEnabled,
            targetLang: this.translationTarget,
            exceptionLang: this.translationException,
            onEnabledChange: (value: boolean) => this.setTranslationEnabled(value),
            onTargetSelect: (code: string) => this.setTranslationTarget(code),
            onExceptionSelect: (code: string) => this.setTranslationException(code),
            onClose: () => { this.showTranslationSettings = false; }
          })
            .width('100%').height('100%')
            .padding({ top: this.safeTop, bottom: this.bottomInset() })
            .transition(TransitionEffect.translate({ x: 18 }).combine(TransitionEffect.OPACITY)
              .animation({ duration: 280, curve: Curve.FastOutSlowIn }))
        }

        if (this.showPublishBrowseSettings && !this.settingsSplitActive()) {
          if (this.showGestureSettings) {
            GestureSettingsPage({ bottomInset: this.bottomInset(),
              fullscreenGestures: this.fullscreenGestures,
              onGesturesChange: (value: boolean) => { this.fullscreenGestures = value; this.savePlaybackSettings(); },
              onBack: () => { this.showGestureSettings = false; }
            })
              .width('100%').height('100%')
              .padding({ top: this.safeTop, bottom: this.bottomInset() })
              .transition(TransitionEffect.translate({ x: 18 }).combine(TransitionEffect.OPACITY)
                .animation({ duration: 280, curve: Curve.FastOutSlowIn }))
          } else {
            PublishBrowseSettingsPage({ bottomInset: this.bottomInset(),
              showBack: true,
              imageQuality: this.imageQuality,
              gifQuality: this.gifQuality,
              autoPlay: this.autoPlay,
              autoPlayMuted: this.autoPlayMuted,
              onImageQualityChange: (value: number) => { this.imageQuality = value; this.saveMediaSettings(); },
              onGifQualityChange: (value: number) => { this.gifQuality = value; this.saveMediaSettings(); },
              onAutoPlayChange: (value: boolean) => { this.autoPlay = value; this.savePlaybackSettings(); },
              onAutoPlayMutedChange: (value: boolean) => { this.autoPlayMuted = value; this.savePlaybackSettings(); },
              onOpenGestureSettings: () => { this.showGestureSettings = true; },
              onClose: () => { this.showPublishBrowseSettings = false; }
            })
              .width('100%').height('100%')
              .padding({ top: this.safeTop, bottom: this.bottomInset() })
              .transition(TransitionEffect.translate({ x: 18 }).combine(TransitionEffect.OPACITY)
                .animation({ duration: 280, curve: Curve.FastOutSlowIn }))
          }
        }

        if (this.showLanguageSettings && !this.settingsSplitActive()) {
          LanguageSettingsPage({ bottomInset: this.bottomInset(),
            mode: this.languageMode,
            showBack: true,
            onBack: () => { this.showLanguageSettings = false; },
            onSelect: (mode: string) => this.changeLanguage(mode)
          })
            .width('100%').height('100%')
            .padding({ top: this.safeTop, bottom: this.bottomInset() })
            .transition(TransitionEffect.translate({ x: 18 }).combine(TransitionEffect.OPACITY)
              .animation({ duration: 280, curve: Curve.FastOutSlowIn }))
        }

        if (this.showCacheSettings && !this.settingsSplitActive()) {
          CacheSettingsPage({ bottomInset: this.bottomInset(),
            showBack: true,
            onClose: () => { this.showCacheSettings = false; },
            maxMb: this.cacheMaxMb,
            usedMb: this.cacheUsedMb,
            ownUsedMb: this.cacheOwnUsedMb,
            ownPostsMax: this.cacheOwnPostsMax,
            ownRepliesMax: this.cacheOwnRepliesMax,
            ownRepostsMax: this.cacheOwnRepostsMax,
            clearBrowsingOnExit: this.cacheClearBrowsingOnExit,
            onMaxMbChange: (value: number) => { this.cacheMaxMb = value; this.saveCacheSettings(); ProfileCache.applyLimits(getContext(this) as common.UIAbilityContext); this.refreshCacheUsage(); },
            onOwnPostsMaxChange: (value: number) => { this.cacheOwnPostsMax = value; this.saveCacheSettings(); },
            onOwnRepliesMaxChange: (value: number) => { this.cacheOwnRepliesMax = value; this.saveCacheSettings(); },
            onOwnRepostsMaxChange: (value: number) => { this.cacheOwnRepostsMax = value; this.saveCacheSettings(); },
            onClearBrowsingOnExitChange: (value: boolean) => { this.cacheClearBrowsingOnExit = value; this.saveCacheSettings(); },
            onClearBrowsing: () => this.confirmClearBrowsing(),
            onClearSearch: () => this.confirmClearSearch(),
            onClearMyData: () => this.confirmClearMyData(),
            onClearAll: () => this.confirmClearAll()
          })
            .width('100%').height('100%')
            .padding({ top: this.safeTop, bottom: this.bottomInset() })
            .transition(TransitionEffect.translate({ x: 18 }).combine(TransitionEffect.OPACITY)
              .animation({ duration: 280, curve: Curve.FastOutSlowIn }))
        }

        if (this.showAbout && !this.settingsSplitActive()) {
          AboutPage({ bottomInset: this.bottomInset(),
            showBack: true,
            page: $aboutPage,
            onClose: () => { this.showAbout = false; this.aboutPage = 'main'; }
          })
            .width('100%').height('100%')
            .padding({ top: this.safeTop, bottom: this.bottomInset() })
            .transition(
              TransitionEffect.translate({ x: 18 })
                .combine(TransitionEffect.OPACITY)
                .animation({ duration: 280, curve: Curve.FastOutSlowIn })
            )
        }

        if (this.showMediaSettings && !this.settingsSplitActive()) {
          MediaSettingsPage({ bottomInset: this.bottomInset(),
            showBack: true,
            imageLimitMb: this.imageLimitMb,
            gifLimitMb: this.gifLimitMb,
            imageQuality: this.imageQuality,
            gifQuality: this.gifQuality,
            onImageLimitChange: (value: number) => { this.imageLimitMb = value; this.saveMediaSettings(); },
            onGifLimitChange: (value: number) => { this.gifLimitMb = value; this.saveMediaSettings(); },
            onImageQualityChange: (value: number) => { this.imageQuality = value; this.saveMediaSettings(); },
            onGifQualityChange: (value: number) => { this.gifQuality = value; this.saveMediaSettings(); },
            onClose: () => { this.showMediaSettings = false; }
          })
            .width('100%').height('100%')
            .padding({ top: this.safeTop, bottom: this.bottomInset() })
            .transition(
              TransitionEffect.translate({ x: 18 })
                .combine(TransitionEffect.OPACITY)
                .animation({ duration: 280, curve: Curve.FastOutSlowIn })
            )
        }

        if (this.showThemeSettings && !this.settingsSplitActive()) {
          ThemeSettingsPage({ bottomInset: this.bottomInset(),
            showBack: true,
            mode: this.themeMode,
            splitEnabled: this.splitEnabled,
            barOpaque: this.barOpaque,
            onSplitChange: (value: boolean) => {
              this.applySplitEnabled(value);
            },
            onBarOpaqueChange: (value: boolean) => { this.barOpaque = value; },
            onSelect: (mode: string) => this.setThemeMode(mode),
            onClose: () => { this.showThemeSettings = false; }
          })
            .width('100%').height('100%')
            .padding({ top: this.safeTop, bottom: this.bottomInset() })
            .transition(
              TransitionEffect.translate({ x: '100%' })
                .combine(TransitionEffect.OPACITY)
                .animation({ duration: 280, curve: Curve.FastOutSlowIn })
            )
        }

        if (!this.composing) {
          this.barLayer()
        }

        if (this.composing) {
          Stack({ alignContent: Alignment.Center }) {
            Column()
              .width('100%').height('100%')
              .backgroundColor('#33000000')
              .onClick(() => this.closeCompose())

            Column() {
              ComposeView({
                cookie: this.cookie,
                replyToId: this.replyId,
                replyToHandle: this.replyHandle,
                quoteId: this.quoteId,
                quoteHandle: this.quoteHandle,
                quoteText: this.quoteText,
                glass: true,
                onClose: () => this.closeCompose()
              })
                .width('100%').height('100%')
            }
            .width(Math.min(560, this.paneWidth - 32))
            .height(Math.max(220, Math.min(480, this.paneHeight - this.keyboardHeight - 80)))
            .translate({ y: -this.keyboardHeight / 2 })
            .borderRadius(24)
            .clip(true)
            .backgroundColor(this.isDarkTheme ? '#1C1F24' : '#D9F7F9F9')
            .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, {
              colorMode: this.isDarkTheme ? ThemeColorMode.DARK : ThemeColorMode.LIGHT,
              adaptiveColor: AdaptiveColor.AVERAGE,
              scale: 1.0,
              policy: BlurStyleActivePolicy.FOLLOWS_WINDOW_ACTIVE_STATE,
              inactiveColor: this.isDarkTheme ? '#1C1F24' : '#D9F7F9F9'
            })
            .border({ width: 1, color: this.isDarkTheme ? '#3A4048' : '#E1E8ED' })
            .shadow({ radius: 28, color: this.isDarkTheme ? '#66000000' : '#26000000', offsetY: 8 })
          }
          .width('100%').height('100%')
          .transition(
            TransitionEffect.translate({ y: '100%' })
              .combine(TransitionEffect.OPACITY)
              .animation({ duration: 280, curve: Curve.FastOutSlowIn })
          )
        }

        if (this.composing) {
          this.barLayer()
        }

        if (this.viewingImage.length > 0) {
          FullscreenImageViewer({ url: this.viewingImage })
            .width('100%').height('100%')
            .transition(
              TransitionEffect.OPACITY
                .combine(TransitionEffect.scale({ x: 0.94, y: 0.94 }))
                .animation({ duration: 220, curve: Curve.FastOutSlowIn })
            )
        }

        if (this.playingVideo.length > 0) {
          FullscreenVideo({
            url: this.playingVideo,
            startTime: this.playingVideoStart,
            posterUrl: this.playingVideoPoster,
            onClose: () => this.closeVideo()
          })
            .width('100%').height('100%')
            .transition(
              TransitionEffect.OPACITY
                .combine(TransitionEffect.scale({ x: 0.94, y: 0.94 }))
                .animation({ duration: 220, curve: Curve.FastOutSlowIn })
            )
        }
      }
    }
    .width('100%').height('100%')
    .backgroundColor($r('app.color.bg'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
