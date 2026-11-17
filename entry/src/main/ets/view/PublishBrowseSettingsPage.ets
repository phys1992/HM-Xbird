import { I18n } from '../model/I18n';
import { SettingsPageHeader } from './SettingsPageHeader';
import { MediaQuality } from '../model/MediaQuality';
import { AdaptiveSlider, AdaptiveSliderConfig } from './AdaptiveSlider';

@Component
export struct PublishBrowseSettingsPage {
  @StorageProp('clientLang') clientLanguage: string = 'zh';
  private tr(value: string): string {
    return this.clientLanguage.length >= 0 ? I18n.t(value) : I18n.t(value);
  }

  @Prop bottomInset: number = 88;
  @Prop showBack: boolean = false;
  @Prop imageQuality: number = 0.5;
  @Prop gifQuality: number = 0.5;
  @Prop autoPlay: boolean = false;
  @Prop autoPlayMuted: boolean = true;
  onImageQualityChange: (value: number) => void = () => {};
  onGifQualityChange: (value: number) => void = () => {};
  onAutoPlayChange: (value: boolean) => void = () => {};
  onAutoPlayMutedChange: (value: boolean) => void = () => {};
  onOpenGestureSettings: () => void = () => {};
  onClose: () => void = () => {};


  private qualityLabel(value: number): string {
    const preset = MediaQuality.presetLabelAt(value);
    if (preset.length > 0) return this.tr(preset);
    return this.tr('标准');
  }

  private readonly imageConfig: AdaptiveSliderConfig = AdaptiveSliderConfig.fixed(3);
  private readonly gifConfig: AdaptiveSliderConfig = AdaptiveSliderConfig.fixed(3);


  build() {
    Column() {
      SettingsPageHeader({ title: '发送与播放', showBack: this.showBack, onBack: () => this.onClose() })

      Scroll() {
        Column() {
          Text(this.tr('发送')).fontSize(13).fontColor($r('app.color.text_secondary'))
            .width('100%').padding({ left: 4, top: 18, bottom: 8 })

          Column() {
            Row() {
              Text(this.tr('图片质量')).fontSize(16).fontColor($r('app.color.text_primary')).layoutWeight(1)
              Text(this.qualityLabel(this.imageQuality)).fontSize(13).fontColor($r('app.color.accent'))
            }.width('100%')
            Row() {
              Column() {
                Image($r('app.media.ic_quality_saver')).width(20).height(20)
              }.width(36).alignItems(HorizontalAlign.Center)
              AdaptiveSlider({
                value: this.imageQuality,
                config: this.imageConfig,
                onChange: (value: number) => this.onImageQualityChange(value)
              }).layoutWeight(1).margin({ left: 6, right: 6 })
              Column() {
                Image($r('app.media.ic_quality_original')).width(20).height(20)
              }.width(36).alignItems(HorizontalAlign.Center)
            }.width('100%').margin({ top: 6 })

            Divider().strokeWidth(1.5).color($r('app.color.divider')).margin({ top: 14, bottom: 12 })

            Row() {
              Text(this.tr('GIF质量')).fontSize(16).fontColor($r('app.color.text_primary')).layoutWeight(1)
              Text(this.qualityLabel(this.gifQuality)).fontSize(13).fontColor($r('app.color.accent'))
            }.width('100%')
            Row() {
              Column() {
                Image($r('app.media.ic_quality_saver')).width(20).height(20)
              }.width(36).alignItems(HorizontalAlign.Center)
              AdaptiveSlider({
                value: this.gifQuality,
                config: this.gifConfig,
                onChange: (value: number) => this.onGifQualityChange(value)
              }).layoutWeight(1).margin({ left: 6, right: 6 })
              Column() {
                Image($r('app.media.ic_quality_original')).width(20).height(20)
              }.width(36).alignItems(HorizontalAlign.Center)
            }.width('100%').margin({ top: 6 })

          }
          .width('100%').padding(16).backgroundColor($r('app.color.surface')).borderRadius(20)

          Text(this.tr('播放')).fontSize(13).fontColor($r('app.color.text_secondary'))
            .width('100%').padding({ left: 4, top: 20, bottom: 8 })

          Column() {
            Row() {
              Text(this.tr('自动播放')).fontSize(16).fontColor($r('app.color.text_primary')).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.autoPlay })
                .onChange((value: boolean) => this.onAutoPlayChange(value))
            }.width('100%').padding({ top: 12, bottom: 12 })
            Divider().strokeWidth(1.5).color($r('app.color.divider'))
            Row() {
              Text(this.tr('自动播放时静音')).fontSize(16)
                .fontColor($r('app.color.text_primary')).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.autoPlayMuted })
                .enabled(this.autoPlay)
                .opacity(this.autoPlay ? 1 : 0.45)
                .onChange((value: boolean) => this.onAutoPlayMutedChange(value))
            }.width('100%').padding({ top: 12, bottom: 12 })
            Divider().strokeWidth(1.5).color($r('app.color.divider'))
            Row() {
              Text(this.tr('全屏手势')).fontSize(16).fontColor($r('app.color.text_primary')).layoutWeight(1)
              Text('›').fontSize(20).fontColor($r('app.color.text_secondary'))
            }.width('100%').padding({ top: 12, bottom: 12 })
            .onClick(() => this.onOpenGestureSettings())
          }
          .width('100%').padding({ left: 16, right: 16 })
          .backgroundColor($r('app.color.surface')).borderRadius(20)

          Blank().height(this.bottomInset + 16)
        }.width('100%').padding({ left: 16, right: 16 })
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off).align(Alignment.Top)
    }
    .width('100%').height('100%')
    .justifyContent(FlexAlign.Start)
    .backgroundColor($r('app.color.grouped_bg'))
  }
}
