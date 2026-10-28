import { promptAction } from '@kit.ArkUI';
import { i18n } from '@kit.LocalizationKit';
import { TweetItem } from '../model/TweetItem';
import { XApi, errorText } from '../api/XApi';
import { InlineVideo } from './InlineVideo';

@Component
export struct TweetCard {
  item: TweetItem = new TweetItem();
  cookie: string = '';
  onReply: (item: TweetItem) => void = () => {};
  onQuote: (item: TweetItem) => void = () => {};
  onOpen: (item: TweetItem) => void = () => {};
  onPlay: (item: TweetItem, startTime: number) => void = () => {};
  onImage: (url: string) => void = () => {};
  onOpenQuoted: (id: string) => void = () => {};
  onOpenUser: (handle: string) => void = () => {};
  @State liked: boolean = false;
  @State retweeted: boolean = false;
  @State likeCount: number = 0;
  @State retweetCount: number = 0;
  @State busy: boolean = false;
  @State inlineVideo: boolean = false;
  @State translatedText: string = '';
  @State translating: boolean = false;
  @State showOriginal: boolean = false;

  aboutToAppear(): void {
    this.likeCount = this.item.likeCount;
    this.retweetCount = this.item.retweetCount;
    this.autoTranslate();
  }

  private destLanguage(): string {
    try {
      const lang = i18n.System.getSystemLanguage();
      if (lang.length == 0) return 'en';
      if (lang.startsWith('zh')) return 'zh-cn';
      const dash = lang.indexOf('-');
      return dash > 0 ? lang.substring(0, dash) : lang;
    } catch (e) {
      return 'en';
    }
  }

  private canTranslate(): boolean {
    if (this.item.lang.length == 0 || this.item.lang == 'und') return false;
    const dest = this.destLanguage();
    const sourcePrimary = this.item.lang.indexOf('-') > 0
      ? this.item.lang.substring(0, this.item.lang.indexOf('-')) : this.item.lang;
    const destPrimary = dest.indexOf('-') > 0 ? dest.substring(0, dest.indexOf('-')) : dest;
    return sourcePrimary != destPrimary;
  }

  private translateNow(): void {
    if (this.translating || this.translatedText.length > 0) return;
    this.translating = true;
    XApi.translateTweet(this.cookie, this.item.id, this.destLanguage()).then((text: string) => {
      this.translatedText = text;
    }).catch(() => {}).finally(() => {
      this.translating = false;
    });
  }

  private autoTranslate(): void {
    if (!this.canTranslate()) return;
    // English is never auto-translated; other languages are.
    if (this.item.lang == 'en' || this.item.lang.startsWith('en-')) return;
    this.translateNow();
  }

