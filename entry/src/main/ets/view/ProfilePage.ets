import { TweetItem } from '../model/TweetItem';
import { UserProfile } from '../model/UserProfile';
import { XApi } from '../api/XApi';
import { ProfileTabPage } from './ProfileTabPage';

@Component
export struct ProfilePage {
  bottomInset: number = 76;
  cookie: string = '';
  @Prop @Watch('onHandleChanged') handle: string = '';
  @Prop @Watch('onKnownProfileChanged') knownProfile: UserProfile | null = null;
  onClose: () => void = () => {};
  onEditProfile: () => void = () => {};
  onOpenConnections: (kind: string, userId: string, title: string) => void = () => {};
  onOpenTweet: (item: TweetItem) => void = () => {};
  onReply: (item: TweetItem) => void = () => {};
  onQuote: (item: TweetItem) => void = () => {};
  onPlay: (item: TweetItem, startTime: number) => void = () => {};
  onImage: (url: string) => void = () => {};
  onOpenQuoted: (id: string) => void = () => {};
  onOpenUser: (handle: string) => void = () => {};
  @State profile: UserProfile | null = null;
  @State loading: boolean = true;
  @State error: string = '';
  @State activeTab: number = 0;
  private controller: SwiperController = new SwiperController();

  onHandleChanged(): void {
    this.profile = null;
    this.activeTab = 0;
    this.load();
  }

  onKnownProfileChanged(): void {
    if (this.knownProfile != null && this.knownProfile.handle == this.handle) {
      this.profile = this.knownProfile;
    }
  }

  aboutToAppear(): void {
    this.load();
  }

  private ownProfile(): boolean {
    return this.knownProfile != null && this.knownProfile.handle == this.handle;
  }

