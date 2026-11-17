import { I18n } from '../model/I18n';
import { MediaQuality } from '../model/MediaQuality';
import { SettingsPageHeader } from './SettingsPageHeader';
import { AdaptiveSlider, AdaptiveSliderConfig } from './AdaptiveSlider';

@Component
export struct MediaSettingsPage {
  @StorageProp('clientLang') clientLanguage: string = 'zh';
  private tr(value: string): string {
    return this.clientLanguage.length >= 0 ? I18n.t(value) : I18n.t(value);
  }

  @Prop bottomInset: number = 88;
  @Prop imageLimitMb: number = 5;
  @Prop gifLimitMb: number = 15;
  @Prop showBack: boolean = false;
  @Prop imageQuality: number = 0.5;
  @Prop gifQuality: number = 0.5;
  private readonly imageConfig: AdaptiveSliderConfig = AdaptiveSliderConfig.fixed(3);
  private readonly gifConfig: AdaptiveSliderConfig = AdaptiveSliderConfig.fixed(3);
  private readonly imageLimitConfig: AdaptiveSliderConfig = AdaptiveSliderConfig.fixed(5, false);
  private readonly gifLimitConfig: AdaptiveSliderConfig = AdaptiveSliderConfig.fixed(15, false);
  onImageLimitChange: (value: number) => void = () => {};
  onGifLimitChange: (value: number) => void = () => {};
  onImageQualityChange: (value: number) => void = () => {};
  onGifQualityChange: (value: number) => void = () => {};
  onClose: () => void = () => {};

  private qualityLabel(value: number): string {
    const preset = MediaQuality.presetLabelAt(value);
    if (preset.length > 0) return this.tr(preset);
    return `${this.tr('压缩')} ${MediaQuality.compressionAt(value)}%`;
  }

  build() {
    Column() {
      SettingsPageHeader({ title: '发布', showBack: this.showBack, onBack: () => this.onClose() })

      Scroll() {
        Column() {
          Text(this.tr('图片')).fontSize(13).fontColor($r('app.color.text_secondary'))
            .width('100%').padding({ left: 4, top: 2, bottom: 8 })

          Column() {
            Row() {
              Text(this.tr('图片大小上限')).fontSize(16).fontColor($r('app.color.text_primary')).layoutWeight(1)
              Text(`${this.imageLimitMb} MB`).fontSize(13).fontColor($r('app.color.text_secondary'))
            }.width('100%')
            AdaptiveSlider({
              value: (this.imageLimitMb - 1) / 4,
              config: this.imageLimitConfig,
              onChange: (value: number) => this.onImageLimitChange(Math.round(1 + value * 4))
            }).width('100%')
            Divider().strokeWidth(1.5).color($r('app.color.divider')).margin({ top: 8, bottom: 12 })
            Row() {
              Text(this.tr('图片质量')).fontSize(16).fontColor($r('app.color.text_primary')).layoutWeight(1)
              Text(this.qualityLabel(this.imageQuality)).fontSize(13).fontColor($r('app.color.text_secondary'))
            }.width('100%')
            AdaptiveSlider({
              value: this.imageQuality,
              config: this.imageConfig,
              onChange: (value: number) => this.onImageQualityChange(value)
            }).width('100%').margin({ top: 2 })
          }
          .width('100%').padding(16)
          .backgroundColor($r('app.color.surface')).borderRadius(20)

          Text(this.tr('GIF动图')).fontSize(13).fontColor($r('app.color.text_secondary'))
            .width('100%').padding({ left: 4, top: 20, bottom: 8 })

          Column() {
            Row() {
              Text(this.tr('GIF 大小上限')).fontSize(16).fontColor($r('app.color.text_primary')).layoutWeight(1)
              Text(`${this.gifLimitMb} MB`).fontSize(13).fontColor($r('app.color.text_secondary'))
            }.width('100%')
            AdaptiveSlider({
              value: (this.gifLimitMb - 1) / 14,
              config: this.gifLimitConfig,
              onChange: (value: number) => this.onGifLimitChange(Math.round(1 + value * 14))
            }).width('100%')
            Divider().strokeWidth(1.5).color($r('app.color.divider')).margin({ top: 8, bottom: 12 })
            Row() {
              Text(this.tr('GIF 质量')).fontSize(16).fontColor($r('app.color.text_primary')).layoutWeight(1)
              Text(this.qualityLabel(this.gifQuality)).fontSize(13).fontColor($r('app.color.text_secondary'))
            }.width('100%')
            AdaptiveSlider({
              value: this.gifQuality,
              config: this.gifConfig,
              onChange: (value: number) => this.onGifQualityChange(value)
            }).width('100%').margin({ top: 2 })
          }
          .width('100%').padding(16)
          .backgroundColor($r('app.color.surface')).borderRadius(20)
          .margin({ top: 0 })

          Text(this.tr('视频和原画不压缩。其余质量发送时默认按所选质量压缩；若仍超过大小上限，会逐档降低至省流。'))
            .fontSize(12).lineHeight(18).fontColor($r('app.color.text_secondary'))
            .width('100%').padding({ left: 4, top: 12 })
          Blank().height(this.bottomInset + 16)
        }.width('100%').padding({ left: 16, right: 16 })
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off).align(Alignment.Top)
    }
    .width('100%').height('100%')
    .justifyContent(FlexAlign.Start)
    .backgroundColor($r('app.color.grouped_bg'))
  }
}
