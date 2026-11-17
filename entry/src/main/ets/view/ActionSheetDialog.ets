import { I18n } from '../model/I18n';

export class DialogOption {
  title: string = '';
  description: string = '';
  destructive: boolean = false;
  icon?: Resource;
  action: () => void = () => {};

  constructor(title: string, description: string, destructive: boolean, action: () => void,
    icon?: Resource) {
    this.title = title;
    this.description = description;
    this.destructive = destructive;
    this.icon = icon;
    this.action = action;
  }
}

@CustomDialog
export struct ActionSheetDialog {
  controller?: CustomDialogController;
  title: string = '';
  message: string = '';
  options: DialogOption[] = [];

  private choose(option: DialogOption): void {
    this.controller?.close();
    setTimeout(() => option.action(), 80);
  }

  build() {
    Column() {
      Row()
        .width(36).height(4).borderRadius(2)
        .backgroundColor($r('app.color.divider'))
        .margin({ top: 2, bottom: 14 })

      Text(I18n.t(this.title)).fontSize(19).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary')).width('100%').textAlign(TextAlign.Center)
      if (this.message.length > 0) {
        Text(I18n.t(this.message)).fontSize(12).lineHeight(18)
          .fontColor($r('app.color.text_secondary'))
          .width('100%').textAlign(TextAlign.Center)
          .padding({ left: 8, right: 8, top: 6 })
      }

      Column() {
        ForEach(this.options, (option: DialogOption, index: number) => {
          Column() {
            Row() {
              if (option.icon != undefined) {
                Stack() {
                  Image(option.icon).width(20).height(20)
                    .fillColor(option.destructive ? '#F4212E' : $r('app.color.text_secondary'))
                }
                .width(36).height(36).borderRadius(10)
                .backgroundColor(option.destructive ? '#26F4212E' : $r('app.color.surface_secondary'))
                .margin({ right: 12 })
              }
              Column() {
                Text(I18n.t(option.title)).fontSize(16)
                  .fontColor(option.destructive ? '#F4212E' : $r('app.color.text_primary'))
                if (option.description.length > 0) {
                  Text(I18n.t(option.description)).fontSize(11)
                    .fontColor($r('app.color.text_secondary')).margin({ top: 3 })
                }
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            }
            .width('100%').height(option.description.length > 0 ? 66 : 54)
            .padding({ left: 16, right: 16 })
            .onClick(() => this.choose(option))

            if (index < this.options.length - 1) {
              Divider().strokeWidth(1).color($r('app.color.divider'))
                .margin({ left: 16, right: 16 })
            }
          }.width('100%')
        }, (option: DialogOption, index: number) => `${index}_${option.title}`)
      }
      .width('100%')
      .backgroundColor($r('app.color.surface'))
      .borderRadius(20)
      .margin({ top: 16 })
      .clip(true)

      Button(I18n.t('取消')).width('100%').height(48).fontSize(16)
        .backgroundColor($r('app.color.surface'))
        .fontColor($r('app.color.text_primary'))
        .borderRadius(20)
        .margin({ top: 10, bottom: 4 })
        .onClick(() => this.controller?.close())
    }
    .width('92%')
    .constraintSize({ maxWidth: 520 })
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor($r('app.color.grouped_bg'))
    .borderRadius(24)
    .alignItems(HorizontalAlign.Center)
  }
}
