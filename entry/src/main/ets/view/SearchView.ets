import { TweetItem } from '../model/TweetItem';
import { TrendItem } from '../model/TrendItem';
import { XApi } from '../api/XApi';
import { SearchResultPage } from './SearchResultPage';

@Component
export struct SearchView {
  bottomInset: number = 76;
  @Prop @Watch('onFocusRequested') focusTick: number = 0;
  @Prop @Watch('onTrendsHomeRequested') trendsHomeTick: number = 0;
  cookie: string = '';
  onReply: (item: TweetItem) => void = () => {};
  onQuote: (item: TweetItem) => void = () => {};
  onOpen: (item: TweetItem) => void = () => {};
  onPlay: (item: TweetItem, startTime: number) => void = () => {};
  onImage: (url: string) => void = () => {};
  onOpenQuoted: (id: string) => void = () => {};
  onOpenUser: (handle: string) => void = () => {};
  @State query: string = '';
  @State activeTab: number = 0;
  @State searched: boolean = false;
  @State searchTick: number = 0;
  @State trends: TrendItem[] = [];
  @State trendsLoading: boolean = false;
  @State trendsError: string = '';
  @State refreshing: boolean = false;
  private controller: SwiperController = new SwiperController();
  private trendsScroller: Scroller = new Scroller();
  private trendsFirst: number = 0;

  aboutToAppear(): void {
    this.loadTrends();
  }

  onFocusRequested(): void {
    focusControl.requestFocus('xh_search_input');
  }

  onTrendsHomeRequested(): void {
    this.searched = false;
    this.activeTab = 0;
    this.controller.changeIndex(0, false);
    if (this.trends.length == 0) this.loadTrends();
  }

  private async loadTrends(): Promise<void> {
    if (this.trendsLoading) return;
    this.trendsLoading = true;
    this.trendsError = '';
    try {
      let list = await XApi.trends(this.cookie, 1);
      if (list.length == 0) list = await XApi.trends(this.cookie, 23424977);
      this.trends = list;
    } catch (e) {
      try {
        this.trends = await XApi.trends(this.cookie, 23424977);
      } catch (e2) {
        this.trendsError = `${e2}`;
      }
    } finally {
      this.trendsLoading = false;
    }
  }

  private async refreshTrends(): Promise<void> {
    this.refreshing = true;
    try {
      let fresh = await XApi.trends(this.cookie, 1);
      if (fresh.length == 0) fresh = await XApi.trends(this.cookie, 23424977);
      const existing: string[] = this.trends.map((t: TrendItem) => t.name);
      const added = fresh.filter((t: TrendItem) => existing.indexOf(t.name) < 0);
      if (added.length > 0) {
        const anchor = this.trendsFirst;
        this.trends = added.concat(this.trends);
        setTimeout(() => {
          this.trendsScroller.scrollToIndex(anchor + added.length, false, ScrollAlign.START);
        }, 0);
      }
    } catch (e) {
      this.trendsError = `${e}`;
    } finally {
      this.refreshing = false;
    }
  }

  private searchTrend(item: TrendItem): void {
    let q = item.query.length > 0 ? item.query : item.name;
    if (q.indexOf('%') >= 0) {
      try { q = decodeURIComponent(q); } catch (e) {}
    }
    this.query = q;
    this.activeTab = 0;
    this.controller.changeIndex(0, true);
    this.runSearch();
  }

  private runSearch(): void {
    const q = this.query.trim();
    if (q.length == 0) return;
    this.query = q;
    this.searched = true;
    this.searchTick += 1;
  }

  private switchTab(index: number): void {
    if (this.activeTab == index) return;
    this.activeTab = index;
    this.controller.changeIndex(index, true);
  }

  @Builder
  tabItem(index: number, label: string) {
    Column() {
      Text(label).fontSize(15)
        .fontWeight(this.activeTab == index ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.activeTab == index ? $r('app.color.text_primary') : $r('app.color.text_secondary'))
      Rect({ width: 36, height: 3 })
        .fill(this.activeTab == index ? '#1D9BF0' : '#00000000')
        .radius(2).margin({ top: 4 })
    }
    .layoutWeight(1).padding({ top: 4, bottom: 2 })
    .onClick(() => this.switchTab(index))
  }

