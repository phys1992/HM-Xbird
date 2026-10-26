import { TweetItem } from '../model/TweetItem';
import { XApi } from '../api/XApi';
import { TweetCard } from './TweetCard';

@Component
export struct SearchView {
  cookie: string = '';
  onReply: (item: TweetItem) => void = () => {};
  onQuote: (item: TweetItem) => void = () => {};
  onOpen: (item: TweetItem) => void = () => {};
  onPlay: (item: TweetItem) => void = () => {};
  @State query: string = '';
  @State tweets: TweetItem[] = [];
  @State loading: boolean = false;
  @State error: string = '';
  @State searched: boolean = false;

  private async runSearch(): Promise<void> {
    const q = this.query.trim();
    if (q.length == 0) return;
    this.loading = true;
    this.error = '';
    this.searched = true;
    try {
      const page = await XApi.search(this.cookie, q);
      this.tweets = page.tweets;
    } catch (e) {
      this.error = `${e}`;
      this.tweets = [];
    } finally {
      this.loading = false;
    }
  }

  build() {
    Column() {
      Row() {
        TextInput({ placeholder: '搜索 X', text: this.query })
          .layoutWeight(1).height(40).borderRadius(20)
          .backgroundColor('#EFF3F4')
          .onChange((value: string) => this.query = value)
          .onSubmit(() => this.runSearch())
        Button('搜索').height(36).margin({ left: 8 })
          .onClick(() => this.runSearch())
      }.padding(12)

      if (this.loading) {
        LoadingProgress().width(36).height(36).margin({ top: 40 })
      } else if (this.error.length > 0) {
        Text(this.error).fontSize(13).fontColor('#F4212E').padding(16)
      } else if (!this.searched) {
        Column() {
          Text('搜索用户、话题或关键词').fontSize(14).fontColor('#536471')
          Text('趋势榜单需要额外接口，后续接入').fontSize(12).fontColor('#8B98A5').margin({ top: 8 })
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.tweets.length == 0) {
        Text('没有搜索结果').fontSize(14).fontColor('#536471').margin({ top: 40 })
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
                  onOpen: (value: TweetItem) => this.onOpen(value),
                  onPlay: (value: TweetItem) => this.onPlay(value)
                })
                Divider().color('#EFF3F4')
              }
            }
          }, (item: TweetItem) => item.id)
        }.layoutWeight(1)
      }
    }.width('100%').height('100%')
  }
}
