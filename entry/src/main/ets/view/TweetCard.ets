import { promptAction } from '@kit.ArkUI';
import { TweetItem } from '../model/TweetItem';
import { XApi } from '../api/XApi';

@Component
export struct TweetCard {
  item: TweetItem = new TweetItem();
  cookie: string = '';
  onReply: (item: TweetItem) => void = () => {};
  onQuote: (item: TweetItem) => void = () => {};
  onOpen: (item: TweetItem) => void = () => {};
  onPlay: (item: TweetItem) => void = () => {};
  @State liked: boolean = false;
  @State retweeted: boolean = false;
  @State likeCount: number = 0;
  @State retweetCount: number = 0;
  @State busy: boolean = false;

  aboutToAppear(): void {
    this.likeCount = this.item.likeCount;
    this.retweetCount = this.item.retweetCount;
  }

  private async toggleLike(): Promise<void> {
    if (this.busy) return;
    this.busy = true;
    const target = !this.liked;
    try {
      await XApi.setFavorite(this.cookie, this.item.id, target);
      this.liked = target;
      this.likeCount += target ? 1 : -1;
    } catch (e) {
      promptAction.showToast({ message: `点赞失败：${e}` });
    } finally {
      this.busy = false;
    }
  }

  private async toggleRetweet(): Promise<void> {
    if (this.busy) return;
    this.busy = true;
    const target = !this.retweeted;
    try {
      await XApi.setRetweet(this.cookie, this.item.id, target);
      this.retweeted = target;
      this.retweetCount += target ? 1 : -1;
    } catch (e) {
      promptAction.showToast({ message: `转推失败：${e}` });
    } finally {
      this.busy = false;
    }
  }

  private shortTime(value: string): string {
    const date = new Date(value);
    if (isNaN(date.getTime())) return value;
    const diff = (new Date().getTime() - date.getTime()) / 1000;
    if (diff < 60) return `${Math.floor(diff)}s`;
    if (diff < 3600) return `${Math.floor(diff / 60)}m`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h`;
    return `${date.getMonth() + 1}/${date.getDate()}`;
  }

  build() {
    Row() {
      if (this.item.avatarUrl.length > 0) {
        Image(this.item.avatarUrl).width(44).height(44).borderRadius(22).margin({ right: 10 })
          .onClick(() => this.onOpen(this.item))
      } else {
        Circle({ width: 44, height: 44 }).fill('#E1E8ED').margin({ right: 10 })
      }
      Column() {
        Row() {
          Text(this.item.authorName.length > 0 ? this.item.authorName : this.item.authorHandle)
            .fontSize(15).fontWeight(FontWeight.Bold).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
          Text(`@${this.item.authorHandle} · ${this.shortTime(this.item.createdAt)}`)
            .fontSize(12).fontColor('#536471').margin({ left: 6 })
        }.width('100%').onClick(() => this.onOpen(this.item))

        Text(this.item.text)
          .fontSize(15).lineHeight(21).margin({ top: 4 })
          .maxLines(10).textOverflow({ overflow: TextOverflow.Ellipsis })
          .onClick(() => this.onOpen(this.item))

        if (this.item.imageUrl.length > 0) {
          Stack({ alignContent: Alignment.Center }) {
            Image(this.item.imageUrl).width('100%').aspectRatio(1.7)
              .objectFit(ImageFit.Cover).borderRadius(12)
            if (this.item.videoUrl.length > 0) {
              Circle({ width: 44, height: 44 }).fill('#99000000')
              Text('▶').fontSize(18).fontColor('#FFFFFF')
            }
          }
          .width('100%').margin({ top: 8 })
          .onClick(() => {
            if (this.item.videoUrl.length > 0) this.onPlay(this.item);
            else this.onOpen(this.item);
          })
        }

        if (this.item.quotedId.length > 0) {
          Column() {
            Row() {
              if (this.item.quotedAvatarUrl.length > 0) {
                Image(this.item.quotedAvatarUrl).width(22).height(22).borderRadius(11)
              }
              Text(this.item.quotedAuthorName).fontSize(13).fontWeight(FontWeight.Bold)
                .margin({ left: 6 })
              Text(`@${this.item.quotedAuthorHandle}`).fontSize(12).fontColor('#536471')
                .margin({ left: 4 })
            }.width('100%')
            Text(this.item.quotedText).fontSize(13).lineHeight(18)
              .maxLines(4).textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 4 })
          }
          .width('100%').padding(10).margin({ top: 8 })
          .border({ width: 1, color: '#CFD9DE' }).borderRadius(12)
          .alignItems(HorizontalAlign.Start)
        }

        Row() {
          Row() {
            Text('💬').fontSize(13)
            Text(`${this.item.replyCount}`).fontSize(12).fontColor('#536471').margin({ left: 4 })
          }.onClick(() => this.onReply(this.item))

          Row() {
            Text(this.retweeted ? '🔁' : '🔁').fontSize(13)
              .fontColor(this.retweeted ? '#00BA7C' : '#536471')
            Text(`${this.retweetCount}`).fontSize(12)
              .fontColor(this.retweeted ? '#00BA7C' : '#536471').margin({ left: 4 })
          }.margin({ left: 28 }).onClick(() => this.toggleRetweet())
            .gesture(LongPressGesture().onAction(() => this.onQuote(this.item)))

          Row() {
            Text(this.liked ? '❤️' : '🤍').fontSize(13)
            Text(`${this.likeCount}`).fontSize(12).fontColor(this.liked ? '#F91880' : '#536471').margin({ left: 4 })
          }.margin({ left: 28 }).onClick(() => this.toggleLike())
        }.margin({ top: 8 }).width('100%')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }
    .width('100%').padding(12).alignItems(VerticalAlign.Top)
  }
}