  @Builder
  trendRow(item: TrendItem, index: number) {
    Column() {
      Row() {
        Text(`${index + 1}`).fontSize(13).fontColor($r('app.color.text_secondary')).width(28)
        Column() {
          Text(item.name).fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          if (item.volume > 0) {
            Text(`${item.volume} 帖子`).fontSize(11).fontColor($r('app.color.text_secondary')).margin({ top: 2 })
          }
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      }
      .width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })
      .onClick(() => this.searchTrend(item))
      Divider().strokeWidth(1).color($r('app.color.divider'))
    }.width('100%')
  }

  build() {
    Column() {
      Row() {
        TextInput({ placeholder: '搜索 X', text: this.query })
          .id('xh_search_input')
          .layoutWeight(1).height(40).borderRadius(20)
          .backgroundColor($r('app.color.surface_secondary'))
          .fontColor($r('app.color.text_primary'))
          .placeholderColor($r('app.color.text_secondary'))
          .onChange((value: string) => this.query = value)
          .onSubmit(() => this.runSearch())
        Button('搜索').height(36).margin({ left: 8 })
          .onClick(() => this.runSearch())
      }.padding(12)

      if (this.searched) {
        Row() {
          this.tabItem(0, '热门')
          this.tabItem(1, '最新')
          this.tabItem(2, '用户')
        }.width('100%').padding({ left: 8, right: 8 })

        Swiper(this.controller) {
          SearchResultPage({
            tab: 0, query: this.query, searchTick: this.searchTick,
            active: this.activeTab == 0, cookie: this.cookie, bottomInset: this.bottomInset,
            onReply: (item: TweetItem) => this.onReply(item),
            onQuote: (item: TweetItem) => this.onQuote(item),
            onOpen: (item: TweetItem) => this.onOpen(item),
            onPlay: (item: TweetItem, time: number) => this.onPlay(item, time),
            onImage: (url: string) => this.onImage(url),
            onOpenQuoted: (id: string) => this.onOpenQuoted(id),
            onOpenUser: (handle: string) => this.onOpenUser(handle)
          })
          SearchResultPage({
            tab: 1, query: this.query, searchTick: this.searchTick,
            active: this.activeTab == 1, cookie: this.cookie, bottomInset: this.bottomInset,
            onReply: (item: TweetItem) => this.onReply(item),
            onQuote: (item: TweetItem) => this.onQuote(item),
            onOpen: (item: TweetItem) => this.onOpen(item),
            onPlay: (item: TweetItem, time: number) => this.onPlay(item, time),
            onImage: (url: string) => this.onImage(url),
            onOpenQuoted: (id: string) => this.onOpenQuoted(id),
            onOpenUser: (handle: string) => this.onOpenUser(handle)
          })
          SearchResultPage({
            tab: 2, query: this.query, searchTick: this.searchTick,
            active: this.activeTab == 2, cookie: this.cookie, bottomInset: this.bottomInset,
            onReply: (item: TweetItem) => this.onReply(item),
            onQuote: (item: TweetItem) => this.onQuote(item),
            onOpen: (item: TweetItem) => this.onOpen(item),
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
      } else {
        Column() {
          Row() {
            Text('全球趋势').fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary')).layoutWeight(1)
            if (this.trendsLoading) LoadingProgress().width(16).height(16)
          }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 6 })

          if (this.trendsError.length > 0) {
            Text(`趋势加载失败：${this.trendsError}`).fontSize(12).fontColor('#F4212E')
              .width('100%').textAlign(TextAlign.Center).padding(12)
            Button('重试').onClick(() => this.loadTrends())
          } else {
            Refresh({ refreshing: this.refreshing }) {
              List({ scroller: this.trendsScroller }) {
                ForEach(this.trends, (item: TrendItem, index: number) => {
                  ListItem() { this.trendRow(item, index) }
                }, (item: TrendItem) => item.name)
              }
              .width('100%').height('100%')
              .contentEndOffset(this.bottomInset)
              .onScrollIndex((start: number) => { this.trendsFirst = start; })
            }
            .onRefreshing(() => { this.refreshTrends(); })
            .layoutWeight(1).width('100%')
          }
        }.layoutWeight(1).width('100%').alignItems(HorizontalAlign.Start)
      }
    }.width('100%').height('100%')
  }
}
