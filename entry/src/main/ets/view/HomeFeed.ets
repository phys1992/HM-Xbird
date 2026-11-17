import { TweetItem } from '../model/TweetItem';
import { XApi, HomeResult, errorText } from '../api/XApi';
import { TweetCard } from './TweetCard';
import { VideoAutoplay } from '../model/VideoAutoplay';
import { I18n } from '../model/I18n';
import { FollowStatusStore } from '../model/FollowStatusStore';
import { HomeTimelineCache, HomeTimelineSnapshot } from '../model/HomeTimelineCache';
import { common } from '@kit.AbilityKit';

@Component
struct TimelinePage {
  @StorageProp('clientLang') clientLanguage: string = 'zh';
  private tr(value: string): string {
    return this.clientLanguage.length >= 0 ? I18n.t(value) : I18n.t(value);
  }

  mode: number = 0;
  bottomInset: number = 76;
  @Prop @Watch('onScrollTopRequested') scrollTopTick: number = 0;
  @Prop @Watch('onActiveChanged') active: boolean = false;
  @Prop @Watch('onPreloadChanged') preload: boolean = false;
  onFirstLoaded: () => void = () => {};
  onReady: () => void = () => {};
  cookie: string = '';
  viewerHandle: string = '';
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
  private followChecked: Record<string, boolean> = {};

  private storageKey(): string {
    return this.mode == 0 ? 'tuichuang_foryou_offset' : 'tuichuang_following_offset';
  }

  aboutToAppear(): void {
    this.loadCached();
    if (this.active && this.tweets.length == 0) this.load(false);
  }

  private loadCached(): void {
    const snapshot = HomeTimelineCache.load(getContext(this) as common.UIAbilityContext, this.mode);
    if (snapshot.tweets.length == 0) return;
    this.tweets = snapshot.tweets;
    this.cursor = snapshot.cursor;
    this.resolveFollowStates();
    if (!this.announced) {
      this.announced = true;
      this.onFirstLoaded();
    }
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
    if (this.active && this.tweets.length == 0 && !this.loading) {
      this.loadCached();
      if (this.tweets.length == 0) this.load(false);
    }
  }

  onPreloadChanged(): void {
    if (this.preload && this.tweets.length == 0) this.loadCached();
  }

  private async fetchFirst(): Promise<HomeResult> {
    if (this.mode == 0) {
      try {
        return await XApi.forYou(this.cookie, '');
      } catch (e) {
        this.notice = this.tr('“为你推荐”暂不可用，已显示关注时间线');
        return await XApi.homeLatest(this.cookie, '');
      }
    }
    return await XApi.homeLatest(this.cookie, '');
  }

