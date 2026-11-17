import { TweetItem } from '../model/TweetItem';
import { UserProfile } from '../model/UserProfile';
import { XApi } from '../api/XApi';
import { TweetCard } from './TweetCard';
import { VideoAutoplay } from '../model/VideoAutoplay';
import { I18n } from '../model/I18n';
import { SearchSnapshotStore, SearchPageSnapshot } from '../model/SearchSnapshotStore';

@Component
export struct SearchResultPage {
  @StorageProp('clientLang') clientLanguage: string = 'zh';
  private tr(value: string): string {
    return this.clientLanguage.length >= 0 ? I18n.t(value) : I18n.t(value);
  }

  tab: number = 0;
  @Prop query: string = '';
  @Prop @Watch('onSearchTickChanged') searchTick: number = 0;
  @Prop @Watch('onActiveChanged') active: boolean = false;
  @Prop @Watch('onPageActiveChanged') pageActive: boolean = false;
  @Prop @Watch('onActivationTickChanged') activationTick: number = 0;
  @Prop @Watch('onScrollTopRequested') scrollTopTick: number = 0;
  cookie: string = '';
  bottomInset: number = 76;
  onReply: (item: TweetItem) => void = () => {};
  onQuote: (item: TweetItem) => void = () => {};
  onOpen: (item: TweetItem) => void = () => {};
  onPlay: (item: TweetItem, startTime: number) => void = () => {};
  onImage: (url: string) => void = () => {};
  onOpenQuoted: (id: string) => void = () => {};
  onOpenUser: (handle: string) => void = () => {};
  @State tweets: TweetItem[] = [];
  @State users: UserProfile[] = [];
  @State loading: boolean = false;
  @State refreshing: boolean = false;
  @State error: string = '';
  @State cursor: string = '';
  private loadedQuery: string = '';
  private fetchedAt: number = 0;
  private scrollOffset: number = 0;
  private firstIndex: number = 0;
  private restoring: boolean = false;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    if (this.query.trim().length > 0 && (this.active || this.pageActive)) this.beginQuery();
  }

  aboutToDisappear(): void {
    this.saveSnapshot();
  }

  onSearchTickChanged(): void {
    // All three result pages are mounted, so the initial search starts their
    // first-page requests together.
    this.beginQuery();
  }

  onActiveChanged(): void {
    if (this.active) this.checkTtl();
    else this.saveSnapshot();
  }

  onPageActiveChanged(): void {
    if (this.pageActive && this.active) this.checkTtl();
    else this.saveSnapshot();
  }

  onActivationTickChanged(): void {
    if (this.pageActive && this.active) this.checkTtl();
  }

  onScrollTopRequested(): void {
    if (!this.active) return;
    this.restoring = true;
    this.scrollOffset = 0;
    try { this.scroller.scrollToIndex(0, true, ScrollAlign.START); } catch (e) {}
    setTimeout(() => { this.restoring = false; }, 350);
  }

  private hasData(): boolean {
    return this.tweets.length > 0 || this.users.length > 0;
  }

  private saveSnapshot(): void {
    if (this.loadedQuery.trim().length == 0 || this.fetchedAt <= 0) return;
    SearchSnapshotStore.put(this.loadedQuery, this.tab, this.tweets, this.users,
      this.cursor, this.fetchedAt, this.scrollOffset);
  }

  private applySnapshot(snapshot: SearchPageSnapshot, query: string): void {
    this.loadedQuery = query;
    this.tweets = snapshot.tweets;
    this.users = snapshot.users;
    this.cursor = snapshot.cursor;
    this.fetchedAt = snapshot.fetchedAt;
    this.scrollOffset = snapshot.scrollOffset;
    if (this.scrollOffset > 0) {
      this.restoring = true;
      setTimeout(() => {
        try { this.scroller.scrollTo({ xOffset: 0, yOffset: this.scrollOffset, animation: false }); } catch (e) {}
        this.restoring = false;
      }, 100);
    }
  }

  private beginQuery(): void {
    const q = this.query.trim();
    if (q.length == 0) {
      this.saveSnapshot();
      this.loadedQuery = '';
      this.tweets = [];
      this.users = [];
      this.cursor = '';
      this.fetchedAt = 0;
      this.error = '';
      return;
    }
    if (q == this.loadedQuery) {
      this.checkTtl();
      return;
    }
    this.saveSnapshot();
    const snapshot = SearchSnapshotStore.get(q, this.tab);
    if (snapshot != null) {
      this.applySnapshot(snapshot, q);
      if (SearchSnapshotStore.isStale(snapshot, this.tab)) this.refreshPage();
      return;
    }
    this.tweets = [];
    this.users = [];
    this.cursor = '';
    this.fetchedAt = 0;
    this.error = '';
    this.scrollOffset = 0;
    this.load(false);
  }

  private checkTtl(): void {
    const q = this.query.trim();
    if (q.length == 0) return;
    if (q != this.loadedQuery) {
      this.beginQuery();
      return;
    }
    if (!this.hasData()) {
      if (!this.loading) this.load(false);
      return;
    }
    if (Date.now() - this.fetchedAt >= SearchSnapshotStore.ttlMs(this.tab)) {
      this.refreshPage();
    }
  }

  private async load(more: boolean): Promise<void> {
    if (this.loading) return;
    const q = this.query.trim();
    if (q.length == 0) return;
    this.loading = true;
    this.error = '';
    try {
      if (this.tab == 2) {
        const page = await XApi.searchUsers(this.cookie, q, more ? this.cursor : '', 10);
        this.users = more ? this.users.concat(page.users) : page.users;
        this.cursor = page.cursor;
      } else {
        const product = this.tab == 1 ? 'Latest' : 'Top';
        const page = await XApi.search(this.cookie, q, more ? this.cursor : '', product, 10);
        this.tweets = more ? this.tweets.concat(page.tweets) : page.tweets;
        this.cursor = page.cursor;
      }
      this.loadedQuery = q;
      this.fetchedAt = Date.now();
      if (!more) {
        this.scrollOffset = 0;
        this.firstIndex = 0;
        try { this.scroller.scrollToIndex(0, false); } catch (e) {}
      }
      this.saveSnapshot();
    } catch (e) {
      this.error = `${e}`;
    } finally {
      this.loading = false;
    }
  }

  private async refreshPage(): Promise<void> {
    if (this.loading || this.refreshing) return;
    const q = this.query.trim();
    if (q.length == 0) return;
    this.refreshing = true;
    try {
      if (this.tab == 2) {
        const page = await XApi.searchUsers(this.cookie, q, '', 10);
        const existing: string[] = this.users.map((u: UserProfile) => u.handle);
        const fresh = page.users.filter((u: UserProfile) => existing.indexOf(u.handle) < 0);
        if (fresh.length > 0) {
          const anchor = this.firstIndex;
          this.restoring = true;
          this.users = fresh.concat(this.users);
          setTimeout(() => {
            try { this.scroller.scrollToIndex(anchor + fresh.length, false, ScrollAlign.START); } catch (e) {}
            this.restoring = false;
          }, 0);
        }
        if (this.cursor.length == 0) this.cursor = page.cursor;
      } else {
        const product = this.tab == 1 ? 'Latest' : 'Top';
        const page = await XApi.search(this.cookie, q, '', product, 10);
        const existing: string[] = this.tweets.map((t: TweetItem) => t.id);
        const fresh = page.tweets.filter((t: TweetItem) => existing.indexOf(t.id) < 0);
        if (fresh.length > 0) {
          const anchor = this.firstIndex;
          this.restoring = true;
          this.tweets = fresh.concat(this.tweets);
          setTimeout(() => {
            try { this.scroller.scrollToIndex(anchor + fresh.length, false, ScrollAlign.START); } catch (e) {}
            this.restoring = false;
          }, 0);
        }
        if (this.cursor.length == 0) this.cursor = page.cursor;
      }
      this.loadedQuery = q;
      this.fetchedAt = Date.now();
      this.saveSnapshot();
    } catch (e) {
      this.error = `${e}`;
    } finally {
      this.refreshing = false;
    }
  }

  private async loadMore(): Promise<void> {
    if (this.loading || this.refreshing || this.cursor.length == 0) return;
    await this.load(true);
  }

  @Builder
  userRow(item: UserProfile) {
    Column() {
      Row() {
        if (item.avatarUrl.length > 0) {
          Image(item.avatarUrl).width(44).height(44).borderRadius(22)
        } else {
          Circle({ width: 44, height: 44 }).fill('#E8F3FD')
        }
        Column() {
          Text(item.name).fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary')).maxLines(1)
          Text(`@${item.handle}`).fontSize(12).fontColor($r('app.color.text_secondary')).margin({ top: 2 })
          if (item.description.length > 0) {
            Text(item.description).fontSize(13).lineHeight(18).fontColor($r('app.color.text_primary')).maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 4 })
          }
        }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 10 })
      }
      .width('100%').padding(14)
      .onClick(() => this.onOpenUser(item.handle))
      Divider().strokeWidth(1).color($r('app.color.divider'))
    }.width('100%')
  }

  @Builder
  emptySearch() {
    Column() {
      Text(this.tr('输入关键词开始搜索')).fontSize(14).fontColor($r('app.color.text_secondary'))
    }.width('100%').height('100%').justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      if (this.query.trim().length == 0) {
        this.emptySearch()
      } else if (this.loading && this.tweets.length == 0 && this.users.length == 0) {
        Column() { LoadingProgress().width(32).height(32) }
          .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else if (this.error.length > 0 && this.tweets.length == 0 && this.users.length == 0) {
        Column() {
          Text(this.error).fontSize(13).fontColor('#F4212E')
            .width('100%').textAlign(TextAlign.Center).padding(16)
          Button(this.tr('重试')).onClick(() => this.load(false))
        }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else if (this.tab == 2) {
        Refresh({ refreshing: this.refreshing }) {
          List({ scroller: this.scroller }) {
            ForEach(this.users, (item: UserProfile) => {
              ListItem() { this.userRow(item) }
            }, (item: UserProfile) => item.handle)
            if (this.cursor.length > 0) {
              ListItem() {
                Row() {
                  LoadingProgress().width(18).height(18)
                  Text(this.tr('加载更多…')).fontSize(12)
                    .fontColor($r('app.color.text_secondary')).margin({ left: 8 })
                }.width('100%').height(44).justifyContent(FlexAlign.Center)
              }.onAppear(() => this.loadMore())
            }
          }
          .width('100%').height('100%')
          .contentEndOffset(this.bottomInset)
          .onScrollStart(() => VideoAutoplay.onScrollStart())
          .onScrollStop(() => VideoAutoplay.onScrollStop())
          .onScrollIndex((start: number) => { this.firstIndex = start; })
          .onScroll((offset: number) => {
            if (!this.restoring) this.scrollOffset = Math.max(0, this.scrollOffset + offset);
          })
          .onReachEnd(() => this.loadMore())
        }
        .onRefreshing(() => { this.refreshPage(); })
        .layoutWeight(1).width('100%')
      } else {
        Refresh({ refreshing: this.refreshing }) {
          List({ scroller: this.scroller }) {
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
            if (this.cursor.length > 0) {
              ListItem() {
                Row() {
                  LoadingProgress().width(18).height(18)
                  Text(this.tr('加载更多…')).fontSize(12)
                    .fontColor($r('app.color.text_secondary')).margin({ left: 8 })
                }.width('100%').height(44).justifyContent(FlexAlign.Center)
              }.onAppear(() => this.loadMore())
            }
          }
          .width('100%').height('100%')
          .contentEndOffset(this.bottomInset)
          .onScrollStart(() => VideoAutoplay.onScrollStart())
          .onScrollStop(() => VideoAutoplay.onScrollStop())
          .onScrollIndex((start: number) => { this.firstIndex = start; })
          .onScroll((offset: number) => {
            if (!this.restoring) this.scrollOffset = Math.max(0, this.scrollOffset + offset);
          })
          .onReachEnd(() => this.loadMore())
        }
        .onRefreshing(() => { this.refreshPage(); })
        .layoutWeight(1).width('100%')
      }
    }.width('100%').height('100%')
  }
}
