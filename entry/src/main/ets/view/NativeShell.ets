import { display } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { TweetItem } from '../model/TweetItem';
import { SessionStore } from '../model/SessionStore';
import { BackDispatcher } from '../model/BackDispatcher';
import { LoginView } from './LoginView';
import { NativeLogin } from './NativeLogin';
import { HomeFeed } from './HomeFeed';
import { SearchView } from './SearchView';
import { XApi } from '../api/XApi';
import { DetailCache } from '../model/DetailCache';
import { NotificationItem } from '../model/NotificationItem';
import { UserProfile } from '../model/UserProfile';
import { TweetCard } from './TweetCard';
import { ComposeView } from './ComposeView';

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
  @State profile: UserProfile | null = null;
  @State profileLoading: boolean = false;
  @State splitEnabled: boolean = true;
  @State playingVideo: string = '';
  @State viewingImage: string = '';
  @State showWebLogin: boolean = false;
  @State sheenX: number = -120;
  private videoController: VideoController = new VideoController();
  @StorageLink('memoryTrimTick') @Watch('onMemoryTrim') memoryTick: number = 0;
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
    const saved = SessionStore.loadCookie(context);
    if (saved.length > 0) {
      this.cookie = saved;
      this.loggedIn = true;
      this.loadProfile();
    }
    this.splitEnabled = SessionStore.loadSplitEnabled(context);
    animateTo({
      duration: 2600,
      curve: Curve.EaseInOut,
      iterations: -1,
      playMode: PlayMode.Alternate
    }, () => {
      this.sheenX = 300;
    });
    try {
      this.expanded = display.getFoldStatus() == display.FoldStatus.FOLD_STATUS_EXPANDED;
      display.on('foldStatusChange', (status: number) => {
        this.expanded = status == display.FoldStatus.FOLD_STATUS_EXPANDED;
      });
    } catch (e) {}
  }

  aboutToDisappear(): void {
    try {
      display.off('foldStatusChange');
    } catch (e) {}
  }

  private handleBack(): boolean {
    if (this.viewingImage.length > 0) {
      this.viewingImage = '';
      return true;
    }
    if (this.playingVideo.length > 0) {
      this.playingVideo = '';
      return true;
    }
    if (this.composing) {
      this.composing = false;
      return true;
    }
    if (this.selected != null) {
      this.selected = null;
      this.detailTweets = [];
      this.detailError = '';
      return true;
    }
    if (this.tab != 0) {
      this.tab = 0;
      return true;
    }
    return false;
  }

  private updateBarX(): void {
    const mode = this.expanded ? this.barMode : 1;
    let x = (this.paneWidth - 320) / 2;
    if (mode == 0) x = 10;
    if (mode == 2) x = this.paneWidth - 330;
    this.barX = Math.max(8, x);
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
    const id = this.twid();
    if (id.length == 0 || this.profileLoading) return;
    this.profileLoading = true;
    try {
      this.profile = await XApi.userByRestId(this.cookie, id);
    } catch (e) {
      // Keep the page usable; profile header is optional.
    } finally {
      this.profileLoading = false;
    }
  }

  private async loadNotifications(): Promise<void> {
    if (this.notificationsLoading) return;
    this.notificationsLoading = true;
    this.notificationsError = '';
    try {
      const list = await XApi.notifications(this.cookie);
      if (list.length > 0) this.notifications = list;
      this.notificationsLoaded = true;
    } catch (e) {
      this.notificationsError = `${e}`;
    } finally {
      this.notificationsLoading = false;
    }
  }

  private onMemoryTrim(): void {
    DetailCache.clear();
  }

  private openNotification(item: NotificationItem): void {
    if (item.tweetId.length == 0) return;
    const tweet = new TweetItem();
    tweet.id = item.tweetId;
    tweet.authorName = item.authorName;
    tweet.authorHandle = item.authorHandle;
    this.openDetail(tweet);
  }

  private async openDetail(item: TweetItem): Promise<void> {
    this.selected = item;
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

  private logout(): void {
    SessionStore.clear(getContext(this) as common.UIAbilityContext);
    this.cookie = '';
    this.loggedIn = false;
    this.selected = null;
    this.tab = 0;
  }

  @Builder
  navItem(index: number, icon: Resource, label: string) {
    Column() {
      Image(icon).width(22).height(22)
        .fillColor(this.tab == index ? '#1D9BF0' : '#536471')
      Text(label).fontSize(10)
        .fontColor(this.tab == index ? '#1D9BF0' : '#536471')
        .margin({ top: 2 })
    }
    .layoutWeight(1).height(52).justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.tab = index;
      this.selected = null;
      if (index == 2) this.loadNotifications();
    })
  }

  @Builder
  bottomBar() {
    Stack({ alignContent: Alignment.Start }) {
      Row() {
        this.navItem(0, $r('app.media.ic_home'), '主页')
        this.navItem(1, $r('app.media.ic_search'), '搜索')
        Column() {
          Button() {
            Image($r('app.media.ic_plus')).width(20).height(20).fillColor('#FFFFFF')
          }
          .width(44).height(44).borderRadius(22).backgroundColor('#0F1419')
          .onClick(() => {
            this.replyId = '';
            this.quoteId = '';
            this.composing = true;
          })
        }.layoutWeight(1).height(52).justifyContent(FlexAlign.Center)
        this.navItem(2, $r('app.media.ic_bell'), '通知')
        this.navItem(3, $r('app.media.ic_user'), '我的')
      }
      .width('100%').height('100%')
      .padding({ left: 6, right: 6 })

      Row()
        .width(90).height('100%')
        .linearGradient({
          angle: 90,
          colors: [['#00FFFFFF', 0.0], ['#80FFFFFF', 0.5], ['#00FFFFFF', 1.0]]
        })
        .blur(8).opacity(0.5)
        .offset({ x: this.sheenX })
        .hitTestBehavior(HitTestMode.None)
    }
    .width(320).height(60).borderRadius(30)
    .clip(true)
    .backgroundColor('#CCFFFFFF')
    .backgroundBlurStyle(BlurStyle.Thick)
    .border({ width: 1, color: '#99FFFFFF' })
    .shadow({ radius: 18, color: '#26000000', offsetY: 5 })
    .margin({ bottom: 12 })
  }

  @Builder
  mePage() {
    Column() {
      Row() {
        if (this.profile != null && this.profile.avatarUrl.length > 0) {
          Image(this.profile.avatarUrl).width(56).height(56).borderRadius(28)
        } else {
          Circle({ width: 56, height: 56 }).fill('#1D9BF0')
        }
        Column() {
          Text(this.profile != null ? this.profile.name : 'tuichuang')
            .fontSize(17).fontWeight(FontWeight.Bold)
          Text(this.profile != null ? `@${this.profile.handle}` : '正在加载资料…')
            .fontSize(13).fontColor('#536471').margin({ top: 2 })
        }.alignItems(HorizontalAlign.Start).margin({ left: 12 }).layoutWeight(1)
      }.width('100%').padding(16)

      if (this.profile != null && this.profile.description.length > 0) {
        Text(this.profile.description).fontSize(14).lineHeight(20)
          .width('100%').padding({ left: 16, right: 16, bottom: 10 })
      }
      if (this.profile != null) {
        Row() {
          Text(`${this.profile.following} 正在关注`).fontSize(13).fontColor('#536471')
          Text(`${this.profile.followers} 关注者`).fontSize(13).fontColor('#536471').margin({ left: 16 })
        }.width('100%').padding({ left: 16, bottom: 12 })
      }

      Divider().color('#EFF3F4')
      Row() {
        Column() {
          Text('启用分栏').fontSize(15)
          Text(this.expanded ? '当前已展开' : '折叠屏展开后生效').fontSize(12).fontColor('#536471').margin({ top: 2 })
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.splitEnabled })
          .onChange((value: boolean) => {
            this.splitEnabled = value;
            SessionStore.saveSplitEnabled(getContext(this) as common.UIAbilityContext, value);
          })
      }.width('100%').padding(16)

      Row() {
        Text('退出登录').fontSize(15).fontColor('#F4212E')
      }.width('100%').padding(16).onClick(() => this.logout())
      Blank()
    }.width('100%').height('100%')
  }

  @Builder
  notificationsPage() {
    Column() {
      Text('通知').fontSize(20).fontWeight(FontWeight.Bold).width('100%').padding(16)

      if (this.notificationsLoading && this.notifications.length == 0) {
        Column() { LoadingProgress().width(28).height(28) }
          .layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.notificationsError.length > 0 && this.notifications.length == 0) {
        Column() {
          Text(this.notificationsError).fontSize(13).fontColor('#F4212E').padding(16)
          Button('重试').onClick(() => this.loadNotifications())
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.notifications.length == 0) {
        Column() {
          Text(this.notificationsLoaded ? '暂无通知' : '打开通知时加载').fontSize(14).fontColor('#536471')
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
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
                    .fontSize(14).maxLines(4).textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(item.authorName.length > 0 ? `@${item.authorHandle}` : '')
                    .fontSize(12).fontColor('#536471').margin({ top: 3 })
                }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 10 })
              }
              .width('100%').padding(14)
              .onClick(() => this.openNotification(item))
              Divider().color('#EFF3F4')
              }.width('100%')
            }
          }, (item: NotificationItem) => item.id)
        }
        .layoutWeight(1).width('100%')
      }
    }.width('100%').height('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  detailPane() {
    Column() {
      if (this.selected == null) {
        Text('选择左侧推文').fontSize(15).fontColor('#536471')
      } else {
        Row() {
          if (!this.expanded) {
            Button('‹').backgroundColor('#00000000').fontColor('#0F1419').fontSize(22)
              .onClick(() => {
                this.selected = null;
                this.detailTweets = [];
              })
          }
          Text('帖子').fontSize(17).fontWeight(FontWeight.Bold).layoutWeight(1)
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
                    onPlay: (value: TweetItem) => this.playingVideo = value.videoUrl,
                    onImage: (url: string) => this.viewingImage = url
                  })
                  Divider().color('#EFF3F4')
                }
              }
            }, (item: TweetItem) => item.id)
          }
          .layoutWeight(1).width('100%')
          .onReachEnd(() => {})
        }

        if (this.detailLoading) {
          Row() {
            LoadingProgress().width(20).height(20)
            Text('加载评论…').fontSize(12).fontColor('#536471').margin({ left: 8 })
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
          cookie: this.cookie,
          onReply: (item: TweetItem) => this.openReply(item),
          onQuote: (item: TweetItem) => this.openQuote(item),
          onOpen: (item: TweetItem) => this.openDetail(item),
          onPrefetch: (item: TweetItem) => this.prefetchDetail(item),
          onPlay: (item: TweetItem) => this.playingVideo = item.videoUrl,
          onImage: (url: string) => this.viewingImage = url
        })
      }.width('100%').height('100%')
      .visibility(this.tab == 0 ? Visibility.Visible : Visibility.None)

      Column() {
        SearchView({
          cookie: this.cookie,
          onReply: (item: TweetItem) => this.openReply(item),
          onQuote: (item: TweetItem) => this.openQuote(item),
          onOpen: (item: TweetItem) => this.openDetail(item),
          onPlay: (item: TweetItem) => this.playingVideo = item.videoUrl,
          onImage: (url: string) => this.viewingImage = url
        })
      }.width('100%').height('100%')
      .visibility(this.tab == 1 ? Visibility.Visible : Visibility.None)

      Column() { this.notificationsPage() }.width('100%').height('100%')
      .visibility(this.tab == 2 ? Visibility.Visible : Visibility.None)

      Column() { this.mePage() }.width('100%').height('100%')
      .visibility(this.tab == 3 ? Visibility.Visible : Visibility.None)
    }.width('100%').height('100%')
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      if (!this.loggedIn) {
        if (this.showWebLogin) {
          LoginView({
            onLoggedIn: (cookie: string, jsUrls: string) => {
              const context = getContext(this) as common.UIAbilityContext;
              SessionStore.saveCookie(context, cookie);
              SessionStore.saveJsUrls(context, jsUrls);
              this.cookie = cookie;
              this.loggedIn = true;
              this.showWebLogin = false;
              this.loadProfile();
            }
          })
        } else {
          NativeLogin({
            onLoggedIn: (cookie: string) => {
              SessionStore.saveCookie(getContext(this) as common.UIAbilityContext, cookie);
              this.cookie = cookie;
              this.loggedIn = true;
              this.loadProfile();
            },
            onWebLogin: () => this.showWebLogin = true
          })
        }
      } else {
        SideBarContainer(SideBarContainerType.Embed) {
          Column() {
            this.contentStack()
          }.width('100%').height('100%').padding({ bottom: 76 })

          Column() {
            this.detailPane()
          }.width('100%').height('100%').padding({ bottom: 76 })
        }
        .showSideBar(true)
        .sideBarWidth(this.expanded && this.splitEnabled ? this.paneWidth * 0.5 :
          (this.selected != null ? 0 : this.paneWidth))
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
            if (!this.expanded) this.barMode = 1;
            this.updateBarX();
          }
          if (!isNaN(h)) this.paneHeight = h;
        })

        Column() {
          this.bottomBar()
        }
        .width('100%').height(76)
        .padding({ left: this.barX })
        .justifyContent(FlexAlign.Center)
        .hitTestBehavior(HitTestMode.Transparent)

        if (this.composing) {
          ComposeView({
            cookie: this.cookie,
            replyToId: this.replyId,
            replyToHandle: this.replyHandle,
            quoteId: this.quoteId,
            quoteHandle: this.quoteHandle,
            quoteText: this.quoteText,
            onClose: () => this.composing = false
          })
          .width('100%').height('100%')
        }

        if (this.viewingImage.length > 0) {
          Stack({ alignContent: Alignment.TopEnd }) {
            Image(this.viewingImage)
              .width('100%').height('100%')
              .objectFit(ImageFit.Contain)
              .backgroundColor('#000000')
            Button('关闭')
              .margin({ top: 12, right: 12 })
              .backgroundColor('#99000000')
              .fontColor('#FFFFFF')
              .onClick(() => this.viewingImage = '')
          }
          .width('100%').height('100%')
          .backgroundColor('#000000')
        }

        if (this.playingVideo.length > 0) {
          Stack({ alignContent: Alignment.TopEnd }) {
            Video({
              src: this.playingVideo,
              controller: this.videoController
            })
              .width('100%').height('100%')
              .objectFit(ImageFit.Contain)
              .autoPlay(true)
              .controls(true)
              .backgroundColor('#000000')
            Button('关闭')
              .margin({ top: 12, right: 12 })
              .backgroundColor('#99000000')
              .fontColor('#FFFFFF')
              .onClick(() => this.playingVideo = '')
          }
          .width('100%').height('100%')
          .backgroundColor('#000000')
        }
      }
    }
    .width('100%').height('100%')
    .backgroundColor('#FFFFFF')
    .onTouchIntercept((event: TouchEvent) => {
      if (this.expanded && event.type == TouchType.Down && event.touches.length > 0) {
        const x = event.touches[0].x;
        const y = event.touches[0].y;
        if (y < this.paneHeight - 110) {
          this.moveBar(x < this.paneWidth / 2 ? 0 : 2);
        }
      }
      return HitTestMode.Default;
    })
  }
}
