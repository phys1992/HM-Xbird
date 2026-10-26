import { promptAction } from '@kit.ArkUI';
import { XApi } from '../api/XApi';

@Component
export struct ComposeView {
  cookie: string = '';
  replyToId: string = '';
  replyToHandle: string = '';
  quoteId: string = '';
  quoteHandle: string = '';
  quoteText: string = '';
  onClose: () => void = () => {};
  @State text: string = '';
  @State posting: boolean = false;
  @State error: string = '';

  private title(): string {
    if (this.replyToId.length > 0) return '回复';
    if (this.quoteId.length > 0) return '引用';
    return '发推';
  }

  private async post(): Promise<void> {
    const content = this.text.trim();
    if (content.length == 0) {
      this.error = '内容不能为空';
      return;
    }
    this.posting = true;
    this.error = '';
    try {
      const quoteUrl = this.quoteId.length > 0
        ? `https://x.com/${this.quoteHandle}/status/${this.quoteId}`
        : '';
      await XApi.createTweet(this.cookie, content, this.replyToId, quoteUrl);
      promptAction.showToast({ message: '已发布' });
      this.onClose();
    } catch (e) {
      this.error = `${e}`;
    } finally {
      this.posting = false;
    }
  }

  build() {
    Column() {
      Row() {
        Button('取消').backgroundColor('#00000000').fontColor('#0F1419')
          .onClick(() => this.onClose())
        Text(this.title()).fontSize(17).fontWeight(FontWeight.Bold).layoutWeight(1).textAlign(TextAlign.Center)
        Button(this.posting ? '发布中…' : '发布')
          .enabled(!this.posting)
          .backgroundColor('#0F1419').fontColor('#FFFFFF').borderRadius(20)
          .onClick(() => this.post())
      }.width('100%').padding(12)

      if (this.replyToId.length > 0) {
        Text(`回复 @${this.replyToHandle}`).fontSize(12).fontColor('#536471')
          .width('100%').padding({ left: 16, bottom: 8 })
      }
      if (this.quoteId.length > 0) {
        Column() {
          Text(`引用 @${this.quoteHandle}`).fontSize(12).fontColor('#536471')
          if (this.quoteText.length > 0) {
            Text(this.quoteText).fontSize(13).maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 4 })
          }
        }
        .width('100%').padding(12).margin({ left: 12, right: 12 })
        .backgroundColor('#F7F9F9').borderRadius(12)
      }

      TextArea({ placeholder: '有什么新鲜事？', text: this.text })
        .width('100%').layoutWeight(1).padding(16)
        .backgroundColor('#FFFFFF')
        .onChange((value: string) => this.text = value)

      if (this.error.length > 0) {
        Text(this.error).fontSize(12).fontColor('#F4212E').padding(12)
      }
    }
    .width('100%').height('100%').backgroundColor('#FFFFFF')
  }
}
