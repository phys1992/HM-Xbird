import { XApi } from '../api/XApi';
import { TweetItem } from '../model/TweetItem';

@Component
export struct HomeView {
  cookie: string = '';
  onLogout: () => void = () => {};
  @State tweets: TweetItem[] = [];
  @State loading: boolean = false;
  @State error: string = '';
  @State cursor: string = '';
  @State tab: number = 0;

  aboutToAppear(): void {
    this.load(false);
  }

  private async load(more: boolean): Promise<void> {
    if (this.loading) return;
    this.loading = true;
    this.error = '';
    try {
      const page = await XApi.homeLatest(this.cookie, more ? this.cursor : '');
      this.tweets = more ? this.tweets.concat(page.tweets) : page.tweets;
      this.cursor = page.cursor;
    } catch (e) {
      this.error = `${e}`;
    } finally {
      this.loading = false;
    }
  }

  private shortTime(value: string): string {
    const date = new Date(value);
    if (isNaN(date.getTime())) return value;
    const now = new Date();
    const diff = (now.getTime() - date.getTime()) / 1000;
    if (diff < 60) return `${Math.floor(diff)}s`;
    if (diff < 3600) return `${Math.floor(diff / 60)}m`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h`;
    return `${date.getMonth() + 1}/${date.getDate()}`;
  }

  @Builder
  tweetCard(item: TweetItem) {
    Row() {
      if (item.avatarUrl.length > 0) {
        Image(item.avatarUrl)
          .width(44)
          .height(44)
          .borderRadius(22)
          .margin({ right: 10 })
      } else {
        Circle({ width: 44, height: 44 })
          .fill('#DDDDDD')
          .margin({ right: 10 })
      }
      Column() {
        Row() {
          Text(item.authorName.length > 0 ? item.authorName : item.authorHandle)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text(`@${item.authorHandle} · ${this.shortTime(item.createdAt)}`)
            .fontSize(12)
            .fontColor('#666')
            .margin({ left: 6 })
        }
        .width('100%')

        Text(item.text)
          .fontSize(15)
          .lineHeight(21)
          .margin({ top: 4 })
          .maxLines(8)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (item.imageUrl.length > 0) {
          Image(item.imageUrl)
            .width('100%')
            .aspectRatio(1.7)
            .objectFit(ImageFit.Cover)
            .borderRadius(12)
            .margin({ top: 8 })
        }

        Row() {
          Text(`💬 ${item.replyCount}`).fontSize(12).fontColor('#666')
          Text(`🔁 ${item.retweetCount}`).fontSize(12).fontColor('#666').margin({ left: 18 })
          Text(`❤️ ${item.likeCount}`).fontSize(12).fontColor('#666').margin({ left: 18 })
        }
        .margin({ top: 8 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(12)
    .alignItems(VerticalAlign.Top)
  }

  build() {
    Column() {
      Row() {
        Text('tuichuang')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
        Button('刷新')
          .height(30)
          .backgroundColor('#00000000')
          .fontColor('#1D9BF0')
          .onClick(() => this.load(false))
        Button('退出')
          .height(30)
          .backgroundColor('#00000000')
          .fontColor('#E0245E')
          .onClick(() => this.onLogout())
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 4 })

      if (this.error.length > 0) {
        Column() {
          Text(this.error)
            .fontSize(13)
            .fontColor('#E0245E')
            .padding(16)
          Button('重试')
            .onClick(() => this.load(false))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.loading && this.tweets.length == 0) {
        Column() {
          LoadingProgress().width(40).height(40)
          Text('加载时间线…').fontSize(13).fontColor('#666').margin({ top: 8 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.tweets.length == 0) {
        Column() {
          Text('时间线为空').fontSize(15).fontColor('#666')
          Text('请确认已登录，或稍后重试').fontSize(12).fontColor('#999').margin({ top: 6 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.tweets, (item: TweetItem) => {
            ListItem() {
              this.tweetCard(item)
            }
          }, (item: TweetItem) => item.id)
        }
        .layoutWeight(1)
        .width('100%')
        .onReachEnd(() => this.load(true))
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
