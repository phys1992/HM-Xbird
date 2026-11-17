import { TweetItem } from '../model/TweetItem';
import { TrendItem } from '../model/TrendItem';
import { XApi } from '../api/XApi';
import { SearchResultPage } from './SearchResultPage';
import { I18n } from '../model/I18n';
import { SearchHistoryStore, SearchHistoryEntry } from '../model/SearchHistoryStore';
import { SearchSnapshotStore } from '../model/SearchSnapshotStore';
import { common } from '@kit.AbilityKit';

const TRENDS_TTL_MS: number = 5 * 60 * 60 * 1000;

@Component
export struct SearchView {
  @StorageProp('clientLang') clientLanguage: string = 'zh';
  private tr(value: string): string {
    return this.clientLanguage.length >= 0 ? I18n.t(value) : I18n.t(value);
  }

  bottomInset: number = 76;
  @Prop @Watch('onFocusRequested') focusTick: number = 0;
  @Prop @Watch('onTrendsHomeRequested') trendsHomeTick: number = 0;
  @Prop @Watch('onPageActiveChanged') active: boolean = false;
  @State resultScrollTopTick: number = 0;
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
  @State displayIndex: number = 0;
  @State indicatorX: number = 0;
  @State tabBarW: number = 0;
  @State searchTick: number = 0;
  @State activationTick: number = 0;
  @State trends: TrendItem[] = [];
  @State trendsLoading: boolean = false;
  @State trendsError: string = '';
  @State refreshing: boolean = false;
  @State history: SearchHistoryEntry[] = [];
  @State showHistory: boolean = false;
  private trendsFetchedAt: number = 0;
  private controller: SwiperController = new SwiperController();
  private readonly indicatorW: number = 36;
  private trendsScroller: Scroller = new Scroller();
  private trendsFirst: number = 0;

  aboutToAppear(): void {
    const context = getContext(this) as common.UIAbilityContext;
    SearchSnapshotStore.configure(context);
    this.history = SearchHistoryStore.load(context);
    this.loadTrends();
  }

  onFocusRequested(): void {
    focusControl.requestFocus('xh_search_input');
  }

  onPageActiveChanged(): void {
    if (!this.active) return;
    this.activationTick += 1;
    if (this.activeTab == 0) this.checkTrendsTtl();
  }

  onTrendsHomeRequested(): void {
    if (this.activeTab == 0) {
      try { this.trendsScroller.scrollToIndex(0, true, ScrollAlign.START); } catch (e) {}
      this.checkTrendsTtl();
    } else {
      this.resultScrollTopTick += 1;
    }
  }

  private trendsStale(): boolean {
    return this.trendsFetchedAt <= 0 ||
      Date.now() - this.trendsFetchedAt >= TRENDS_TTL_MS;
  }

  private checkTrendsTtl(): void {
    if (this.trends.length == 0) {
      this.loadTrends();
    } else if (this.trendsStale() && !this.refreshing) {
      this.refreshTrends();
    }
  }

  private async loadTrends(): Promise<void> {
    if (this.trendsLoading) return;
    this.trendsLoading = true;
    this.trendsError = '';
    try {
      let list = await XApi.trends(this.cookie, 1);
      if (list.length == 0) list = await XApi.trends(this.cookie, 23424977);
      this.trends = list;
      this.trendsFetchedAt = Date.now();
    } catch (e) {
      try {
        this.trends = await XApi.trends(this.cookie, 23424977);
        this.trendsFetchedAt = Date.now();
      } catch (e2) {
        this.trendsError = `${e2}`;
      }
    } finally {
      this.trendsLoading = false;
    }
  }

  private async refreshTrends(): Promise<void> {
    if (this.refreshing) return;
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
      this.trendsFetchedAt = Date.now();
      this.trendsError = '';
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
    this.runSearch();
  }

  private runSearch(): void {
    const q = this.query.trim();
    if (q.length == 0) return;
    this.query = q;
    this.switchTab(1);
    this.searchTick += 1;
    this.history = SearchHistoryStore.add(getContext(this) as common.UIAbilityContext, q, 1);
    this.showHistory = false;
  }

