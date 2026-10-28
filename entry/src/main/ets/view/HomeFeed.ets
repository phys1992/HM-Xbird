import { TweetItem } from '../model/TweetItem';
import { XApi, HomeResult, errorText } from '../api/XApi';
import { TweetCard } from './TweetCard';

@Component
struct TimelinePage {
  mode: number = 0;
  bottomInset: number = 76;
  @Prop @Watch('onScrollTopRequested') scrollTopTick: number = 0;
  @Prop @Watch('onActiveChanged') active: boolean = false;
  @Prop @Watch('onPreloadChanged') preload: boolean = false;
  onFirstLoaded: () => void = () => {};
  onReady: () => void = () => {};
  cookie: string = '';
  onReply: (item: TweetItem) => void = () => {};
  onQuote: (item: TweetItem) => void = () => {};
  onOpen: (item: TweetItem) => void = () => {};
  onPrefetch: (item: TweetItem) => void = () => {};
  onPlay: (item: TweetItem, startTime: number) => void = () => {};
  onImage: (url: string) => void = () => {};
  onOpenQuoted: (id: string) => void = () => {};
  onOpenUser: (handle: string) => void = () => {};
  @State tweets: TweetItem[] = [];
  @State loading: boolean = false;
  @State error: string = '';
  @State notice: string = '';
  @State cursor: string = '';
  @State refreshing: boolean = false;
  private listScroller: Scroller = new Scroller();
  private scrollOffset: number = 0;
  private firstVisibleIndex: number = 0;
  private restoring: boolean = false;
  private announced: boolean = false;

  private storageKey(): string {
    return this.mode == 0 ? 'tuichuang_foryou_offset' : 'tuichuang_following_offset';
  }

  aboutToAppear(): void {
    if (this.active) this.load(false);
  }

  onScrollTopRequested(): void {
    if (!this.active) return;
    let y = 0;
    try { y = this.listScroller.currentOffset().yOffset; } catch (e) {}
    if (y > 1) {
      this.restoring = true;
      AppStorage.setOrCreate(this.storageKey(), 0);
      this.listScroller.scrollToIndex(0, true, ScrollAlign.START);
      setTimeout(() => {
        this.scrollOffset = 0;
        AppStorage.setOrCreate(this.storageKey(), 0);
        this.restoring = false;
      }, 450);
    } else {
      this.refreshNew();
    }
  }

  onActiveChanged(): void {
    if (this.active && this.tweets.length == 0 && !this.loading) this.load(false);
  }

  onPreloadChanged(): void {
    if (this.preload && !this.active && this.tweets.length == 0 && !this.loading) {
      this.load(false);
    }
  }

  private async fetchFirst(): Promise<HomeResult> {
    if (this.mode == 0) {
      try {
        return await XApi.forYou(this.cookie, '');
      } catch (e) {
        this.notice = '“为你推荐”暂不可用，已显示关注时间线';
        return await XApi.homeLatest(this.cookie, '');
      }
    }
    return await XApi.homeLatest(this.cookie, '');
  }

  private async load(more: boolean): Promise<void> {
    if (this.loading) return;
    this.loading = true;
    this.error = '';
    try {
      let page: HomeResult;
      if (more) {
        page = this.mode == 0 ? await XApi.forYou(this.cookie, this.cursor)
          : await XApi.homeLatest(this.cookie, this.cursor);
      } else {
        page = await this.fetchFirst();
      }
      this.tweets = more ? this.tweets.concat(page.tweets) : page.tweets;
      this.cursor = page.cursor;
      if (!more) {
        const saved = AppStorage.get<number>(this.storageKey()) ?? 0;
        this.scrollOffset = saved;
        if (saved > 0) {
          this.restoring = true;
          setTimeout(() => {
            this.listScroller.scrollTo({ xOffset: 0, yOffset: saved, animation: false });
            this.restoring = false;
          }, 120);
        }
        for (let i = 0; i < this.tweets.length && i < 3; i++) {
          this.onPrefetch(this.tweets[i]);
        }
        if (!this.announced) {
          this.announced = true;
          this.onFirstLoaded();
        }
      }
    } catch (e) {
      this.error = errorText(e);
    } finally {
      this.loading = false;
    }
  }

