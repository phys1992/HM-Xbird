import { TweetItem } from '../model/TweetItem';
import { UserProfile } from '../model/UserProfile';
import { XApi } from '../api/XApi';
import { TweetCard } from './TweetCard';

@Component
export struct ProfilePage {
  cookie: string = '';
  @Prop @Watch('onHandleChanged') handle: string = '';
  onClose: () => void = () => {};
  onOpenTweet: (item: TweetItem) => void = () => {};
  onReply: (item: TweetItem) => void = () => {};
  onQuote: (item: TweetItem) => void = () => {};
  onPlay: (item: TweetItem) => void = () => {};
  onImage: (url: string) => void = () => {};
  onOpenQuoted: (id: string) => void = () => {};
  onOpenUser: (handle: string) => void = () => {};
  @State profile: UserProfile | null = null;
  @State tweets: TweetItem[] = [];
  @State loading: boolean = true;
  @State error: string = '';

  onHandleChanged(): void {
    this.profile = null;
    this.tweets = [];
    this.load();
  }

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      const p = await XApi.userByScreenName(this.cookie, this.handle);
      this.profile = p;
      const page = await XApi.userTweets(this.cookie, p.id, '');
      this.tweets = page.tweets;
    } catch (e) {
      this.error = `${e}`;
    } finally {
      this.loading = false;
    }
  }

  build() {
    Column() {
      Row() {
        Button('‹').backgroundColor('#00000000').fontColor('#0F1419').fontSize(24)
          .onClick(() => this.onClose())
        Text(this.profile != null ? this.profile.name : `@${this.handle}`)
          .fontSize(17).fontWeight(FontWeight.Bold).layoutWeight(1)
        Blank().width(12)
      }.width('100%').height(48).padding({ left: 8, right: 12 })

      if (this.loading && this.profile == null) {
        Column() { LoadingProgress().width(32).height(32) }
          .layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.error.length > 0 && this.profile == null) {
        Column() {
          Text(this.error).fontSize(13).fontColor('#F4212E').padding(16)
          Button('重试').onClick(() => this.load())
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.profile != null) {
        List() {
          ListItem() {
            Column() {
              if (this.profile!.bannerUrl.length > 0) {
                Image(this.profile!.bannerUrl).width('100%').height(110).objectFit(ImageFit.Cover)
              } else {
                Row().width('100%').height(80).backgroundColor('#CFD9DE')
              }
              Row() {
                if (this.profile!.avatarUrl.length > 0) {
                  Image(this.profile!.avatarUrl).width(72).height(72).borderRadius(36)
                    .border({ width: 3, color: '#FFFFFF' })
                } else {
                  Circle({ width: 72, height: 72 }).fill('#1D9BF0')
                    .border({ width: 3, color: '#FFFFFF' })
                }
              }.width('100%').padding({ left: 16 }).offset({ y: -28 }).height(36)

              Text(this.profile!.name).fontSize(18).fontWeight(FontWeight.Bold)
              Text(`@${this.profile!.handle}`).fontSize(13).fontColor('#536471').margin({ top: 2 })
              if (this.profile!.description.length > 0) {
                Text(this.profile!.description).fontSize(14).lineHeight(20).margin({ top: 8 })
              }
              Row() {
                Text(`${this.profile!.following} 正在关注`).fontSize(13).fontColor('#536471')
                Text(`${this.profile!.followers} 关注者`).fontSize(13).fontColor('#536471')
                  .margin({ left: 16 })
              }.margin({ top: 8 })
            }.width('100%').padding({ left: 16, right: 16, bottom: 12 }).alignItems(HorizontalAlign.Start)
          }

          ForEach(this.tweets, (item: TweetItem) => {
            ListItem() {
              Column() {
                TweetCard({
                  item: item,
                  cookie: this.cookie,
                  onReply: (value: TweetItem) => this.onReply(value),
                  onQuote: (value: TweetItem) => this.onQuote(value),
                  onOpen: (value: TweetItem) => this.onOpenTweet(value),
                  onPlay: (value: TweetItem) => this.onPlay(value),
                  onImage: (url: string) => this.onImage(url),
                  onOpenQuoted: (id: string) => this.onOpenQuoted(id),
                  onOpenUser: (handle: string) => this.onOpenUser(handle)
                })
                Divider().color('#EFF3F4')
              }
            }
          }, (item: TweetItem) => item.id)
        }.layoutWeight(1).width('100%')
      }
    }.width('100%').height('100%').backgroundColor('#FFFFFF')
  }
}