  private selectHistory(entry: SearchHistoryEntry): void {
    this.query = entry.query;
    const tab = entry.lastTab >= 1 && entry.lastTab <= 3 ? entry.lastTab : 1;
    this.activeTab = tab;
    this.displayIndex = tab;
    this.showHistory = false;
    this.controller.changeIndex(tab, false);
    this.animateIndicatorTo(tab, 0);
    this.searchTick += 1;
    this.history = SearchHistoryStore.add(getContext(this) as common.UIAbilityContext,
      entry.query, tab);
  }

  private historyTabLabel(tab: number): string {
    if (tab == 2) return this.tr('最新');
    if (tab == 3) return this.tr('用户');
    return this.tr('热门');
  }

  private removeHistory(entry: SearchHistoryEntry): void {
    this.history = SearchHistoryStore.remove(getContext(this) as common.UIAbilityContext,
      entry.query);
  }

  private clearHistory(): void {
    SearchHistoryStore.clear(getContext(this) as common.UIAbilityContext);
    this.history = [];
    this.showHistory = false;
  }

  private tabLeft(index: number): number {
    if (this.tabBarW <= 0) return 0;
    const slot = this.tabBarW / 4;
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
    const slot = this.tabBarW / 4;
    const ratio = Math.min(1, Math.abs(offset) / this.tabBarW);
    let next = index;
    if (offset < 0 && index < 3) next = index + 1;
    else if (offset > 0 && index > 0) next = index - 1;
    const fraction = index + (next - index) * ratio;
    this.indicatorX = fraction * slot + (slot - this.indicatorW) / 2;
    this.displayIndex = ratio > 0.5 ? next : index;
  }

  private switchTab(index: number): void {
    this.displayIndex = index;
    this.activeTab = index;
    this.animateIndicatorTo(index, 280);
    this.controller.changeIndex(index, true);
    if (index > 0 && this.query.trim().length > 0) {
      this.history = SearchHistoryStore.updateTab(getContext(this) as common.UIAbilityContext,
        this.query, index);
    }
    if (index == 0) this.checkTrendsTtl();
  }