  private async refreshNew(): Promise<void> {
    if (this.loading) { this.refreshing = false; return; }
    this.refreshing = true;
    try {
      const page = await this.fetchFirst();
      const existing: string[] = this.tweets.map((t: TweetItem) => t.id);
      const fresh = page.tweets.filter((t: TweetItem) => existing.indexOf(t.id) < 0);
      if (fresh.length > 0) {
        const anchor = this.firstVisibleIndex;
        this.restoring = true;
        this.tweets = fresh.concat(this.tweets);
        // Wait for Refresh to finish its pull-back, then reveal the bottom of
        // the newly inserted block with the system smooth-scroll animation.
        setTimeout(() => {
          this.listScroller.scrollToIndex(anchor + fresh.length, false, ScrollAlign.START);
          setTimeout(() => {
            this.scrollOffset = this.listScroller.currentOffset().yOffset;
            AppStorage.setOrCreate(this.storageKey(), this.scrollOffset);
            this.restoring = false;
          }, 420);
        }, 0);
      }
    } catch (e) {
      this.notice = `刷新失败：${e}`;
    } finally {
      this.refreshing = false;
    }
  }

  build() {
    Column() {
      if (this.notice.length > 0) {
        Text(this.notice).fontSize(11).fontColor('#F59E0B')
          .width('100%').padding({ left: 12, top: 4 })
      }

      if (this.error.length > 0) {
        Column() {
          Text(this.error).fontSize(13).fontColor('#F4212E').padding(16)
          Button('重试').onClick(() => this.load(false))
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.loading && this.tweets.length == 0) {
        Column() {
          LoadingProgress().width(36).height(36)
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.tweets.length == 0) {
        Column() {
          Text('暂无内容').fontSize(14).fontColor($r('app.color.text_secondary'))
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        Refresh({ refreshing: this.refreshing }) {
          List({ scroller: this.listScroller }) {
            ForEach(this.tweets, (item: TweetItem) => {
              ListItem() {
                Column() {
                  TweetCard({
                    item: item,
                    cookie: this.cookie,
                    onReply: (value: TweetItem) => this.onReply(value),
                    onQuote: (value: TweetItem) => this.onQuote(value),
                    onOpen: (value: TweetItem) => this.onOpen(value),
                    onPlay: (value: TweetItem, startTime: number) => this.onPlay(value, startTime),
                    onImage: (url: string) => this.onImage(url),
                    onOpenQuoted: (id: string) => this.onOpenQuoted(id),
                    onOpenUser: (handle: string) => this.onOpenUser(handle)
                  })
                  Divider().strokeWidth(1).color($r('app.color.divider'))
                }
                .transition(
                  TransitionEffect.OPACITY
                    .combine(TransitionEffect.translate({ y: -10 }))
                    .animation({ duration: 220, curve: Curve.EaseOut })
                )
              }
            }, (item: TweetItem) => item.id)

            ListItem() {
              Row() {
                LoadingProgress().width(18).height(18)
                Text('加载更多…').fontSize(12).fontColor($r('app.color.text_secondary')).margin({ left: 6 })
              }.width('100%').justifyContent(FlexAlign.Center).padding(12)
            }
          }
          .width('100%').height('100%')
          .backgroundColor($r('app.color.bg'))
          .contentEndOffset(this.bottomInset)
          .onScrollIndex((start: number) => {
            this.firstVisibleIndex = start;
          })
          .onScroll((offset: number) => {
            if (this.restoring) return;
            this.scrollOffset = Math.max(0, this.scrollOffset + offset);
            AppStorage.setOrCreate(this.storageKey(), this.scrollOffset);
          })
          .onReachEnd(() => {
            if (!this.loading && this.cursor.length > 0) this.load(true);
          })
        }
        .onRefreshing(() => {
          this.refreshNew();
        })
        .layoutWeight(1)
        .width('100%')
        .backgroundColor($r('app.color.bg'))
      }
    }
    .width('100%').height('100%')
    .backgroundColor($r('app.color.bg'))
  }
}

@Component
export struct HomeFeed {
  bottomInset: number = 76;
  @Prop scrollTopTick: number = 0;
  cookie: string = '';
  onReady: () => void = () => {};
  onReply: (item: TweetItem) => void = () => {};
  onQuote: (item: TweetItem) => void = () => {};
  onOpen: (item: TweetItem) => void = () => {};
  onPrefetch: (item: TweetItem) => void = () => {};
  onPlay: (item: TweetItem, startTime: number) => void = () => {};
  onImage: (url: string) => void = () => {};
  onOpenQuoted: (id: string) => void = () => {};
  onOpenUser: (handle: string) => void = () => {};
  @State homeIndex: number = 0;
  @State preloadFollowing: boolean = false;
  private preloadScheduled: boolean = false;
  private controller: SwiperController = new SwiperController();

  @Builder
  tabItem(index: number, title: string) {
    Column() {
      Text(title).fontSize(15)
        .fontWeight(this.homeIndex == index ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.homeIndex == index ? $r('app.color.text_primary') : $r('app.color.text_secondary'))
      Rect({ width: 44, height: 3 })
        .fill(this.homeIndex == index ? $r('app.color.accent') : '#00000000')
        .radius(2).margin({ top: 4 })
    }
    .layoutWeight(1).padding({ top: 4 })
    .onClick(() => {
      this.homeIndex = index;
      this.controller.changeIndex(index, true);
    })
  }

  private schedulePreload(): void {
    if (this.preloadScheduled) return;
    this.preloadScheduled = true;
    setTimeout(() => {
      this.preloadFollowing = true;
    }, 800);
  }

  build() {
    Column() {
      Row() {
        this.tabItem(0, '为你推荐')
        this.tabItem(1, '正在关注')
      }.width('100%')

      Swiper(this.controller) {
        TimelinePage({
          mode: 0,
          bottomInset: this.bottomInset,
          scrollTopTick: this.scrollTopTick,
          active: this.homeIndex == 0,
          preload: false,
          onFirstLoaded: () => { this.schedulePreload(); this.onReady(); },
          cookie: this.cookie,
          onReply: (item: TweetItem) => this.onReply(item),
          onQuote: (item: TweetItem) => this.onQuote(item),
          onOpen: (item: TweetItem) => this.onOpen(item),
          onPrefetch: (item: TweetItem) => this.onPrefetch(item),
          onPlay: (item: TweetItem, startTime: number) => this.onPlay(item, startTime),
          onImage: (url: string) => this.onImage(url),
          onOpenQuoted: (id: string) => this.onOpenQuoted(id),
          onOpenUser: (handle: string) => this.onOpenUser(handle)
        })
        TimelinePage({
          mode: 1,
          bottomInset: this.bottomInset,
          scrollTopTick: this.scrollTopTick,
          active: this.homeIndex == 1,
          preload: this.preloadFollowing,
          onFirstLoaded: () => {},
          cookie: this.cookie,
          onReply: (item: TweetItem) => this.onReply(item),
          onQuote: (item: TweetItem) => this.onQuote(item),
          onOpen: (item: TweetItem) => this.onOpen(item),
          onPrefetch: (item: TweetItem) => this.onPrefetch(item),
          onPlay: (item: TweetItem, startTime: number) => this.onPlay(item, startTime),
          onImage: (url: string) => this.onImage(url),
          onOpenQuoted: (id: string) => this.onOpenQuoted(id),
          onOpenUser: (handle: string) => this.onOpenUser(handle)
        })
      }
      .index(this.homeIndex)
      .onChange((index: number) => { this.homeIndex = index; })
      .indicator(false)
      .loop(false)
      .duration(280)
      .curve(Curve.EaseOut)
      .cachedCount(2)
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%').height('100%')
    .backgroundColor($r('app.color.bg'))
  }
}
