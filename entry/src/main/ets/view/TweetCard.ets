import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { i18n } from '@kit.LocalizationKit';
import { TweetItem } from '../model/TweetItem';
import { UserProfile } from '../model/UserProfile';
import { XApi, errorText } from '../api/XApi';
import { InlineVideo } from './InlineVideo';
import { I18n } from '../model/I18n';
import { ProfileCache } from '../model/ProfileCache';
import { SessionStore } from '../model/SessionStore';
import { FollowStatusStore } from '../model/FollowStatusStore';
import { RelationStore } from '../model/RelationStore';
import { TranslationSettings, TranslationSettingsStore } from '../model/TranslationSettings';

@Component
export struct TweetCard {
  @StorageProp('clientLang') clientLanguage: string = 'zh';
  private tr(value: string): string {
    return this.clientLanguage.length >= 0 ? I18n.t(value) : I18n.t(value);
  }

  item: TweetItem = new TweetItem();
  cookie: string = '';
  onReply: (item: TweetItem) => void = () => {};
  onQuote: (item: TweetItem) => void = () => {};
  onOpen: (item: TweetItem) => void = () => {};
  onPlay: (item: TweetItem, startTime: number) => void = () => {};
  onImage: (url: string) => void = () => {};
  onOpenQuoted: (id: string) => void = () => {};
  onOpenUser: (handle: string) => void = () => {};
  videoPane: string = 'left';
  videoIndex: number = 0;
  ownProfileRetweet: boolean = false;
  showFollow: boolean = false;
  viewerHandle: string = '';
  @StorageProp('followStateTick') @Watch('onFollowStateTick') followStateTick: number = 0;
  @State liked: boolean = false;
  @State retweeted: boolean = false;
  @State likeCount: number = 0;
  @State retweetCount: number = 0;
  @State viewCount: number = 0;
  @State following: boolean = false;
  @State followBusy: boolean = false;
  @State busy: boolean = false;
  @State translatedText: string = '';
  @State translating: boolean = false;
  @State showOriginal: boolean = false;
  @State actionWidth: number = 0;
  private translationSettings: TranslationSettings = new TranslationSettings();

  aboutToAppear(): void {
    this.likeCount = this.item.likeCount;
    this.retweetCount = this.item.retweetCount;
    this.viewCount = this.item.viewCount;
    this.following = this.item.authorFollowing;
    if (!this.following && this.showFollow) {
      const known = FollowStatusStore.get(this.item.authorHandle);
      if (known != undefined) {
        this.following = known;
      } else {
        const cached = ProfileCache.load(getContext(this) as common.UIAbilityContext, this.item.authorHandle);
        if (cached != null) this.following = cached.isFollowing;
      }
    }
    this.translationSettings = TranslationSettingsStore.load(getContext(this) as common.UIAbilityContext);
    this.autoTranslate();
  }

  private actionStep(): number {
    return this.actionWidth > 40 ? (this.actionWidth - 40) / 3 : 0;
  }

  private showActionNumbers(): boolean {
    // Four 40vp buttons leave ~20vp between them at the minimum width.
    // Counts sit under the icon and no longer compete with the next action.
    return this.actionWidth >= 200;
  }

  private destLanguage(): string {
    if (this.translationSettings.enabled &&
      this.translationSettings.targetLang.length > 0 &&
      this.translationSettings.targetLang != 'system') {
      return this.translationSettings.targetLang;
    }
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
    this.translationSettings = TranslationSettingsStore.load(getContext(this) as common.UIAbilityContext);
    this.translating = true;
    XApi.translateTweet(this.cookie, this.item.id, this.destLanguage()).then((text: string) => {
      this.translatedText = text;
    }).catch(() => {}).finally(() => {
      this.translating = false;
    });
  }

