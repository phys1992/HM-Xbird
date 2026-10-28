import { TweetItem } from '../model/TweetItem';
import { XApi } from '../api/XApi';
import { TweetCard } from './TweetCard';

@Component
export struct ProfileTabPage {
  cookie: string = '';
  handle: string = '';
  tab: number = 0;
  bottomInset: number = 76;
  @Prop @Watch('onActiveChanged') active: boolean = false;
  onReply: (item: TweetItem) => void = () => {};
  onQuote: (item: TweetItem) => void = () => {};
  onOpen: (item: TweetItem) => void = () => {};
  onPlay: (item: TweetItem, startTime: number) => void = () => {};
  onImage: (url: string) => void = () => {};
  onOpenQuoted: (id: string) => void = () => {};
  onOpenUser: (handle: string) => void = () => {};
  @State tweets: TweetItem[] = [];
  @State loading: boolean = false;
  @State refreshing: boolean = false;
  @State error: string = '';
  @State cursor: string = '';
  private loadedHandle: string = '';

  aboutToAppear(): void {
    if (this.active) this.load(false);
  }

  onActiveChanged(): void {
    if (this.active && this.loadedHandle != this.handle) this.load(false);
  }

  private query(): string {
    if (this.tab == 1) return `from:${this.handle} filter:replies`;
    if (this.tab == 2) return `from:${this.handle} filter:nativeretweets`;
    return `from:${this.handle}`;
  }

  private async load(more: boolean): Promise<void> {
    if (this.loading) return;
    if (more && this.cursor.length == 0) return;
    this.loading = true;
    this.error = '';
    try {
      const page = await XApi.search(this.cookie, this.query(), more ? this.cursor : '', 'Latest');
      this.tweets = more ? this.tweets.concat(page.tweets) : page.tweets;
      this.cursor = page.cursor;
      this.loadedHandle = this.handle;
    } catch (e) {
      this.error = `${e}`;
      if (!more) this.tweets = [];
    } finally {
      this.loading = false;
    }
  }

  private async refresh(): Promise<void> {
    this.refreshing = true;
    try {
      await this.load(false);
    } finally {
      this.refreshing = false;
    }
  }

  build() {
    Column() {
      if (this.loading && this.tweets.length == 0) {
        Column() { LoadingProgress().width(28).height(28) }
          .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else if (this.error.length > 0 && this.tweets.length == 0) {
        Column() {
          Text(this.error).fontSize(13).fontColor('#F4212E').width('100%').textAlign(TextAlign.Center).padding(16)
          Button('重试').onClick(() => this.load(false))
        }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else {
        Refresh({ refreshing: this.refreshing }) {
          List() {
            if (this.tweets.length == 0) {
              ListItem() {
                Text('暂无内容').fontSize(13).fontColor($r('app.color.text_secondary'))
                  .width('100%').textAlign(TextAlign.Center).padding(28)
              }
            } else {
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
                }
              }, (item: TweetItem) => item.id)
            }
          }
          .width('100%').height('100%')
          .contentEndOffset(this.bottomInset)
          .onReachEnd(() => this.load(true))
        }
        .onRefreshing(() => { this.refresh(); })
        .layoutWeight(1).width('100%')
      }
    }
    .width('100%').height('100%').backgroundColor($r('app.color.bg'))
  }
}