  private async load(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      if (this.knownProfile != null && this.knownProfile.handle == this.handle) {
        this.profile = this.knownProfile;
        this.loading = false;
        return;
      }
      this.profile = await XApi.userByScreenName(this.cookie, this.handle);
    } catch (e) {
      this.error = `${e}`;
    } finally {
      this.loading = false;
    }
  }

  private async refresh(): Promise<void> {
    if (this.knownProfile != null && this.knownProfile.handle == this.handle) {
      this.loading = true;
      try { this.profile = await XApi.viewerProfile(this.cookie); }
      catch (e) { this.error = `${e}`; }
      finally { this.loading = false; }
      return;
    }
    this.load();
  }

  private joined(): string {
    if (this.profile == null || this.profile.createdAt.length == 0) return '';
    const date = new Date(this.profile.createdAt);
    if (isNaN(date.getTime())) return '';
    return `${date.getFullYear()}年${date.getMonth() + 1}月加入`;
  }

  @Builder
  tabItem(index: number, title: string) {
    Column() {
      Text(title).fontSize(14)
        .fontWeight(this.activeTab == index ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.activeTab == index ? $r('app.color.text_primary') : $r('app.color.text_secondary'))
      Rect({ width: 52, height: 3 })
        .fill(this.activeTab == index ? $r('app.color.accent') : '#00000000')
        .radius(2).margin({ top: 6 })
    }
    .layoutWeight(1).padding({ top: 10, bottom: 2 })
    .onClick(() => {
      this.activeTab = index;
      this.controller.changeIndex(index, true);
    })
  }

  build() {
    Column() {
      Row() {
        Button('‹').backgroundColor('#00000000').fontColor($r('app.color.text_primary')).fontSize(26)
          .onClick(() => this.onClose())
        Text(this.profile != null ? this.profile.name : `@${this.handle}`)
          .fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary')).layoutWeight(1)
        if (this.ownProfile()) {
          Button('编辑资料').height(30).fontSize(12)
            .backgroundColor($r('app.color.surface_secondary')).fontColor($r('app.color.text_primary'))
            .onClick(() => this.onEditProfile())
        } else {
          Button('刷新').height(30).fontSize(12)
            .backgroundColor($r('app.color.surface_secondary')).fontColor($r('app.color.text_primary'))
            .onClick(() => this.refresh())
        }
      }.width('100%').height(48).padding({ left: 8, right: 12 })

      if (this.loading && this.profile == null) {
        Column() { LoadingProgress().width(32).height(32) }
          .layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.error.length > 0 && this.profile == null) {
        Column() {
          Text(this.error).fontSize(13).fontColor('#F4212E').padding(16)
          Button('重试').onClick(() => this.load())
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.profile != null) {
        Column() {
          if (this.profile!.bannerUrl.length > 0) {
            Image(this.profile!.bannerUrl).width('100%').height(110).objectFit(ImageFit.Cover)
          } else {
            Row().width('100%').height(82).backgroundColor($r('app.color.surface_secondary'))
          }
          Row() {
            if (this.profile!.avatarUrl.length > 0) {
              Image(this.profile!.avatarUrl).width(72).height(72).borderRadius(36)
                .border({ width: 3, color: $r('app.color.bg') })
            } else {
              Circle({ width: 72, height: 72 }).fill($r('app.color.accent'))
                .border({ width: 3, color: $r('app.color.bg') })
            }
            Blank()
          }.width('100%').padding({ left: 16, right: 16 }).offset({ y: -26 }).height(40)

          Row() {
            Text(this.profile!.name).fontSize(18).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            if (this.profile!.verified) {
              Text('✓').fontSize(10).fontColor('#FFFFFF')
                .width(16).height(16).textAlign(TextAlign.Center)
                .backgroundColor($r('app.color.accent')).borderRadius(8).margin({ left: 6 })
            }
          }.width('100%').alignItems(VerticalAlign.Center)
          Text(`@${this.profile!.handle}`).fontSize(13).fontColor($r('app.color.text_secondary')).margin({ top: 2 })
          if (this.profile!.description.length > 0) {
            Text(this.profile!.description).fontSize(14).lineHeight(20)
              .fontColor($r('app.color.text_primary')).margin({ top: 8 })
          }
          if (this.joined().length > 0) {
            Text(this.joined()).fontSize(12).fontColor($r('app.color.text_secondary')).margin({ top: 6 })
          }
          Row() {
            Text(`${this.profile!.following} 正在关注`).fontSize(13).fontColor($r('app.color.text_secondary'))
              .onClick(() => this.onOpenConnections('following', this.profile!.id, '正在关注'))
            Text(`${this.profile!.followers} 关注者`).fontSize(13).fontColor($r('app.color.text_secondary'))
              .margin({ left: 16 })
              .onClick(() => this.onOpenConnections('followers', this.profile!.id, '关注者'))
          }.margin({ top: 8 })
        }
        .width('100%').padding({ left: 16, right: 16, bottom: 8 }).alignItems(HorizontalAlign.Start)

        Row() {
          this.tabItem(0, '帖子')
          this.tabItem(1, '回复')
          this.tabItem(2, '转帖')
        }.width('100%')
        Divider().strokeWidth(1).color($r('app.color.divider'))

        Swiper(this.controller) {
          ProfileTabPage({
            cookie: this.cookie, handle: this.profile!.handle, tab: 0,
            active: this.activeTab == 0, bottomInset: this.bottomInset,
            onReply: (item: TweetItem) => this.onReply(item),
            onQuote: (item: TweetItem) => this.onQuote(item),
            onOpen: (item: TweetItem) => this.onOpenTweet(item),
            onPlay: (item: TweetItem, time: number) => this.onPlay(item, time),
            onImage: (url: string) => this.onImage(url),
            onOpenQuoted: (id: string) => this.onOpenQuoted(id),
            onOpenUser: (handle: string) => this.onOpenUser(handle)
          })
          ProfileTabPage({
            cookie: this.cookie, handle: this.profile!.handle, tab: 1,
            active: this.activeTab == 1, bottomInset: this.bottomInset,
            onReply: (item: TweetItem) => this.onReply(item),
            onQuote: (item: TweetItem) => this.onQuote(item),
            onOpen: (item: TweetItem) => this.onOpenTweet(item),
            onPlay: (item: TweetItem, time: number) => this.onPlay(item, time),
            onImage: (url: string) => this.onImage(url),
            onOpenQuoted: (id: string) => this.onOpenQuoted(id),
            onOpenUser: (handle: string) => this.onOpenUser(handle)
          })
          ProfileTabPage({
            cookie: this.cookie, handle: this.profile!.handle, tab: 2,
            active: this.activeTab == 2, bottomInset: this.bottomInset,
            onReply: (item: TweetItem) => this.onReply(item),
            onQuote: (item: TweetItem) => this.onQuote(item),
            onOpen: (item: TweetItem) => this.onOpenTweet(item),
            onPlay: (item: TweetItem, time: number) => this.onPlay(item, time),
            onImage: (url: string) => this.onImage(url),
            onOpenQuoted: (id: string) => this.onOpenQuoted(id),
            onOpenUser: (handle: string) => this.onOpenUser(handle)
          })
        }
        .index(this.activeTab)
        .onChange((index: number) => { this.activeTab = index; })
        .indicator(false).loop(false)
        .duration(280).curve(Curve.EaseOut)
        .cachedCount(3)
        .layoutWeight(1).width('100%')
      }
    }.width('100%').height('100%').backgroundColor($r('app.color.bg'))
  }
}
