import { I18n } from '../model/I18n';
import { SettingsPageHeader } from './SettingsPageHeader';

@Component
export struct LanguageSettingsPage {
  @StorageProp('clientLang') clientLanguage: string = 'zh';
  private tr(value: string): string {
    return this.clientLanguage.length >= 0 ? I18n.t(value) : I18n.t(value);
  }

  @Prop bottomInset: number = 88;
  @Prop mode: string = 'system';
  @Prop showBack: boolean = false;
  onSelect: (mode: string) => void = () => {};
  onBack: () => void = () => {};

  @Builder
  languageRow(id: string, title: string, subtitle: string) {
    Row() {
      Column() {
        Text(title).fontSize(16).fontColor($r('app.color.text_primary'))
        if (subtitle.length > 0) {
          Text(subtitle).fontSize(12).fontColor($r('app.color.text_secondary')).margin({ top: 3 })
        }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      if (this.mode == id) {
        Stack({ alignContent: Alignment.Center }) {
          Circle({ width: 24, height: 24 }).fill($r('app.color.accent'))
          Text('✓').fontSize(14).fontColor('#FFFFFF').fontWeight(FontWeight.Bold)
        }.width(24).height(24)
      } else {
        Row()
          .width(24).height(24).borderRadius(12)
          .backgroundColor(Color.Transparent)
          .border({ width: 1.5, color: $r('app.color.text_secondary') })
      }
    }
    .width('100%').padding(16)
    .onClick(() => this.onSelect(id))
  }

  build() {
    Column() {
      SettingsPageHeader({ title: '语言', showBack: this.showBack, onBack: () => this.onBack() })

      Scroll() {
        Column() {
          Column() {
            this.languageRow('zh', '中文', '')
            Divider().strokeWidth(1.5).color($r('app.color.divider')).margin({ left: 16 })
            this.languageRow('en', 'English', '')
            Divider().strokeWidth(1.5).color($r('app.color.divider')).margin({ left: 16 })
            this.languageRow('system', I18n.followSystemLabel(), '')
          }.width('100%').backgroundColor($r('app.color.surface')).borderRadius(20).clip(true)

          Text(this.tr('应用界面语言。选择“跟随系统”时会使用系统语言。'))
            .fontSize(12).fontColor($r('app.color.text_secondary'))
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