  private autoTranslate(): void {
    if (!this.translationSettings.enabled) return;
    const source = this.item.lang.indexOf('-') > 0
      ? this.item.lang.substring(0, this.item.lang.indexOf('-')) : this.item.lang;
    const exception = this.translationSettings.exceptionLang.indexOf('-') > 0
      ? this.translationSettings.exceptionLang.substring(0,
        this.translationSettings.exceptionLang.indexOf('-')) : this.translationSettings.exceptionLang;
    if (exception.length > 0 && source == exception) return;
    if (!this.canTranslate()) return;
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
      promptAction.showToast({ message: this.tr(`点赞失败：${errorText(e)}`) });
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
      ProfileCache.notifyChanged();
    } catch (e) {
      promptAction.showToast({ message: this.tr(`转推失败：${e}`) });
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

  private unitText(value: number, unit: string): string {
    const rounded = Math.round(value * 10) / 10;
    if (rounded >= 100) return `${Math.min(999, Math.round(rounded))}${unit}`;
    return `${rounded.toFixed(1)}${unit}`;
  }

  onFollowStateTick(): void {
    if (this.followBusy) return;
    const state = FollowStatusStore.get(this.item.authorHandle);
    if (state != undefined) this.following = state;
  }

  private shortCount(value: number): string {
    if (value < 1000) return `${value}`;
    if (value < 999500) return this.unitText(value / 1000, 'K');
    if (value < 999500000) return this.unitText(value / 1000000, 'M');
    return this.unitText(value / 1000000000, 'G');
  }

  private async toggleFollow(): Promise<void> {
    if (this.followBusy || this.item.authorHandle.length == 0) return;
    const target = !this.following;
    this.followBusy = true;
    try {
      const ok = await XApi.setFollow(this.cookie, this.item.authorId, this.item.authorHandle, target);
      if (!ok) throw new Error(this.tr('操作失败'));
      this.following = target;
      ProfileCache.setFollowing(getContext(this) as common.UIAbilityContext,
        this.item.authorHandle, target, this.item.authorName, this.item.avatarUrl);
      const followedUser = new UserProfile();
      followedUser.id = this.item.authorId;
      followedUser.handle = this.item.authorHandle;
      followedUser.name = this.item.authorName;
      followedUser.avatarUrl = this.item.avatarUrl;
      followedUser.isFollowing = target;
      RelationStore.markFollow(this.item.authorHandle, target, followedUser);
      if (RelationStore.viewerId.length > 0) {
        RelationStore.refresh(this.cookie, RelationStore.viewerId).catch(() => {});
      }
      promptAction.showToast({ message: target ? this.tr('已关注') : this.tr('已取消关注') });
    } catch (e) {
      promptAction.showToast({ message: this.tr(`操作失败：${e}`), duration: 2500 });
    } finally {
      this.followBusy = false;
    }
  }

  private shareLink(): void {
    const context = getContext(this) as common.UIAbilityContext;
    if (SessionStore.loadShareConsent(context)) {
      this.copyShareLink();
      return;
    }
    AlertDialog.show({
      title: this.tr('复制推文链接'),
      message: this.tr('分享功能需要将推文链接写入系统剪贴板。是否允许？'),
      autoCancel: true,
      primaryButton: { value: this.tr('取消'), action: () => {} },
      secondaryButton: {
        value: this.tr('允许并复制'),
        action: () => {
          SessionStore.saveShareConsent(context);
          this.copyShareLink();
        }
      }
    });
  }

  private async copyShareLink(): Promise<void> {
    try {
      const url = `https://x.com/${this.item.authorHandle}/status/${this.item.id}`;
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, url);
      await pasteboard.getSystemPasteboard().setData(data);
      promptAction.showToast({ message: this.tr('链接已复制') });
    } catch (e) {
      promptAction.showToast({ message: this.tr('复制失败'), duration: 2000 });
    }
  }

