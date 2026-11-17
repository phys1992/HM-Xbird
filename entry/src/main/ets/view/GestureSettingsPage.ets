import { I18n } from '../model/I18n';
import { SettingsPageHeader } from './SettingsPageHeader';
import { GestureDemo } from './GestureDemo';

@Component
export struct GestureSettingsPage {
  @StorageProp('clientLang') clientLanguage: string = 'zh';
  private tr(value: string): string {
    return this.clientLanguage.length >= 0 ? I18n.t(value) : I18n.t(value);
  }

  @Prop bottomInset: number = 88;
  @Prop fullscreenGestures: boolean = true;
  onGesturesChange: (value: boolean) => void = (value: boolean) => {};
  onBack: () => void = () => {};

  build() {
    Column() {
      SettingsPageHeader({
        title: '全屏手势',
        showBack: true,
        onBack: () => this.onBack()
      })

      Scroll() {
        Column() {
          GestureDemo()

          Column() {
            Row() {
              Column() {
                Text(this.tr('全屏手势')).fontSize(16).fontColor($r('app.color.text_primary'))
                Text(this.tr('开启后左半屏调亮度，右半屏调音量，横向滑动调进度'))
                  .fontSize(12).lineHeight(17).fontColor($r('app.color.text_secondary')).margin({ top: 3 })
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.fullscreenGestures })
                .onChange((next: boolean) => this.onGesturesChange(next))
            }.width('100%')
          }
          .width('100%').padding(16)
          .backgroundColor($r('app.color.surface')).borderRadius(20)
          .margin({ top: 24 })

          Blank().height(this.bottomInset + 16)
        }.width('100%').padding({ left: 16, right: 16, top: 20, bottom: 24 })
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off).align(Alignment.Top)
    }
    .width('100%').height('100%')
    .justifyContent(FlexAlign.Start)
    .backgroundColor($r('app.color.grouped_bg'))
  }
}
