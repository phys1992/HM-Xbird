import { I18n } from '../model/I18n';
import { SettingsPageHeader } from './SettingsPageHeader';

class LanguageOption {
  code: string = '';
  label: string = '';
  constructor(code: string, label: string) {
    this.code = code;
    this.label = label;
  }
}

@Component
export struct TranslationSettingsPage {
  @StorageProp('clientLang') clientLanguage: string = 'zh';
  private tr(value: string): string {
    return this.clientLanguage.length >= 0 ? I18n.t(value) : I18n.t(value);
  }

  @Prop bottomInset: number = 88;
  @Prop showBack: boolean = false;
  @Prop autoEnabled: boolean = true;
  @Prop targetLang: string = '';
  @Prop exceptionLang: string = '';
  onEnabledChange: (value: boolean) => void = () => {};
  onTargetSelect: (code: string) => void = () => {};
  onExceptionSelect: (code: string) => void = () => {};
  onClose: () => void = () => {};

  private readonly languages: LanguageOption[] = [
    new LanguageOption('ar', '阿拉伯语'),
    new LanguageOption('zh-cn', '中文'),
    new LanguageOption('en', 'English'),
    new LanguageOption('fr', '法语'),
    new LanguageOption('ru', '俄语'),
    new LanguageOption('es', '西班牙语')
  ];

  build() {
    Column() {
      SettingsPageHeader({ title: '自动翻译', showBack: this.showBack, onBack: () => this.onClose() })

      Scroll() {
        Column() {
          Column() {
            Row() {
              Column() {
                Text(this.tr('自动翻译')).fontSize(16).fontColor($r('app.color.text_primary'))
                Text(this.tr('检测到非目标语言时自动翻译')).fontSize(12)
                  .fontColor($r('app.color.text_secondary')).margin({ top: 3 })
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.autoEnabled })
                .onChange((value: boolean) => {
                  this.onEnabledChange(value);
                })
            }.width('100%').padding(16)
          }.width('100%').backgroundColor($r('app.color.surface')).borderRadius(20)

          Column() {
            Row() {
              Text(this.tr('目标')).fontSize(12).fontColor($r('app.color.text_secondary'))
                .width(48).textAlign(TextAlign.Start)
              Text(this.tr('语种')).fontSize(12).fontColor($r('app.color.text_secondary'))
                .layoutWeight(1).textAlign(TextAlign.Center)
              Text(this.tr('例外')).fontSize(12).fontColor($r('app.color.text_secondary'))
                .width(48).textAlign(TextAlign.End)
            }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 6 })

            ForEach(this.languages, (option: LanguageOption, index: number) => {
              Row() {
                Column() {
                  if (this.targetLang == option.code) {
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
                .width(64).height(52).justifyContent(FlexAlign.Center)
                .enabled(this.autoEnabled)
                .onClick(() => {
                  if (!this.autoEnabled) return;
                  this.onTargetSelect(option.code);
                })

                Text(option.label).fontSize(16).fontColor($r('app.color.text_primary'))
                  .layoutWeight(1).textAlign(TextAlign.Center)
                  .opacity(this.autoEnabled ? 1 : 0.38)

                Column() {
                  if (this.exceptionLang == option.code) {
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
                .width(64).height(52).justifyContent(FlexAlign.Center)
                .enabled(this.autoEnabled)
                .onClick(() => {
                  if (!this.autoEnabled) return;
                  this.onExceptionSelect(option.code);
                })
              }
              .width('100%').height(52)
              .padding({ left: 16, right: 16 })
              .opacity(this.autoEnabled ? 1 : 0.72)
              if (index < this.languages.length - 1) {
                Divider().strokeWidth(1.5).color($r('app.color.divider')).margin({ left: 16, right: 16 })
              }
            }, (option: LanguageOption) => option.code)
          }
          .width('100%').backgroundColor($r('app.color.surface')).borderRadius(20)
          .margin({ top: 12 }).clip(true)

          Text(this.tr('目标决定翻译后的语言；例外语种保持原文。两者可以使用相同语种。'))
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
