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

@Component
export struct NativeShell {
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
  @State imageScale: number = 1;
  @State showWebLogin: boolean = false;
  @State profileHandle: string = '';
  @State sheenX: number = -120;
  @State barOpaque: boolean = false;
  @State lightX: number = 0;
  @State lightOpacity: number = 0;
  @State videoError: string = '';
  @State keyboardHeight: number = 0;
  private mainWin: window.Window | null = null;
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
  @State mediaQuality: number = 2;
  @State showThemeSettings: boolean = false;
  @State showEditProfile: boolean = false;
  @State showMediaSettings: boolean = false;
  @State showAbout: boolean = false;
  @State aboutPage: string = 'main';
  @State savedAccounts: SavedAccount[] = [];
  @State pendingSaveAccount: boolean = false;
  @State loginPage: string = 'home';
  @State userListVisible: boolean = false;
  @State userListKind: string = 'followers';
  @State userListId: string = '';
  @State userListTitle: string = '关注者';
  @State splitRatio: number = 0.5;
  private splitStartRatio: number = 0.5;
  @State trendsHomeTick: number = 0;
  @State expanded: boolean = false;
  @State selected: TweetItem | null = null;
  @State detailTweets: TweetItem[] = [];
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
      this.loadProfile();
    }
    this.splitEnabled = SessionStore.loadSplitEnabled(context);
    this.themeMode = SessionStore.loadThemeMode(context);
    this.isDarkTheme = ThemeUtil.isDark(context, this.themeMode);
    AppStorage.setOrCreate('tuichuang_dark', this.isDarkTheme);
    this.imageLimitMb = SessionStore.loadImageLimit(context);
    this.gifLimitMb = SessionStore.loadGifLimit(context);
    this.mediaQuality = SessionStore.loadMediaQuality(context);
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
    animateTo({ duration: 220, curve: Curve.FastOutSlowIn }, () => {
      this.playingVideo = '';
      this.playingVideoStart = 0;
      this.playingVideoPoster = '';
    });
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
      animateTo({ duration: 220, curve: Curve.FastOutSlowIn }, () => {
        this.playingVideo = '';
        this.playingVideoStart = 0;
        this.playingVideoPoster = '';
      });
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
    if (this.userListVisible) {
      this.userListVisible = false;
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

  private updateBarX(): void {
    const mode = this.expanded ? this.barMode : 1;
    let x = (this.paneWidth - this.barWidth) / 2;
    if (mode == 0) x = this.barGap;
    if (mode == 2) x = this.paneWidth - this.barWidth - this.barGap;
    this.barX = Math.max(this.barGap, x);
  }

  private moveBar(target: number): void {
    if (!this.expanded || target == this.barMode) return;
    animateTo({ duration: 300, curve: Curve.Friction }, () => {
      this.barMode = target;
      this.updateBarX();
    });
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

  private async loadProfile(): Promise<void> {
    if (this.profileLoading) return;
    this.profileLoading = true;
    try {
      // Viewer works for both WebView and manually imported cookies. The old
      // UserByRestId queryId is stale and returns 403, so prefer Viewer.
      try {
        this.profile = await XApi.viewerProfile(this.cookie);
        if (this.profile != null) {
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
            if (!ok) promptAction.showToast({ message: '账号保存失败' });
          }
        }
      } catch (e) {
        const id = this.twid();
        if (id.length > 0) {
          this.profile = await XApi.userByRestId(this.cookie, id);
          this.loadMyTweets(id);
        }
      }
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
    this.openDetail(tweet);
  }

  private openQuoted(id: string): void {
    if (id.length == 0) return;
    const tweet = new TweetItem();
    tweet.id = id;
    this.openDetail(tweet);
  }

  private async openDetail(item: TweetItem): Promise<void> {
    animateTo({ duration: 280, curve: Curve.FastOutSlowIn }, () => {
      this.selected = item;
    });
    this.detailError = '';
    const cached = DetailCache.get(item.id);
    if (cached != null) {
      this.detailTweets = cached;
      this.detailLoading = false;
      return;
    }
    this.detailTweets = [item];
    this.detailLoading = true;
    try {
      const page = await XApi.tweetDetail(this.cookie, item.id);
      if (page.tweets.length > 0) {
        this.detailTweets = page.tweets;
        DetailCache.put(item.id, page.tweets);
      }
    } catch (e) {
      this.detailError = `${e}`;
    } finally {
      this.detailLoading = false;
    }
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
        '验证身份以使用保存的账号');
      if (!authorized) {
        promptAction.showToast({ message: '系统认证未通过，无法使用保存的账号' });
        return;
      }
      const cookie = await AccountStore.cookie(account);
      if (cookie.length == 0) throw new Error('保存的登录信息不存在');
      const profile = await XApi.viewerProfile(cookie);
      this.cookie = cookie;
      this.profile = profile;
      this.loggedIn = true;
      SessionStore.saveCookie(getContext(this) as common.UIAbilityContext, cookie);
      this.loadMyTweets(profile.id);
    } catch (e) {
      promptAction.showToast({ message: `恢复账号失败：${e}`, duration: 3000 });
    }
  }

  private confirmLogout(): void {
    AlertDialog.show({
      title: '退出登录？',
      message: '保留已保存账号时，下次可以直接恢复登录。',
      autoCancel: true,
      buttons: [
        { value: '取消', action: () => {} },
        { value: '保留账号退出', action: () => { this.logout(true); } },
        { value: '删除账号退出', fontColor: '#F4212E', action: () => { this.confirmDeleteSavedAccount(); } }
      ]
    });
  }

  private confirmDeleteSavedAccount(): void {
    AlertDialog.show({
      title: '删除保存的账号？',
      message: '将同时删除该账号保存在本机的 Cookie，删除后只能重新登录。此操作不可恢复。',
      autoCancel: true,
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: { value: '确认删除', fontColor: '#F4212E', action: () => { this.logout(false); } }
    });
  }

  private async logout(preserveSaved: boolean): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext;
    if (!preserveSaved && this.profile != null) {
      const account = this.savedAccounts.find((a: SavedAccount) => a.handle == this.profile!.handle);
      if (account != undefined) await AccountStore.remove(context, account);
    }
    SessionStore.clear(context);
    this.cookie = '';
    this.loggedIn = false;
    this.selected = null;
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
      this.imageLimitMb, this.gifLimitMb, this.mediaQuality);
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
    return Math.max(240, Math.min(this.paneWidth - 240, this.paneWidth * this.splitRatio));
  }

  @Builder
  navItem(index: number, icon: Resource, label: string) {
    Column() {
      Image(icon).width(22).height(22)
        .fillColor(this.tab == index ? $r('app.color.accent') : $r('app.color.text_secondary'))
      Text(label).fontSize(10)
        .fontColor(this.tab == index ? $r('app.color.accent') : $r('app.color.text_secondary'))
        .margin({ top: 2 })
    }
    .layoutWeight(1).height(52).justifyContent(FlexAlign.Center)
    .onClick(() => {
      if (this.selected != null && !(this.expanded && this.splitEnabled)) {
        animateTo({ duration: 280, curve: Curve.FastOutSlowIn }, () => {
          this.selected = null;
          this.detailTweets = [];
          this.detailError = '';
        });
        if (index == 0) {
          this.tab = 0;
          return;
        }
      }
      if (index == 0) {
        this.closeComposeIfOpen();
        if (this.tab == 0) this.homeTapTick += 1;
        else this.tab = 0;
        return;
      }
      this.closeComposeIfOpen();
      if (index == 3) {
        if (this.tab == 3) this.tab = this.previousTab;
        else { this.previousTab = this.tab; this.tab = 3; }
        return;
      }
      const wasTab = this.tab;
      this.tab = index;
      if (index == 1) this.trendsHomeTick += 1;
      if (index == 2) {
        if (wasTab == 2) this.loadNotifications(false);
        else if (!this.notificationsLoaded) this.loadNotifications(false);
      }
    })
  }

  @Builder
  bottomBar() {
    Stack({ alignContent: Alignment.Start }) {
      Row() {
        this.navItem(0, $r('app.media.ic_home'), '主页')
        this.navItem(1, $r('app.media.ic_search'), '趋势')
        Column() {
          Button() {
            Image($r('app.media.ic_plus')).width(20).height(20).fillColor($r('app.color.plus_icon'))
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
      if (!isNaN(w) && w > 0) {
        this.barWidth = w;
        this.updateBarX();
      }
    })
  }

  @Builder
  mePage() {
    Column() {
      Text('我的')
        .fontSize(30).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%').padding({ left: 20, right: 20, top: 10, bottom: 14 })

      Scroll() {
        Column() {
          // Profile card
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
                Text(this.profile != null ? `@${this.profile.handle}` : '正在加载资料…')
                  .fontSize(14).fontColor($r('app.color.text_secondary')).margin({ top: 3 })
              }.alignItems(HorizontalAlign.Start).margin({ left: 14 }).layoutWeight(1)
              Text('›').fontSize(22).fontColor($r('app.color.text_secondary'))
            }.width('100%')
            .onClick(() => {
              if (this.profile != null) this.profileHandle = this.profile.handle;
            })

            if (this.profile != null && this.profile.description.length > 0) {
              Text(this.profile.description).fontSize(14).lineHeight(20)
                .fontColor($r('app.color.text_primary')).margin({ top: 14 })
            }
            if (this.profile != null) {
              Row() {
                Text(`${this.profile.following} 正在关注`)
                  .fontSize(13).fontColor($r('app.color.text_secondary'))
                  .padding({ left: 12, right: 12, top: 7, bottom: 7 })
                  .backgroundColor($r('app.color.surface_secondary')).borderRadius(14)
                  .onClick(() => {
                    this.userListKind = 'following';
                    this.userListId = this.profile!.id;
                    this.userListTitle = '正在关注';
                    this.userListVisible = true;
                  })
                Text(`${this.profile.followers} 关注者`)
                  .fontSize(13).fontColor($r('app.color.text_secondary'))
                  .padding({ left: 12, right: 12, top: 7, bottom: 7 })
                  .backgroundColor($r('app.color.surface_secondary')).borderRadius(14)
                  .margin({ left: 8 })
                  .onClick(() => {
                    this.userListKind = 'followers';
                    this.userListId = this.profile!.id;
                    this.userListTitle = '关注者';
                    this.userListVisible = true;
                  })
              }.margin({ top: 12 })
            }
          }
          .width('100%').padding(18)
          .backgroundColor($r('app.color.surface')).borderRadius(20)

          Column() {
            Row() {
              Text('显示与主题').fontSize(16).fontColor($r('app.color.text_primary')).layoutWeight(1)
              Text(this.themeMode == 'light' ? '浅色' : (this.themeMode == 'dark' ? '深色' : '跟随系统'))
                .fontSize(13).fontColor($r('app.color.text_secondary'))
              Text('›').fontSize(20).fontColor($r('app.color.text_secondary')).margin({ left: 6 })
            }
            .width('100%').padding(16)
            .onClick(() => this.showThemeSettings = true)

            Divider().strokeWidth(1.5).color($r('app.color.divider')).margin({ left: 16 })

            Row() {
              Text('媒体与压缩').fontSize(16).fontColor($r('app.color.text_primary')).layoutWeight(1)
              Text(`${this.imageLimitMb}MB · ${this.gifLimitMb}MB`)
                .fontSize(13).fontColor($r('app.color.text_secondary'))
              Text('›').fontSize(20).fontColor($r('app.color.text_secondary')).margin({ left: 6 })
            }
            .width('100%').padding(16)
            .onClick(() => this.showMediaSettings = true)
          }
          .width('100%').backgroundColor($r('app.color.surface')).borderRadius(20)
          .margin({ top: 20 })

          Row() {
            Text('关于 HM-Xbird').fontSize(16).fontColor($r('app.color.text_primary')).layoutWeight(1)
            Text('1.0.0').fontSize(13).fontColor($r('app.color.text_secondary'))
            Text('›').fontSize(20).fontColor($r('app.color.text_secondary')).margin({ left: 6 })
          }
          .width('100%').padding(16)
          .backgroundColor($r('app.color.surface')).borderRadius(20)
          .margin({ top: 12 })
          .onClick(() => { this.aboutPage = 'main'; this.showAbout = true; })

          Row() {
            Text('退出登录')
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
      Text('通知').fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary')).width('100%').padding(16)

      if (this.notificationsLoading && this.notifications.length == 0) {
        Column() { LoadingProgress().width(28).height(28) }
          .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else if (this.notificationsError.length > 0 && this.notifications.length == 0) {
        Column() {
          Text(this.notificationsError).fontSize(13).fontColor('#F4212E')
            .width('100%').textAlign(TextAlign.Center).padding(16)
          Button('重试').onClick(() => this.loadNotifications(false))
        }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else if (this.notifications.length == 0) {
        Column() {
          Text(this.notificationsLoaded ? '暂无通知' : '打开通知时加载').fontSize(14).fontColor($r('app.color.text_secondary'))
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
      if (this.selected == null) {
        Text('选择左侧推文').fontSize(15).fontColor($r('app.color.text_secondary'))
      } else {
        Row() {
          if (!this.expanded) {
            Button('‹').backgroundColor('#00000000').fontColor($r('app.color.text_primary')).fontSize(22)
              .onClick(() => {
                this.selected = null;
                this.detailTweets = [];
              })
          }
          Text('帖子').fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary')).layoutWeight(1)
        }.width('100%').height(48).padding({ left: 8, right: 12 })

        if (this.detailError.length > 0) {
          Column() {
            Text(this.detailError).fontSize(13).fontColor('#F4212E').padding(16)
            Button('重试').onClick(() => {
              if (this.selected != null) this.openDetail(this.selected);
            })
          }.layoutWeight(1).justifyContent(FlexAlign.Center)
        } else {
          List() {
            ForEach(this.detailTweets, (item: TweetItem) => {
              ListItem() {
                Column() {
                  TweetCard({
                    item: item,
                    cookie: this.cookie,
                    onReply: (value: TweetItem) => this.openReply(value),
                    onQuote: (value: TweetItem) => this.openQuote(value),
                    onPlay: (value: TweetItem, startTime: number) => { this.playingVideoStart = startTime; this.playingVideoPoster = value.imageUrl; this.playingVideo = value.videoUrl; },
                    onImage: (url: string) => { this.imageScale = 1; this.viewingImage = url; },
                    onOpenQuoted: (id: string) => this.openQuoted(id),
                    onOpenUser: (handle: string) => this.profileHandle = handle
                  })
                  Divider().strokeWidth(1).color($r('app.color.divider'))
                }
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
            Text('加载评论…').fontSize(12).fontColor($r('app.color.text_secondary')).margin({ left: 8 })
          }.height(32)
        }
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
          onReply: (item: TweetItem) => this.openReply(item),
          onQuote: (item: TweetItem) => this.openQuote(item),
          onOpen: (item: TweetItem) => this.openDetail(item),
          onPrefetch: (item: TweetItem) => this.prefetchDetail(item),
          onReady: () => { AppStorage.setOrCreate('tuichuang_ready', true); },
          onPlay: (item: TweetItem, startTime: number) => { this.playingVideoStart = startTime; this.playingVideoPoster = item.imageUrl; this.playingVideo = item.videoUrl; },
          onImage: (url: string) => { this.imageScale = 1; this.viewingImage = url; },
          onOpenQuoted: (id: string) => this.openQuoted(id),
          onOpenUser: (handle: string) => this.profileHandle = handle
        })
      }.width('100%').height('100%')
      .visibility(this.tab == 0 ? Visibility.Visible : Visibility.None)

      Column() {
        SearchView({
          bottomInset: this.bottomInset(),
          focusTick: this.searchFocusTick,
          trendsHomeTick: this.trendsHomeTick,
          cookie: this.cookie,
          onReply: (item: TweetItem) => this.openReply(item),
          onQuote: (item: TweetItem) => this.openQuote(item),
          onOpen: (item: TweetItem) => this.openDetail(item),
          onPlay: (item: TweetItem, startTime: number) => { this.playingVideoStart = startTime; this.playingVideoPoster = item.imageUrl; this.playingVideo = item.videoUrl; },
          onImage: (url: string) => { this.imageScale = 1; this.viewingImage = url; },
          onOpenQuoted: (id: string) => this.openQuoted(id),
          onOpenUser: (handle: string) => this.profileHandle = handle
        })
      }.width('100%').height('100%')
      .visibility(this.tab == 1 ? Visibility.Visible : Visibility.None)

      Column() { this.notificationsPage() }.width('100%').height('100%')
      .visibility(this.tab == 2 ? Visibility.Visible : Visibility.None)

      Column() { this.mePage() }.width('100%').height('100%')
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
    .gesture(
      PanGesture()
        .onActionUpdate((event: GestureEvent) => {
          if (!this.expanded) return;
          this.barX = Math.max(this.barGap, Math.min(this.paneWidth - this.barWidth - this.barGap, this.barX + event.offsetX));
        })
        .onActionEnd(() => {
          if (!this.expanded) return;
          const third = this.paneWidth / 3;
          const target = this.barX + this.barWidth / 2 < third ? 0 : (this.barX + this.barWidth / 2 > third * 2 ? 2 : 1);
          this.moveBar(target);
        })
    )
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
              this.loadProfile();
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
              this.loadProfile();
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

          Column() {
            this.detailPane()
          }.width('100%').height('100%').padding({ top: this.safeTop })
        }
        .showSideBar(this.selected == null || (this.expanded && this.splitEnabled))
        .sideBarWidth(this.expanded && this.splitEnabled ? this.splitWidth() : this.paneWidth)
        .minSideBarWidth(1)
        .maxSideBarWidth(this.paneWidth)
        .minContentWidth(0)
        .showControlButton(false)
        .autoHide(false)
        .width('100%').height('100%')
        .onAreaChange((oldValue: Area, newValue: Area) => {
          const w = parseFloat(`${newValue.width}`);
          const h = parseFloat(`${newValue.height}`);
          if (!isNaN(w)) {
            this.paneWidth = w;
            this.barWidth = this.pillWidth();
            let foldable = false;
            try { foldable = display.isFoldable(); } catch (e) {}
            if (!foldable) {
              this.expanded = w >= 600;
              if (!this.expanded) this.barMode = 1;
            }
            this.updateBarX();
          }
          if (!isNaN(h)) this.paneHeight = h;
        })

        if (this.expanded && this.splitEnabled) {
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
          .position({ x: this.splitWidth() - 6, y: this.paneHeight / 2 - 19 })
          .gesture(
            PanGesture()
              .onActionStart(() => { this.splitStartRatio = this.splitRatio; })
              .onActionUpdate((event: GestureEvent) => {
                if (this.paneWidth <= 0) return;
                const ratio = this.splitStartRatio + event.offsetX / this.paneWidth;
                this.splitRatio = Math.max(0.25, Math.min(0.75, ratio));
              })
          )
        }

        if (!this.composing) {
          this.barLayer()
        }

        if (this.profileHandle.length > 0) {
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
            onOpenTweet: (item: TweetItem) => this.openDetail(item),
            onReply: (item: TweetItem) => this.openReply(item),
            onQuote: (item: TweetItem) => this.openQuote(item),
            onPlay: (item: TweetItem, startTime: number) => { this.playingVideoStart = startTime; this.playingVideoPoster = item.imageUrl; this.playingVideo = item.videoUrl; },
            onImage: (url: string) => { this.imageScale = 1; this.viewingImage = url; },
            onOpenQuoted: (id: string) => this.openQuoted(id),
            onOpenUser: (handle: string) => this.profileHandle = handle
          })
          .width('100%').height('100%')
          .padding({ top: this.safeTop })
          .transition(
            TransitionEffect.translate({ x: '100%' })
              .combine(TransitionEffect.OPACITY)
              .animation({ duration: 280, curve: Curve.FastOutSlowIn })
          )
        }

        if (this.showEditProfile && this.profile != null) {
          EditProfilePage({
            cookie: this.cookie,
            profile: this.profile,
            onClose: () => {
              this.showEditProfile = false;
              this.loadProfile();
            },
            onSaved: (updated: UserProfile) => {
              this.profile = updated;
              this.showEditProfile = false;
            }
          })
            .width('100%').height('100%')
            .padding({ top: this.safeTop, bottom: this.safeBottom })
            .transition(
              TransitionEffect.translate({ x: '100%' })
                .combine(TransitionEffect.OPACITY)
                .animation({ duration: 280, curve: Curve.FastOutSlowIn })
            )
        }

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
            .padding({ top: this.safeTop })
            .transition(
              TransitionEffect.translate({ x: '100%' })
                .combine(TransitionEffect.OPACITY)
                .animation({ duration: 280, curve: Curve.FastOutSlowIn })
            )
        }

        if (this.showAbout) {
          AboutPage({
            page: $aboutPage,
            onClose: () => { this.showAbout = false; this.aboutPage = 'main'; }
          })
            .width('100%').height('100%')
            .padding({ top: this.safeTop, bottom: this.safeBottom })
            .transition(
              TransitionEffect.translate({ x: 18 })
                .combine(TransitionEffect.OPACITY)
                .animation({ duration: 280, curve: Curve.FastOutSlowIn })
            )
        }

        if (this.showMediaSettings) {
          MediaSettingsPage({
            imageLimitMb: this.imageLimitMb,
            gifLimitMb: this.gifLimitMb,
            quality: this.mediaQuality,
            onImageLimitChange: (value: number) => { this.imageLimitMb = value; this.saveMediaSettings(); },
            onGifLimitChange: (value: number) => { this.gifLimitMb = value; this.saveMediaSettings(); },
            onQualityChange: (value: number) => { this.mediaQuality = value; this.saveMediaSettings(); },
            onClose: () => { this.showMediaSettings = false; }
          })
            .width('100%').height('100%')
            .padding({ top: this.safeTop, bottom: this.safeBottom })
            .transition(
              TransitionEffect.translate({ x: 18 })
                .combine(TransitionEffect.OPACITY)
                .animation({ duration: 280, curve: Curve.FastOutSlowIn })
            )
        }

        if (this.showThemeSettings) {
          ThemeSettingsPage({
            mode: this.themeMode,
            splitEnabled: this.splitEnabled,
            barOpaque: this.barOpaque,
            onSplitChange: (value: boolean) => {
              this.splitEnabled = value;
              SessionStore.saveSplitEnabled(getContext(this) as common.UIAbilityContext, value);
            },
            onBarOpaqueChange: (value: boolean) => { this.barOpaque = value; },
            onSelect: (mode: string) => this.setThemeMode(mode),
            onClose: () => { this.showThemeSettings = false; }
          })
            .width('100%').height('100%')
            .padding({ top: this.safeTop, bottom: this.safeBottom })
            .transition(
              TransitionEffect.translate({ x: '100%' })
                .combine(TransitionEffect.OPACITY)
                .animation({ duration: 280, curve: Curve.FastOutSlowIn })
            )
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
          Stack({ alignContent: Alignment.TopEnd }) {
            Image(this.viewingImage)
              .width('100%').height('100%')
              .objectFit(ImageFit.Contain)
              .backgroundColor('#000000')
              .scale({ x: this.imageScale, y: this.imageScale })
              .gesture(
                PinchGesture()
                  .onActionUpdate((event: GestureEvent) => {
                    this.imageScale = Math.max(1, Math.min(4, event.scale));
                  })
              )
              .onClick(() => { this.imageScale = 1; })
            Button('关闭')
              .margin({ top: 12, right: 12 })
              .backgroundColor('#99000000')
              .fontColor('#FFFFFF')
              .onClick(() => this.closeImage())
          }
          .width('100%').height('100%')
          .backgroundColor('#000000')
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