  build() {
    Column() {
      if (this.item.isRetweet && this.item.retweetedByHandle != undefined && this.item.retweetedByHandle.length > 0) {
        Row() {
          Image($r('app.media.ic_repost_active')).width(14).height(14).fillColor('#00BA7C')
          Text(this.ownProfileRetweet ? this.tr('你已转帖') : this.tr('已转帖'))
            .fontSize(12).fontColor('#00BA7C').margin({ left: 5 })
        }.width('100%').padding({ left: 56, right: 12, top: 10 })
      }

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
            .onClick(() => this.onOpenUser(this.item.authorHandle))
          Text(`@${this.item.authorHandle} · ${this.shortTime(this.item.createdAt)}`)
            .fontSize(12).fontColor($r('app.color.text_secondary')).margin({ left: 6 })
            .onClick(() => this.onOpenUser(this.item.authorHandle))
          if (this.showFollow && this.viewerHandle != this.item.authorHandle) {
            Button() {
              if (this.followBusy) {
                LoadingProgress().width(16).height(16)
                  .color(this.following ? '#FFFFFF' : $r('app.color.accent'))
              } else {
                Image(this.following ? $r('app.media.ic_follow_check_white') : $r('app.media.ic_follow_add_blue'))
                  .width(19).height(19)
              }
            }
            .width(32).height(32).borderRadius(16)
            .backgroundColor(this.following ? $r('app.color.accent') : Color.Transparent)
            .border({
              width: this.following ? 0 : 1.3,
              color: this.following ? Color.Transparent : $r('app.color.accent')
            })
            .margin({ left: 6 })
            .enabled(!this.followBusy)
            .accessibilityText(this.following ? this.tr('取消关注') : this.tr('关注'))
            .onClick(() => this.toggleFollow())
          }
        }.width('100%')

        Text(this.translatedText.length > 0 && !this.showOriginal
          ? this.translatedText : this.item.text)
          .fontSize(15).lineHeight(21).margin({ top: 4 })
          .fontColor($r('app.color.text_primary'))
          .maxLines(12).textOverflow({ overflow: TextOverflow.Ellipsis })
          .onClick(() => this.onOpen(this.item))

        if (this.translating) {
          Row() {
            LoadingProgress().width(12).height(12)
            Text(this.tr('翻译中…')).fontSize(11).fontColor($r('app.color.text_secondary')).margin({ left: 4 })
          }.margin({ top: 4 })
        } else if (this.translatedText.length > 0) {
          Text(this.showOriginal ? this.tr('查看翻译') : this.tr('已翻译 · 查看原文'))
            .fontSize(11).fontColor('#1D9BF0').margin({ top: 3 })
            .onClick(() => this.showOriginal = !this.showOriginal)
        } else if (this.canTranslate()) {
          Text(this.tr('翻译')).fontSize(11).fontColor('#1D9BF0').margin({ top: 3 })
            .onClick(() => this.translateNow())
        }

        if (this.item.videoUrl.length > 0) {
          InlineVideo({
            url: this.item.videoUrl,
            posterUrl: this.item.imageUrl,
            videoId: this.item.id,
            pane: this.videoPane,
            index: this.videoIndex,
            surfaceName: `inline_${this.item.id}`,
            onFullscreen: (time: number) => this.onPlay(this.item, time)
          })
            .margin({ top: 8 })
        } else if (this.item.imageUrl.length > 0) {
          Image(this.item.imageUrl).width('100%').aspectRatio(1.7)
            .objectFit(ImageFit.Cover).borderRadius(12)
            .margin({ top: 8 })
            .onClick(() => this.onImage(this.item.imageUrl))
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
          Blank()
          Image($r('app.media.ic_views')).width(12).height(12)
            .fillColor($r('app.color.text_secondary'))
          Text(`${this.tr('浏览')} ${this.shortCount(this.viewCount)}`)
            .fontSize(10).fontColor($r('app.color.text_secondary')).margin({ left: 4 })
        }
        .width('100%').justifyContent(FlexAlign.End)
        .margin({ top: 5, bottom: 1 })

        Stack({ alignContent: Alignment.TopStart }) {
          Column() {
            Image($r('app.media.ic_reply')).width(20).height(20)
            if (this.item.replyCount > 0 && this.showActionNumbers()) {
              Text(this.shortCount(this.item.replyCount)).fontSize(9).lineHeight(9).maxLines(1)
                .fontColor($r('app.color.text_secondary'))
            }
          }
          .width(40).height(40).borderRadius(11).backgroundColor($r('app.color.surface_secondary'))
          .justifyContent(FlexAlign.Center)
          .position({ x: 0, y: 0 })
          .onClick(() => this.onReply(this.item))
          .accessibilityText(this.tr('回复'))

          Column() {
            Image(this.retweeted ? $r('app.media.ic_repost_active') : $r('app.media.ic_repost')).width(20).height(20)
            if (this.retweetCount > 0 && this.showActionNumbers()) {
              Text(this.shortCount(this.retweetCount)).fontSize(9).lineHeight(9).maxLines(1)
                .fontColor(this.retweeted ? '#00BA7C' : $r('app.color.text_secondary'))
            }
          }
          .width(40).height(40).borderRadius(11).backgroundColor($r('app.color.surface_secondary'))
          .justifyContent(FlexAlign.Center)
          .position({ x: this.actionStep(), y: 0 })
          .onClick(() => this.toggleRetweet())
          .gesture(LongPressGesture().onAction(() => this.onQuote(this.item)))
          .accessibilityText(this.tr('转帖'))

          Column() {
            Image(this.liked ? $r('app.media.ic_heart_filled') : $r('app.media.ic_heart')).width(20).height(20)
            if (this.likeCount > 0 && this.showActionNumbers()) {
              Text(this.shortCount(this.likeCount)).fontSize(9).lineHeight(9).maxLines(1)
                .fontColor(this.liked ? '#F91880' : $r('app.color.text_secondary'))
            }
          }
          .width(40).height(40).borderRadius(11).backgroundColor($r('app.color.surface_secondary'))
          .justifyContent(FlexAlign.Center)
          .position({ x: this.actionStep() * 2, y: 0 })
          .onClick(() => this.toggleLike())
          .accessibilityText(this.tr('喜欢'))

          Column() {
            Image($r('app.media.ic_share')).width(20).height(20)
          }
          .width(40).height(40).borderRadius(11).backgroundColor($r('app.color.surface_secondary'))
          .justifyContent(FlexAlign.Center)
          .position({ x: this.actionStep() * 3, y: 0 })
          .onClick(() => this.shareLink())
          .accessibilityText(this.tr('分享'))
        }
        .width('100%').height(40).margin({ top: 2 })
        .onAreaChange((oldValue: Area, newValue: Area) => {
          const w = parseFloat(`${newValue.width}`);
          if (!isNaN(w) && w > 0 && Math.abs(w - this.actionWidth) > 0.5) {
            this.actionWidth = w;
          }
        })

      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }
      .width('100%').padding(12).alignItems(VerticalAlign.Top)
    }
    .width('100%')
  }
}