  private async toggleLike(): Promise<void> {
    if (this.busy) return;
    this.busy = true;
    const target = !this.liked;
    const previousCount = this.likeCount;
    // Optimistic: update the heart immediately, roll back if the request fails.
    this.liked = target;
    this.likeCount += target ? 1 : -1;
    try {
      await XApi.setFavorite(this.cookie, this.item.id, target);
    } catch (e) {
      this.liked = !target;
      this.likeCount = previousCount;
      promptAction.showToast({ message: `点赞失败：${errorText(e)}` });
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
          .onClick(() => this.onOpenUser(this.item.authorHandle))
      } else {
        Stack({ alignContent: Alignment.Center }) {
          Circle({ width: 44, height: 44 }).fill($r('app.color.accent_soft'))
          Text(this.item.authorName.length > 0 ? this.item.authorName.substring(0, 1).toUpperCase() : '?')
            .fontSize(17).fontColor('#1D9BF0').fontWeight(FontWeight.Bold)
        }.width(44).height(44).margin({ right: 10 })
      }
      Column() {
        Row() {
          Text(this.item.authorName.length > 0 ? this.item.authorName : this.item.authorHandle)
            .fontSize(15).fontWeight(FontWeight.Bold).maxLines(1)
            .fontColor($r('app.color.text_primary'))
            .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
          Text(`@${this.item.authorHandle} · ${this.shortTime(this.item.createdAt)}`)
            .fontSize(12).fontColor($r('app.color.text_secondary')).margin({ left: 6 })
        }.width('100%').onClick(() => this.onOpenUser(this.item.authorHandle))

        Text(this.translatedText.length > 0 && !this.showOriginal
          ? this.translatedText : this.item.text)
          .fontSize(15).lineHeight(21).margin({ top: 4 })
          .fontColor($r('app.color.text_primary'))
          .maxLines(12).textOverflow({ overflow: TextOverflow.Ellipsis })
          .onClick(() => this.onOpen(this.item))

        if (this.translating) {
          Row() {
            LoadingProgress().width(12).height(12)
            Text('翻译中…').fontSize(11).fontColor($r('app.color.text_secondary')).margin({ left: 4 })
          }.margin({ top: 4 })
        } else if (this.translatedText.length > 0) {
          Text(this.showOriginal ? '查看翻译' : '已翻译 · 查看原文')
            .fontSize(11).fontColor('#1D9BF0').margin({ top: 3 })
            .onClick(() => this.showOriginal = !this.showOriginal)
        } else if (this.canTranslate()) {
          Text('翻译').fontSize(11).fontColor('#1D9BF0').margin({ top: 3 })
            .onClick(() => this.translateNow())
        }

        if (this.item.videoUrl.length > 0 && this.inlineVideo) {
          InlineVideo({
            url: this.item.videoUrl,
            surfaceName: `inline_${this.item.id}`,
            onFullscreen: (time: number) => this.onPlay(this.item, time)
          })
            .margin({ top: 8 })
        } else if (this.item.imageUrl.length > 0) {
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
            if (this.item.videoUrl.length > 0) {
              this.inlineVideo = true;
            } else if (this.item.imageUrl.length > 0) {
              this.onImage(this.item.imageUrl);
            } else {
              this.onOpen(this.item);
            }
          })
        }

        if (this.item.quotedId.length > 0) {
          Column() {
            Row() {
              if (this.item.quotedAvatarUrl.length > 0) {
                Image(this.item.quotedAvatarUrl).width(22).height(22).borderRadius(11)
              }
              Text(this.item.quotedAuthorName).fontSize(13).fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary')).margin({ left: 6 })
              Text(`@${this.item.quotedAuthorHandle}`).fontSize(12).fontColor($r('app.color.text_secondary'))
                .margin({ left: 4 })
            }.width('100%')
            Text(this.item.quotedText).fontSize(13).lineHeight(18)
              .fontColor($r('app.color.text_primary')).maxLines(4).textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 4 })
          }
          .width('100%').padding(10).margin({ top: 8 })
          .border({ width: 1, color: $r('app.color.placeholder') }).borderRadius(12)
          .alignItems(HorizontalAlign.Start)
          .onClick(() => this.onOpenQuoted(this.item.quotedId))
        }

        Row() {
          Row() {
            Image($r('app.media.ic_reply')).width(17).height(17)
            if (this.item.replyCount > 0) {
              Text(`${this.item.replyCount}`).fontSize(12).fontColor($r('app.color.text_secondary')).margin({ left: 5 })
            }
          }
          .height(32).padding({ left: 8, right: 8 }).borderRadius(16)
          .onClick(() => this.onReply(this.item))

          Row() {
            Image(this.retweeted ? $r('app.media.ic_repost_active') : $r('app.media.ic_repost')).width(18).height(18)
            if (this.retweetCount > 0) {
              Text(`${this.retweetCount}`).fontSize(12)
                .fontColor(this.retweeted ? '#00BA7C' : $r('app.color.text_secondary')).margin({ left: 5 })
            }
          }
          .height(32).padding({ left: 10, right: 10 }).borderRadius(16)
          .margin({ left: 8 })
          .onClick(() => this.toggleRetweet())
          .gesture(LongPressGesture().onAction(() => this.onQuote(this.item)))

          Row() {
            Image(this.liked ? $r('app.media.ic_heart_filled') : $r('app.media.ic_heart')).width(18).height(18)
            if (this.likeCount > 0) {
              Text(`${this.likeCount}`).fontSize(12)
                .fontColor(this.liked ? '#F91880' : $r('app.color.text_secondary')).margin({ left: 5 })
            }
          }
          .height(32).padding({ left: 10, right: 10 }).borderRadius(16)
          .margin({ left: 8 })
          .onClick(() => this.toggleLike())
        }.margin({ top: 6 }).width('100%')

      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }
    .width('100%').padding(12).alignItems(VerticalAlign.Top)
  }
}
