import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { dataSharePredicates } from '@kit.ArkData';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { camera, cameraPicker } from '@kit.CameraKit';
import { fileIo } from '@kit.CoreFileKit';
import { inputMethod } from '@kit.IMEKit';
import { XApi } from '../api/XApi';
import { EmojiStore } from '../model/EmojiStore';
import { EmojiGroupData } from '../model/EmojiData';
import { MediaCompressor } from '../model/MediaCompressor';
import { SessionStore } from '../model/SessionStore';
import { TweetLength } from '../model/TweetLength';
import { ComposeDraft, DraftStore } from '../model/DraftStore';

@Component
export struct ComposeView {
  cookie: string = '';
  replyToId: string = '';
  replyToHandle: string = '';
  quoteId: string = '';
  quoteHandle: string = '';
  quoteText: string = '';
  onClose: () => void = () => {};
  glass: boolean = false;
  @State text: string = '';
  @State posting: boolean = false;
  @State error: string = '';
  @State mediaUris: string[] = [];
  @State showEmoji: boolean = false;
  @State emojiGroups: EmojiGroupData[] = [];
  @State emojiIndex: number = 0;
  @State imageLimitMb: number = 5;
  @State gifLimitMb: number = 15;
  @State mediaQuality: number = 2;
  private areaController: TextAreaController = new TextAreaController();
  private cancelled: boolean = false;
  private posted: boolean = false;
  private draftTimer: number = -1;
  private lastSavedSignature: string = '';

  aboutToAppear(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    this.emojiGroups = EmojiStore.load(ctx);
    this.imageLimitMb = SessionStore.loadImageLimit(ctx);
    this.gifLimitMb = SessionStore.loadGifLimit(ctx);
    this.mediaQuality = SessionStore.loadMediaQuality(ctx);
    const draft = DraftStore.load(ctx);
    if (draft != null && draft.replyToId == this.replyToId && draft.quoteId == this.quoteId
      && (draft.text.length > 0 || draft.mediaUris.length > 0)) {
      this.text = draft.text;
      this.mediaUris = draft.mediaUris;
    }
    setTimeout(() => {
      focusControl.requestFocus('composeInput');
      try { this.areaController.caretPosition(this.text.length); } catch (e) {}
      setTimeout(() => {
        inputMethod.getController().showSoftKeyboard().catch(() => {});
      }, 120);
    }, 260);
    this.lastSavedSignature = this.draftSignature();
    this.startDraftTimer();
  }

  private draftSignature(): string {
    return `${this.text}\u0001${this.mediaUris.join('\u0002')}\u0001${this.replyToId}\u0001${this.quoteId}`;
  }

  private startDraftTimer(): void {
    if (this.draftTimer > 0) clearInterval(this.draftTimer);
    this.draftTimer = setInterval(() => {
      if (this.cancelled || this.posted) return;
      const signature = this.draftSignature();
      if (signature == this.lastSavedSignature) return;
      this.persistDraft();
      DraftStore.flush(getContext(this) as common.UIAbilityContext);
      this.lastSavedSignature = signature;
    }, 10000);
  }

  private stopDraftTimer(): void {
    if (this.draftTimer > 0) {
      clearInterval(this.draftTimer);
      this.draftTimer = -1;
    }
  }

  aboutToDisappear(): void {
    this.stopDraftTimer();
    if (!this.cancelled && !this.posted) {
      DraftStore.flush(getContext(this) as common.UIAbilityContext);
    }
  }

  private persistDraft(): void {
    if (this.cancelled || this.posted) return;
    const ctx = getContext(this) as common.UIAbilityContext;
    if (this.text.trim().length == 0 && this.mediaUris.length == 0) {
      DraftStore.clear(ctx);
      return;
    }
    const draft = new ComposeDraft();
    draft.text = this.text;
    draft.mediaUris = this.mediaUris;
    draft.replyToId = this.replyToId;
    draft.quoteId = this.quoteId;
    DraftStore.save(ctx, draft);
  }


  private displayUri(uri: string): string {
    return uri.startsWith('file://') ? uri : `file://${uri}`;
  }

  private currentEmojis(): string[] {
    if (this.emojiGroups.length == 0 || this.emojiIndex >= this.emojiGroups.length) return [];
    return this.emojiGroups[this.emojiIndex].emojis;
  }

