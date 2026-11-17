import { I18n } from '../model/I18n';

@Component
export struct SettingsPageHeader {
  @StorageProp('clientLang') clientLanguage: string = 'zh';
  @Prop title: string = '';
  @Prop showBack: boolean = false;
  onBack: () => void = () => {};

  private tr(value: string): string {
    return this.clientLanguage.length >= 0 ? I18n.t(value) : I18n.t(value);
  }

  build() {
    Row() {
      if (this.showBack) {
        Button() {
          Text('‹').fontSize(27).fontColor($r('app.color.text_primary'))
        }
        .width(40).height(40).borderRadius(20)
        .backgroundColor($r('app.color.surface'))
        .margin({ right: 10 })
        .onClick(() => this.onBack())
      }
      Text(this.tr(this.title)).fontSize(26).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary')).layoutWeight(1)
    }
    .width('100%').height(52)
    .padding({ left: this.showBack ? 16 : 20, right: 20, top: 8, bottom: 8 })
  }
}
