import { TweetItem } from '../model/TweetItem';
import { XApi, HomeResult } from '../api/XApi';
import { TweetCard } from './TweetCard';

@Component
export struct HomeFeed {
  private static scrollOffset: number = 0;
  cookie: string = '';
  onReply: (item: TweetItem) => void = () => {};
  onQuote: (item: TweetItem) => void = () => {};
  onOpen: (item: TweetItem) => void = () => {};
  onPrefetch: (item: TweetItem) => void = () => {};
  onPlay: (item: TweetItem) => void = () => {};
  onImage: (url: string) => void = () => {};
  onOpenQuoted: (id: string) => void = () => {};
  onOpenUser: (handle: string) => void = () => {};
  @State tab: number = 0;
  @State tweets: TweetItem[] = [];
  @State loading: boolean = false;
  @State error: string = '';
  @State notice: string = '';
  @State cursor: string = '';
  @State refreshing: boolean = false;
  private listScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.load(false);
  }

  private async load(more: boolean): Promise<void> {
    if (this.loading) return;
    this.loading = true;
    this.error = '';
    try {
      let page: HomeResult;
      const cursor = more ? this.cursor : '';
      if (this.tab == 0) {
        try {
          page = await XApi.forYou(this.cookie, cursor);
        } catch (e) {
          this.notice = '“为你推荐”接口不可用，已回退到关注时间线';
          page = await XApi.homeLatest(this.cookie, cursor);
        }
      } else {
        page = await XApi.homeLatest(this.cookie, cursor);
      }
      this.tweets = more ? this.tweets.concat(page.tweets) : page.tweets;
      this.cursor = page.cursor;
      if (!more) {
        const savedOffset = AppStorage.get<number>('tuichuang_home_offset') ?? 0;
        HomeFeed.scrollOffset = savedOffset;
        if (savedOffset > 0) {
          setTimeout(() => {
            this.listScroller.scrollTo({ xOffset: 0, yOffset: savedOffset, animation: false });
          }, 120);
        }
        for (let i = 0; i < this.tweets.length && i < 3; i++) {
          this.onPrefetch(this.tweets[i]);
        }
      }
    } catch (e) {
      this.error = `${e}`;
    } finally {
      this.loading = false;
    }
  }

  private switchTab(index: number): void {
    if (this.tab == index) return;
    this.tab = index;
    this.tweets = [];
    this.cursor = '';
    this.notice = '';
    this.load(false);
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text('为你推荐').fontSize(15)
            .fontWeight(this.tab == 0 ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.tab == 0 ? '#0F1419' : '#536471')
          if (this.tab == 0) {
            Rect({ width: 44, height: 3 }).fill('#1D9BF0').radius(2).margin({ top: 4 })
          } else {
            Rect({ width: 44, height: 3 }).fill('#00000000').margin({ top: 4 })
          }
        }.layoutWeight(1).onClick(() => this.switchTab(0))

        Column() {
          Text('正在关注').fontSize(15)
            .fontWeight(this.tab == 1 ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.tab == 1 ? '#0F1419' : '#536471')
          if (this.tab == 1) {
            Rect({ width: 44, height: 3 }).fill('#1D9BF0').radius(2).margin({ top: 4 })
          } else {
            Rect({ width: 44, height: 3 }).fill('#00000000').margin({ top: 4 })
          }
        }.layoutWeight(1).onClick(() => this.switchTab(1))
      }.width('100%').padding({ top: 4 })

      if (this.notice.length > 0) {
        Text(this.notice).fontSize(11).fontColor('#F59E0B')
          .width('100%').padding({ left: 12, top: 6 })
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
          Text('暂无内容').fontSize(14).fontColor('#536471')
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
                  onPlay: (value: TweetItem) => this.onPlay(value),
                  onImage: (url: string) => this.onImage(url),
                  onOpenQuoted: (id: string) => this.onOpenQuoted(id),
                  onOpenUser: (handle: string) => this.onOpenUser(handle)
                })
                Divider().color('#EFF3F4')
              }
            }
          }, (item: TweetItem) => item.id)

          ListItem() {
            Row() {
              LoadingProgress().width(18).height(18)
              Text('加载更多…').fontSize(12).fontColor('#536471').margin({ left: 6 })
            }.width('100%').justifyContent(FlexAlign.Center).padding(12)
          }
        }
        .layoutWeight(1).width('100%')
        .onScroll((offset: number) => {
          HomeFeed.scrollOffset = Math.max(0, HomeFeed.scrollOffset + offset);
          AppStorage.setOrCreate('tuichuang_home_offset', HomeFeed.scrollOffset);
        })
        .onReachEnd(() => {
          if (!this.loading && this.cursor.length > 0) this.load(true);
        })
        }
        .onRefreshing(() => {
          this.refreshing = true;
          this.cursor = '';
          this.load(false).then(() => { this.refreshing = false; });
        })
        .layoutWeight(1)
      }
    }
    .width('100%').height('100%')
  }
}
