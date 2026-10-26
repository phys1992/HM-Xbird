import { TweetItem } from '../model/TweetItem';
import { XApi, HomeResult } from '../api/XApi';
import { TweetCard } from './TweetCard';

@Component
export struct HomeFeed {
  cookie: string = '';
  onReply: (item: TweetItem) => void = () => {};
  onQuote: (item: TweetItem) => void = () => {};
  onOpen: (item: TweetItem) => void = () => {};
  @State tab: number = 0;
  @State tweets: TweetItem[] = [];
  @State loading: boolean = false;
  @State error: string = '';
  @State notice: string = '';

  aboutToAppear(): void {
    this.load(false);
  }

  private async load(more: boolean): Promise<void> {
    if (this.loading) return;
    this.loading = true;
    this.error = '';
    try {
      let page: HomeResult;
      if (this.tab == 0) {
        try {
          page = await XApi.forYou(this.cookie, '');
        } catch (e) {
          this.notice = '“为你推荐”接口不可用，已回退到关注时间线';
          page = await XApi.homeLatest(this.cookie, '');
        }
      } else {
        page = await XApi.homeLatest(this.cookie, '');
      }
      this.tweets = more ? this.tweets.concat(page.tweets) : page.tweets;
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
        List() {
          ForEach(this.tweets, (item: TweetItem) => {
            ListItem() {
              Column() {
                TweetCard({
                  item: item,
                  cookie: this.cookie,
                  onReply: (value: TweetItem) => this.onReply(value),
                  onQuote: (value: TweetItem) => this.onQuote(value),
                  onOpen: (value: TweetItem) => this.onOpen(value)
                })
                Divider().color('#EFF3F4')
              }
            }
          }, (item: TweetItem) => item.id)
        }
        .layoutWeight(1).width('100%')
        .onReachEnd(() => this.load(true))
      }
    }
    .width('100%').height('100%')
  }
}