  private useEmoji(emoji: string): void {
    this.text += emoji;
    this.persistDraft();
    EmojiStore.addRecent(getContext(this) as common.UIAbilityContext, emoji);
  }

  private count(): number {
    return TweetLength.count(this.text);
  }

  private overLimit(): boolean {
    return this.count() > TweetLength.MAX;
  }

  private title(): string {
    if (this.replyToId.length > 0) return '回复';
    if (this.quoteId.length > 0) return '引用';
    return '发推';
  }

  private async cachePicked(ctx: common.UIAbilityContext, uri: string, index: number): Promise<string> {
    let ext = '.jpg';
    const dot = uri.lastIndexOf('.');
    if (dot > 0) ext = uri.substring(dot);
    const dest = `${ctx.cacheDir}/picked_${Date.now()}_${index}${ext}`;
    const helper = photoAccessHelper.getPhotoAccessHelper(ctx);
    const predicates = new dataSharePredicates.DataSharePredicates();
    predicates.equalTo('uri', uri);
    const options: photoAccessHelper.FetchOptions = { fetchColumns: [], predicates: predicates };
    const assets = await helper.getAssets(options);
    const asset = await assets.getFirstObject();
    // Read through the media provider FD. The picker grants access to the
    // selected item; no direct filesystem path is used.
    const fd = await asset.getReadOnlyFd();
    try {
      const stat = fileIo.statSync(fd);
      const buffer = new ArrayBuffer(stat.size);
      fileIo.readSync(fd, buffer);
      const out = fileIo.openSync(dest, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(out.fd, buffer);
      } finally {
        fileIo.closeSync(out);
      }
    } finally {
      await asset.close(fd);
    }
    return dest;
  }

  private async prepareMedia(context: common.UIAbilityContext, path: string): Promise<string> {
    const lower = path.toLowerCase();
    if (lower.endsWith('.mp4') || lower.endsWith('.mov')) {
      if (fileIo.statSync(path).size > 512 * MediaCompressor.MB) {
        throw new Error('视频超过 512MB，请压缩后再上传');
      }
      return path;
    }
    const isGif = lower.endsWith('.gif');
    const mime = isGif ? 'image/gif' : 'image/jpeg';
    const limit = (isGif ? this.gifLimitMb : this.imageLimitMb) * MediaCompressor.MB;
    return await MediaCompressor.process(context, path, mime, limit, this.mediaQuality);
  }

  private async pickMedia(): Promise<void> {
    try {
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_VIDEO_TYPE;
      // The system picker exposes its built-in editor; the app never implements
      // cropping/filtering itself and receives only the edited result.
      options.isEditSupported = true;
      options.maxSelectNumber = Math.max(1, 4 - this.mediaUris.length);
      const result = await new photoAccessHelper.PhotoViewPicker().select(options);
      if (result.photoUris.length > 0) {
        const context = getContext(this) as common.UIAbilityContext;
        const local: string[] = [];
        for (let i = 0; i < result.photoUris.length && i < 4; i++) {
          const path = await this.cachePicked(context, result.photoUris[i], i);
          local.push(await this.prepareMedia(context, path));
        }
        this.mediaUris = this.mediaUris.concat(local);
        this.persistDraft();
      }
    } catch (e) {
      this.error = `选择图片失败：${e}`;
    }
  }

