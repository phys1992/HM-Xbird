@Component
export struct PlaceholderView {
  title: string = '';
  description: string = '';
  icon: string = '✦';

  build() {
    Column() {
      Text(this.icon).fontSize(44).fontColor('#1D9BF0')
      Text(this.title).fontSize(20).fontWeight(FontWeight.Bold).margin({ top: 12 })
      Text(this.description).fontSize(13).fontColor('#536471')
        .textAlign(TextAlign.Center).margin({ top: 8 }).padding({ left: 32, right: 32 })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center)
  }
}