  @Builder
  tabItem(index: number, label: string) {
    Column() {
      Text(this.tr(label)).fontSize(15)
        .fontWeight(this.displayIndex == index ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.displayIndex == index ? $r('app.color.text_primary') : $r('app.color.text_secondary'))
    }
    .layoutWeight(1).height(44).justifyContent(FlexAlign.Center)
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
            Text(this.tr(`${item.volume} 帖子`)).fontSize(11).fontColor($r('app.color.text_secondary')).margin({ top: 2 })
          }
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      }
      .width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })
      .onClick(() => this.searchTrend(item))
      Divider().strokeWidth(1).color($r('app.color.divider'))
    }.width('100%')
  }

  @Builder
  trendsPage() {
    Column() {
      if (this.trendsError.length > 0) {
        Text(this.tr(`趋势加载失败：${this.trendsError}`)).fontSize(12).fontColor('#F4212E')
          .width('100%').textAlign(TextAlign.Center).padding(12)
        Button(this.tr('重试')).onClick(() => this.loadTrends())
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
    }.width('100%').height('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  resultPage(tab: number, pageIndex: number) {
    SearchResultPage({
      tab: tab,
      query: this.query,
      searchTick: this.searchTick,
      active: this.activeTab == pageIndex,
      pageActive: this.active,
      activationTick: this.activationTick,
      scrollTopTick: this.resultScrollTopTick,
      cookie: this.cookie,
      bottomInset: this.bottomInset,
      onReply: (item: TweetItem) => this.onReply(item),
      onQuote: (item: TweetItem) => this.onQuote(item),
      onOpen: (item: TweetItem) => this.onOpen(item),
      onPlay: (item: TweetItem, time: number) => this.onPlay(item, time),
      onImage: (url: string) => this.onImage(url),
      onOpenQuoted: (id: string) => this.onOpenQuoted(id),
      onOpenUser: (handle: string) => this.onOpenUser(handle)
    })
  }

  @Builder
  historyPanel() {
    Column() {
      Row() {
        Text(this.tr('最近搜索')).fontSize(13).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_secondary')).layoutWeight(1)
        Text(this.tr('清空全部')).fontSize(12).fontColor($r('app.color.accent'))
          .onClick(() => this.clearHistory())
      }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 6 })
      Scroll() {
        Column() {
          ForEach(this.history, (entry: SearchHistoryEntry) => {
            Row() {
              Text(entry.query).fontSize(15).fontColor($r('app.color.text_primary'))
                .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                .onClick(() => this.selectHistory(entry))
              Text(this.historyTabLabel(entry.lastTab)).fontSize(11)
                .fontColor($r('app.color.text_secondary')).margin({ right: 6 })
              Text(this.tr('×')).fontSize(18).fontColor($r('app.color.text_secondary'))
                .width(32).textAlign(TextAlign.Center)
                .onClick(() => this.removeHistory(entry))
            }.width('100%').height(42).padding({ left: 16, right: 8 })
          }, (entry: SearchHistoryEntry) => entry.query)
        }.width('100%')
      }.height(Math.min(360, this.history.length * 42)).scrollBar(BarState.Off)
    }
    .width('100%')
    .backgroundColor($r('app.color.surface'))
    .borderRadius(16)
    .shadow({ radius: 16, color: '#26000000', offsetY: 6 })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
      Row() {
        TextInput({ placeholder: this.tr('搜索 X'), text: this.query })
          .id('xh_search_input')
          .layoutWeight(1).height(40).borderRadius(20)
          .backgroundColor($r('app.color.surface'))
          .border({ width: 1, color: $r('app.color.divider') })
          .fontColor($r('app.color.text_primary'))
          .placeholderColor($r('app.color.text_secondary'))
          .onChange((value: string) => this.query = value)
          .onFocus(() => {
            this.history = SearchHistoryStore.load(getContext(this) as common.UIAbilityContext);
            this.showHistory = true;
          })
          .onBlur(() => {
            setTimeout(() => { this.showHistory = false; }, 180);
          })
          .onSubmit(() => this.runSearch())
        Button(this.tr('搜索')).height(36).margin({ left: 8 })
          .onClick(() => this.runSearch())
      }.padding(12)

      Stack({ alignContent: Alignment.BottomStart }) {
        Row() {
          this.tabItem(0, '全球趋势')
          this.tabItem(1, '热门')
          this.tabItem(2, '最新')
          this.tabItem(3, '用户')
        }.width('100%').height(44)
        .onAreaChange((oldValue: Area, newValue: Area) => {
          const w = parseFloat(`${newValue.width}`);
          if (!isNaN(w) && w > 0) {
            this.tabBarW = w;
            this.indicatorX = this.tabLeft(this.displayIndex);
          }
        })

        Rect({ width: this.indicatorW, height: 3 })
          .fill('#1D9BF0')
          .radius(2)
          .position({ x: this.indicatorX, y: 41 })
      }.width('100%').height(44)

      Swiper(this.controller) {
        this.trendsPage()
        this.resultPage(0, 1)
        this.resultPage(1, 2)
        this.resultPage(2, 3)
      }
      .index(this.activeTab)
      .onChange((index: number) => {
        this.activeTab = index;
        this.displayIndex = index;
        if (this.tabBarW > 0) this.indicatorX = this.tabLeft(index);
        if (index == 0) this.checkTrendsTtl();
      })
      .onAnimationStart((index: number, targetIndex: number, event: SwiperAnimationEvent) => {
        this.displayIndex = targetIndex;
        this.animateIndicatorTo(targetIndex, 280);
      })
      .onGestureSwipe((index: number, event: SwiperAnimationEvent) => {
        this.updateSwipeIndicator(index, event.currentOffset);
      })
      .onAnimationEnd((index: number, event: SwiperAnimationEvent) => {
        this.activeTab = index;
        this.displayIndex = index;
        this.indicatorX = this.tabLeft(index);
        if (index == 0) this.checkTrendsTtl();
      })
      .indicator(false).loop(false)
      .duration(280).curve(Curve.EaseOut)
      .cachedCount(4)
      .layoutWeight(1).width('100%')
      }
      .width('100%').height('100%')

      if (this.showHistory && this.query.trim().length == 0 && this.history.length > 0) {
        Column() {
          this.historyPanel()
        }
        .width('100%')
        .position({ x: 0, y: 58 })
        .zIndex(20)
      }
    }.width('100%').height('100%')
  }
}