  private resolveFollowStates(): void {
    const handles: string[] = [];
    for (const tweet of this.tweets) {
      const handle = tweet.authorHandle;
      if (handle.length > 0 && this.followChecked[handle] == undefined && handles.indexOf(handle) < 0) {
        handles.push(handle);
      }
    }
    if (handles.length == 0) return;
    for (const handle of handles) this.followChecked[handle] = true;
    XApi.followStates(this.cookie, handles).then((states: Record<string, boolean>) => {
      const known: Record<string, boolean> = {};
      let count = 0;
      for (const handle of handles) {
        if (states[handle] != undefined) {
          known[handle] = states[handle];
          count += 1;
        }
      }
      if (count > 0) FollowStatusStore.set(known);
    }).catch(() => {});
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
      this.resolveFollowStates();
      this.cursor = page.cursor;
      if (!more) {
        HomeTimelineCache.save(getContext(this) as common.UIAbilityContext,
          this.mode, this.tweets, this.cursor);
      }
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
        this.resolveFollowStates();
        // Wait for Refresh to finish its pull-back, then reveal the bottom of
        // the newly inserted block with the system smooth-scroll animation.
        HomeTimelineCache.save(getContext(this) as common.UIAbilityContext,
          this.mode, this.tweets, this.cursor);
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
      this.notice = this.tr(`刷新失败：${e}`);
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
          Button(this.tr('重试')).onClick(() => this.load(false))
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.loading && this.tweets.length == 0) {
        Column() {
          LoadingProgress().width(36).height(36)
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.tweets.length == 0) {
        Column() {
          Text(this.tr('暂无内容')).fontSize(14).fontColor($r('app.color.text_secondary'))
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        Refresh({ refreshing: this.refreshing }) {
          List({ scroller: this.listScroller }) {
            ForEach(this.tweets, (item: TweetItem, index: number) => {
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
                    onOpenUser: (handle: string) => this.onOpenUser(handle),
                    viewerHandle: this.viewerHandle,
                    showFollow: true,
                    videoPane: 'left',
                    videoIndex: index
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
                Text(this.tr('加载更多…')).fontSize(12).fontColor($r('app.color.text_secondary')).margin({ left: 6 })
              }.width('100%').justifyContent(FlexAlign.Center).padding(12)
            }
          }
          .width('100%').height('100%')
          .backgroundColor($r('app.color.bg'))
          .contentEndOffset(this.bottomInset)
          .onScrollIndex((start: number) => {
            this.firstVisibleIndex = start;
          })
          .onScrollStart(() => VideoAutoplay.onScrollStart())
          .onScrollStop(() => VideoAutoplay.onScrollStop())
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
  @StorageProp('clientLang') clientLanguage: string = 'zh';
  private tr(value: string): string {
    return this.clientLanguage.length >= 0 ? I18n.t(value) : I18n.t(value);
  }

  bottomInset: number = 76;
  @Prop scrollTopTick: number = 0;
  cookie: string = '';
  viewerHandle: string = '';
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
  @State displayIndex: number = 0;
  @State indicatorX: number = 0;
  @State tabBarW: number = 0;
  @State preloadFollowing: boolean = false;
  private preloadScheduled: boolean = false;
  private controller: SwiperController = new SwiperController();
  private readonly indicatorW: number = 44;

  @Builder
  tabItem(index: number, title: string) {
    Column() {
      Text(this.tr(title)).fontSize(15)
        .fontWeight(this.displayIndex == index ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.displayIndex == index ? $r('app.color.text_primary') : $r('app.color.text_secondary'))
    }
    .layoutWeight(1).height(44).justifyContent(FlexAlign.Center)
    .onClick(() => this.switchTab(index))
  }

  private tabLeft(index: number): number {
    if (this.tabBarW <= 0) return 0;
    const slot = this.tabBarW / 2;
    return index * slot + (slot - this.indicatorW) / 2;
  }

  private animateIndicatorTo(index: number, duration: number): void {
    const target = this.tabLeft(index);
    if (duration <= 0) {
      this.indicatorX = target;
      return;
    }
    animateTo({ duration: duration, curve: Curve.EaseOut }, () => {
      this.indicatorX = target;
    });
  }

  private updateSwipeIndicator(index: number, offset: number): void {
    if (this.tabBarW <= 0) return;
    const slot = this.tabBarW / 2;
    const ratio = Math.min(1, Math.abs(offset) / this.tabBarW);
    let next = index;
    if (offset < 0 && index < 1) next = index + 1;
    else if (offset > 0 && index > 0) next = index - 1;
    const fraction = index + (next - index) * ratio;
    this.indicatorX = fraction * slot + (slot - this.indicatorW) / 2;
    this.displayIndex = ratio > 0.5 ? next : index;
  }

  private switchTab(index: number): void {
    this.displayIndex = index;
    this.homeIndex = index;
    this.animateIndicatorTo(index, 280);
    this.controller.changeIndex(index, true);
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
      Stack({ alignContent: Alignment.BottomStart }) {
        Row() {
          this.tabItem(0, '为你推荐')
          this.tabItem(1, '正在关注')
        }.width('100%').height(44)
        .onAreaChange((oldValue: Area, newValue: Area) => {
          const w = parseFloat(`${newValue.width}`);
          if (!isNaN(w) && w > 0) {
            this.tabBarW = w;
            this.indicatorX = this.tabLeft(this.displayIndex);
          }
        })

        Rect({ width: this.indicatorW, height: 3 })
          .fill($r('app.color.accent'))
          .radius(2)
          .position({ x: this.indicatorX, y: 41 })
      }.width('100%').height(44)

      Swiper(this.controller) {
        TimelinePage({
          mode: 0,
          bottomInset: this.bottomInset,
          scrollTopTick: this.scrollTopTick,
          active: this.homeIndex == 0,
          preload: false,
          onFirstLoaded: () => { this.schedulePreload(); this.onReady(); },
          cookie: this.cookie,
          viewerHandle: this.viewerHandle,
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
          viewerHandle: this.viewerHandle,
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
      .onChange((index: number) => {
        this.homeIndex = index;
        this.displayIndex = index;
        if (this.tabBarW > 0) this.indicatorX = this.tabLeft(index);
      })
      .onAnimationStart((index: number, targetIndex: number, event: SwiperAnimationEvent) => {
        this.displayIndex = targetIndex;
        this.animateIndicatorTo(targetIndex, 280);
      })
      .onGestureSwipe((index: number, event: SwiperAnimationEvent) => {
        this.updateSwipeIndicator(index, event.currentOffset);
      })
      .onAnimationEnd((index: number, event: SwiperAnimationEvent) => {
        this.homeIndex = index;
        this.displayIndex = index;
        this.indicatorX = this.tabLeft(index);
      })
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