  private async capture(photo: boolean): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const suffix = photo ? 'jpg' : 'mp4';
      const path = `${context.cacheDir}/x_capture_${Date.now()}.${suffix}`;
      const file = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      fileIo.closeSync(file);
      // Per HarmonyOS cameraPicker guidance, saveUri keeps the capture in the
      // app sandbox instead of automatically inserting it into the gallery.
      const result = await cameraPicker.pick(context,
        [photo ? cameraPicker.PickerMediaType.PHOTO : cameraPicker.PickerMediaType.VIDEO], {
          cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK,
          saveUri: `file://${path}`,
          videoDuration: photo ? 0 : 140
        });
      if (result.resultCode == 0 && result.resultUri.length > 0) {
        const path = result.resultUri.startsWith('file://') ? result.resultUri.substring(7) : result.resultUri;
        const prepared = await this.prepareMedia(context, path);
        if (this.mediaUris.length < 4) this.mediaUris = this.mediaUris.concat([prepared]);
        this.persistDraft();
      }
    } catch (e) {
      this.error = `拍摄失败：${e}`;
    }
  }

  private async post(): Promise<void> {
    const content = this.text.trim();
    if (content.length == 0 && this.mediaUris.length == 0) {
      this.error = '内容不能为空';
      return;
    }
    if (this.overLimit()) {
      this.error = `内容超过 ${TweetLength.MAX} 字限制`;
      return;
    }
    this.posting = true;
    this.error = '';
    try {
      const ids: string[] = [];
      for (const uri of this.mediaUris) {
        ids.push(await XApi.uploadImage(this.cookie, uri));
      }
      const quoteUrl = this.quoteId.length > 0
        ? `https://x.com/${this.quoteHandle}/status/${this.quoteId}`
        : '';
      await XApi.createTweet(this.cookie, content, this.replyToId, quoteUrl, ids);
      this.stopDraftTimer();
      DraftStore.clear(getContext(this) as common.UIAbilityContext);
      this.posted = true;
      promptAction.showToast({ message: '已发布' });
      this.onClose();
    } catch (e) {
      this.error = `${e}`;
      console.error(`XHMedia post failed: ${e}`);
      promptAction.showToast({ message: this.error, duration: 4000 });
    } finally {
      this.posting = false;
    }
  }

  build() {
    Column() {
      Row() {
        Button('取消').backgroundColor('#00000000').fontColor($r('app.color.text_primary'))
          .onClick(() => {
            this.stopDraftTimer();
            DraftStore.clear(getContext(this) as common.UIAbilityContext);
            this.cancelled = true;
            this.onClose();
          })
        Text(this.title()).fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
          .layoutWeight(1).textAlign(TextAlign.Center)
        Text(`${this.count()}/${TweetLength.MAX}`)
          .fontSize(12)
          .fontColor(this.overLimit() ? '#F4212E' : $r('app.color.text_secondary'))
          .margin({ right: 8 })
        Button(this.posting ? '发布中…' : '发布')
          .enabled(!this.posting)
          .backgroundColor($r('app.color.accent')).fontColor('#FFFFFF').borderRadius(20)
          .onClick(() => this.post())
      }.width('100%').padding(12)
      Divider().strokeWidth(1).color($r('app.color.divider'))

      if (this.replyToId.length > 0) {
        Text(`回复 @${this.replyToHandle}`).fontSize(12).fontColor($r('app.color.text_secondary'))
          .width('100%').padding({ left: 16, bottom: 8 })
      }
      if (this.quoteId.length > 0) {
        Column() {
          Text(`引用 @${this.quoteHandle}`).fontSize(12).fontColor($r('app.color.text_secondary'))
          if (this.quoteText.length > 0) {
            Text(this.quoteText).fontSize(13).fontColor($r('app.color.text_primary')).maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 4 })
          }
        }
        .width('100%').padding(12).margin({ left: 12, right: 12 })
        .backgroundColor($r('app.color.surface_secondary')).borderRadius(12)
      }

      if (this.mediaUris.length > 0) {
        Scroll() {
          Row() {
            ForEach(this.mediaUris, (uri: string, index: number) => {
              Stack({ alignContent: Alignment.TopEnd }) {
                if (uri.toLowerCase().endsWith('.mp4') || uri.toLowerCase().endsWith('.mov')) {
                  Stack({ alignContent: Alignment.Center }) {
                    Row().width(78).height(78).borderRadius(10).backgroundColor('#222222')
                    Text('视频').fontSize(12).fontColor('#FFFFFF')
                  }.width(78).height(78)
                } else {
                  Image(this.displayUri(uri)).width(78).height(78).borderRadius(10).objectFit(ImageFit.Cover)
                }
                Button('×')
                  .width(22).height(22).fontSize(14).padding(0)
                  .backgroundColor('#99000000').fontColor('#FFFFFF')
                  .onClick(() => {
                    this.mediaUris = this.mediaUris.filter((u: string) => u != uri);
                    this.persistDraft();
                  })
              }.margin({ right: 8 })
            }, (uri: string) => uri)
            if (this.mediaUris.length < 4) {
              Stack({ alignContent: Alignment.Center }) {
                Text('+').fontSize(30).fontColor($r('app.color.text_secondary'))
              }
              .width(78).height(78).borderRadius(10)
              .backgroundColor($r('app.color.surface_secondary'))
              .border({ width: 1, color: $r('app.color.divider'), style: BorderStyle.Dashed })
              .margin({ right: 8 })
              .onClick(() => this.pickMedia())
            }
          }.padding({ left: 16, right: 16, bottom: 8 })
        }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
      }

      TextArea({ placeholder: '有什么新鲜事？', text: this.text, controller: this.areaController })
        .key('composeInput')
        .width('100%').layoutWeight(1).padding(16)
        .backgroundColor(this.glass ? Color.Transparent : $r('app.color.bg'))
        .fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.text_secondary'))
        .onChange((value: string) => { this.text = value; this.persistDraft(); })

      Row() {
        Button('图片/视频').height(32).fontSize(12)
          .backgroundColor($r('app.color.surface_secondary')).fontColor($r('app.color.text_primary'))
          .onClick(() => this.pickMedia())
        Button('拍照').height(32).fontSize(12).margin({ left: 8 })
          .backgroundColor($r('app.color.surface_secondary')).fontColor($r('app.color.text_primary'))
          .onClick(() => this.capture(true))
        Button('录像').height(32).fontSize(12).margin({ left: 8 })
          .backgroundColor($r('app.color.surface_secondary')).fontColor($r('app.color.text_primary'))
          .onClick(() => this.capture(false))
        Button('表情').height(32).fontSize(12).margin({ left: 8 })
          .backgroundColor(this.showEmoji ? $r('app.color.accent_soft') : $r('app.color.surface_secondary'))
          .fontColor(this.showEmoji ? $r('app.color.accent') : $r('app.color.text_primary'))
          .onClick(() => {
            if (!this.showEmoji) {
              inputMethod.getController().stopInputSession().catch(() => {});
            }
            animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
              this.showEmoji = !this.showEmoji;
            });
          })
        Blank()
        Text(`${this.mediaUris.length}/4`).fontSize(11)
          .fontColor($r('app.color.text_secondary')).margin({ left: 8 })
        Text('可在系统选择器中编辑').fontSize(10)
          .fontColor($r('app.color.text_secondary')).margin({ left: 6 })
      }.width('100%').padding({ left: 16, right: 16, top: 6, bottom: 8 })

      if (this.showEmoji) {
        Column() {
          Scroll() {
            Row() {
              ForEach(this.emojiGroups, (group: EmojiGroupData, index: number) => {
                Button(group.name).height(28).fontSize(11)
                  .backgroundColor(this.emojiIndex == index ? $r('app.color.accent') : Color.Transparent)
                  .fontColor(this.emojiIndex == index ? '#FFFFFF' : $r('app.color.text_secondary'))
                  .onClick(() => this.emojiIndex = index)
              }, (group: EmojiGroupData) => group.name)
            }.padding({ left: 8, right: 8 })
          }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).height(34)

          if (this.currentEmojis().length == 0) {
            Text('使用表情后会出现在这里').fontSize(12).fontColor($r('app.color.text_secondary'))
              .width('100%').textAlign(TextAlign.Center).padding(16)
          } else {
            Grid() {
              ForEach(this.currentEmojis(), (emoji: string, index: number) => {
                GridItem() {
                  Text(emoji).fontSize(23).width('100%').height(34).textAlign(TextAlign.Center)
                    .onClick(() => this.useEmoji(emoji))
                }
              }, (emoji: string, index: number) => `${emoji}-${index}`)
            }
            .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr')
            .columnsGap(2).rowsGap(2)
            .height(165).width('100%').padding({ left: 6, right: 6 })
          }
        }
        .height(205).width('100%')
        .backgroundColor($r('app.color.surface_secondary'))
        .transition(
          TransitionEffect.OPACITY
            .combine(TransitionEffect.translate({ y: 24 }))
            .animation({ duration: 300, curve: Curve.FastOutSlowIn })
        )
      }

      if (this.error.length > 0) {
        Text(this.error).fontSize(12).fontColor('#F4212E').padding(12)
      }
    }
    .width('100%').height('100%').backgroundColor(this.glass ? Color.Transparent : $r('app.color.bg'))
  }
}
