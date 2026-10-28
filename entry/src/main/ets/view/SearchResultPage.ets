import { TweetItem } from '../model/TweetItem';
import { UserProfile } from '../model/UserProfile';
import { XApi } from '../api/XApi';
import { TweetCard } from './TweetCard';

@Component
export struct SearchResultPage {
  tab: number = 0;
  @Prop @Watch('onQueryChanged') query: string = '';
  @Prop @Watch('onSearchTickChanged') searchTick: number = 0;
  @Prop @Watch('onActiveChanged') active: boolean = false;
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
  private currentQuery: string = '';
  private scroller: Scroller = new Scroller();
  private firstIndex: number = 0;

  aboutToAppear(): void {
    if (this.active && this.query.trim().length > 0) this.load();
  }

  onQueryChanged(): void {
    this.loadedQuery = '';
    this.clear();
    if (this.active && this.query.trim().length > 0) this.load();
  }

  onSearchTickChanged(): void {
    this.loadedQuery = '';
    this.clear();
    if (this.active && this.query.trim().length > 0) this.load();
  }

  onActiveChanged(): void {
    if (this.active && this.query.trim().length > 0 && this.loadedQuery != this.query) {
      this.load();
    }
  }

  private clear(): void {
    this.tweets = [];
    this.users = [];
    this.cursor = '';
    this.error = '';
  }

  private async load(): Promise<void> {
    if (this.loading) return;
    const q = this.query.trim();
    if (q.length == 0) return;
    this.loading = true;
    this.error = '';
    try {
      if (this.tab == 2) {
        const page = await XApi.searchUsers(this.cookie, q, '');
        this.users = page.users;
        this.cursor = page.cursor;
      } else {
        const product = this.tab == 1 ? 'Latest' : 'Top';
        const page = await XApi.search(this.cookie, q, '', product);
        this.tweets = page.tweets;
        this.cursor = page.cursor;
      }
      this.loadedQuery = q;
      this.scroller.scrollToIndex(0, false);
    } catch (e) {
      this.error = `${e}`;
    } finally {
      this.loading = false;
    }
  }

  private async refreshPage(): Promise<void> {
    this.refreshing = true;
    const q = this.query.trim();
    try {
      if (this.tab == 2) {
        const page = await XApi.searchUsers(this.cookie, q, '');
        const existing: string[] = this.users.map((u: UserProfile) => u.handle);
        const added = page.users.filter((u: UserProfile) => existing.indexOf(u.handle) < 0);
        if (added.length > 0) {
          const anchor = this.firstIndex;
          this.users = added.concat(this.users);
          setTimeout(() => {
            this.scroller.scrollToIndex(anchor + added.length, false, ScrollAlign.START);
          }, 0);
        }
      } else {
        const product = this.tab == 1 ? 'Latest' : 'Top';
        const page = await XApi.search(this.cookie, q, '', product);
        const existing: string[] = this.tweets.map((t: TweetItem) => t.id);
        const added = page.tweets.filter((t: TweetItem) => existing.indexOf(t.id) < 0);
        if (added.length > 0) {
          const anchor = this.firstIndex;
          this.tweets = added.concat(this.tweets);
          setTimeout(() => {
            this.scroller.scrollToIndex(anchor + added.length, false, ScrollAlign.START);
          }, 0);
        }
      }
    } catch (e) {
      this.error = `${e}`;
    } finally {
      this.refreshing = false;
    }
  }

  private async loadMore(): Promise<void> {
    if (this.loading || this.cursor.length == 0) return;
    const q = this.query.trim();
    try {
      if (this.tab == 2) {
        const page = await XApi.searchUsers(this.cookie, q, this.cursor);
        this.users = this.users.concat(page.users);
        this.cursor = page.cursor;
      } else {
        const product = this.tab == 1 ? 'Latest' : 'Top';
        const page = await XApi.search(this.cookie, q, this.cursor, product);
        if (page.tweets.length > 0) this.tweets = this.tweets.concat(page.tweets);
        this.cursor = page.cursor;
      }
    } catch (e) {}
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

  build() {
    Column() {
      if (this.loading && this.tweets.length == 0 && this.users.length == 0) {
        Column() { LoadingProgress().width(32).height(32) }
          .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else if (this.error.length > 0 && this.tweets.length == 0 && this.users.length == 0) {
        Column() {
          Text(this.error).fontSize(13).fontColor('#F4212E')
            .width('100%').textAlign(TextAlign.Center).padding(16)
          Button('重试').onClick(() => this.load())
        }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else if (this.tab == 2) {
        Refresh({ refreshing: this.refreshing }) {
          List({ scroller: this.scroller }) {
            ForEach(this.users, (item: UserProfile) => {
              ListItem() { this.userRow(item) }
            }, (item: UserProfile) => item.handle)
          }
          .width('100%').height('100%')
          .contentEndOffset(this.bottomInset)
          .onScrollIndex((start: number) => { this.firstIndex = start; })
          .onReachEnd(() => this.loadMore())
        }
        .onRefreshing(() => { this.refreshPage(); })
        .layoutWeight(1).width('100%')
      } else {
        Refresh({ refreshing: this.refreshing }) {
          List({ scroller: this.scroller }) {
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
          }
          .width('100%').height('100%')
          .contentEndOffset(this.bottomInset)
          .onScrollIndex((start: number) => { this.firstIndex = start; })
          .onReachEnd(() => this.loadMore())
        }
        .onRefreshing(() => { this.refreshPage(); })
        .layoutWeight(1).width('100%')
      }
    }.width('100%').height('100%')
  }
}
