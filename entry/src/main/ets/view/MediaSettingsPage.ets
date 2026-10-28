@Component
export struct MediaSettingsPage {
  @Prop imageLimitMb: number = 5;
  @Prop gifLimitMb: number = 15;
  @Prop quality: number = 2;
  onImageLimitChange: (value: number) => void = () => {};
  onGifLimitChange: (value: number) => void = () => {};
  onQualityChange: (value: number) => void = () => {};
  onClose: () => void = () => {};

  @Builder
  qualityButton(value: number, label: string) {
    Button(label).layoutWeight(1).height(34).fontSize(12)
      .fontColor(this.quality == value ? '#FFFFFF' : $r('app.color.text_primary'))
      .backgroundColor(this.quality == value ? $r('app.color.accent') : $r('app.color.surface_secondary'))
      .borderRadius(17)
      .margin({ left: value == 0 ? 0 : 6 })
      .onClick(() => this.onQualityChange(value))
  }

  build() {
    Column() {
      Row() {
        Text('媒体与压缩').fontSize(24).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary')).layoutWeight(1)
      }.width('100%').padding({ left: 20, right: 20, top: 8, bottom: 8 })

      Scroll() {
        Column() {
          Text('上传大小上限').fontSize(13).fontColor($r('app.color.text_secondary'))
            .width('100%').padding({ left: 4, top: 2, bottom: 8 })

          Column() {
            Row() {
              Text('图片大小上限').fontSize(16).fontColor($r('app.color.text_primary')).layoutWeight(1)
              Text(`${this.imageLimitMb} MB`).fontSize(13).fontColor($r('app.color.text_secondary'))
            }.width('100%')
            Slider({ value: this.imageLimitMb, min: 1, max: 5, step: 1 })
              .width('100%').margin({ top: 4 })
              .onChange((value: number) => this.onImageLimitChange(value))
            Divider().strokeWidth(1.5).color($r('app.color.divider')).margin({ top: 8, bottom: 12 })
            Row() {
              Text('GIF 大小上限').fontSize(16).fontColor($r('app.color.text_primary')).layoutWeight(1)
              Text(`${this.gifLimitMb} MB`).fontSize(13).fontColor($r('app.color.text_secondary'))
            }.width('100%')
            Slider({ value: this.gifLimitMb, min: 1, max: 15, step: 1 })
              .width('100%').margin({ top: 4 })
              .onChange((value: number) => this.onGifLimitChange(value))
          }
          .width('100%').padding(16)
          .backgroundColor($r('app.color.surface')).borderRadius(20)

          Text('压缩质量').fontSize(13).fontColor($r('app.color.text_secondary'))
            .width('100%').padding({ left: 4, top: 20, bottom: 8 })

          Column() {
            Row() {
              this.qualityButton(0, '原图')
              this.qualityButton(1, '高')
              this.qualityButton(2, '标准')
              this.qualityButton(3, '省流')
            }.width('100%')
            Text('原图不压缩；超过大小上限时会提示。其他档位会在上传前压缩，并继续降质/缩放直到低于上限。')
              .fontSize(12).fontColor($r('app.color.text_secondary'))
              .width('100%').margin({ top: 12 })
          }
          .width('100%').padding(16)
          .backgroundColor($r('app.color.surface')).borderRadius(20)

          Text('视频超过 512 MB 时不会压缩，会提示先压缩再上传。')
            .fontSize(12).fontColor($r('app.color.text_secondary'))
            .width('100%').padding({ left: 4, top: 12 })
          Blank().height(30)
        }.width('100%').padding({ left: 16, right: 16 })
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off).align(Alignment.Top)
    }
    .width('100%').height('100%')
    .justifyContent(FlexAlign.Start)
    .backgroundColor($r('app.color.grouped_bg'))
  }
}
