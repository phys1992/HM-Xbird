import { promptAction } from '@kit.ArkUI';

@Component
export struct SettingsView {
  wide: boolean = false;
  onClose: () => void = () => {};
  onAddAccount: () => void = () => {};
  onLogout: () => void = () => {};
  @State selected: number = 0;
  @State foldedDetail: boolean = false;
  @State notifications: boolean = true;
  @State darkMode: boolean = false;

  private readonly titles: string[] = ['账号', '通知', '隐私与安全', '显示和亮度', '语言', '关于'];

  @Builder
  list() {
    Column() {
      ForEach(this.titles, (title: string, index: number) => {
        Row() {
          Text(title).fontSize(16).layoutWeight(1)
          Text('›').fontSize(18).fontColor('#999999')
        }
        .width('100%').height(52).padding({ left: 16, right: 16 })
        .backgroundColor(this.selected == index ? '#F0F4FF' : '#FFFFFF')
        .onClick(() => {
          this.selected = index;
          this.foldedDetail = true;
        })
        Divider().strokeWidth(1.5).color('#F0F0F0').margin({ left: 16 })
      }, (title: string) => title)
    }
    .width('100%')
  }

  @Builder
  detail() {
    Column() {
      if (!this.wide) {
        Row() {
          Button('‹ 返回').backgroundColor('#00000000').fontColor('#007DFF')
            .onClick(() => this.foldedDetail = false)
          Text(this.titles[this.selected]).fontSize(18).fontWeight(FontWeight.Bold).layoutWeight(1)
        }
        .width('100%').height(52).padding({ left: 8, right: 12 })
      } else {
        Text(this.titles[this.selected]).fontSize(20).fontWeight(FontWeight.Bold)
          .width('100%').padding({ left: 16, top: 16, bottom: 8 })
      }

      if (this.selected == 0) {
        Column() {
          Row() {
            Circle({ width: 48, height: 48 }).fill('#1D9BF0')
            Column() {
              Text('当前账号').fontSize(15).fontWeight(FontWeight.Bold)
              Text('已通过网页登录').fontSize(12).fontColor('#999999').margin({ top: 2 })
            }.alignItems(HorizontalAlign.Start).margin({ left: 12 })
          }.width('100%').padding(16)
          Divider().strokeWidth(1.5).color('#F0F0F0')
          Row() { Text('添加已有账号').fontSize(15) }.width('100%').padding(16)
            .onClick(() => this.onAddAccount())
          Row() { Text('登出').fontSize(15).fontColor('#E84026') }.width('100%').padding(16)
            .onClick(() => this.onLogout())
        }.width('100%')
      } else if (this.selected == 1) {
        Row() {
          Text('通知过滤').fontSize(15).layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.notifications })
            .onChange((value: boolean) => this.notifications = value)
        }.width('100%').padding(16)
      } else if (this.selected == 2) {
        Text('隐私与安全设置后续接入。当前账号数据由 X 网页端管理。')
          .fontSize(14).fontColor('#666666').padding(16)
      } else if (this.selected == 3) {
        Row() {
          Text('深色模式').fontSize(15).layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.darkMode })
            .onChange((value: boolean) => {
              this.darkMode = value;
              promptAction.showToast({ message: '深色模式将在后续版本接入' });
            })
        }.width('100%').padding(16)
      } else if (this.selected == 4) {
        Text('语言跟随系统。').fontSize(14).fontColor('#666666').padding(16)
      } else {
        Column() {
          Text('tuichuang').fontSize(16).fontWeight(FontWeight.Bold)
          Text('版本 0.1.0').fontSize(13).fontColor('#999999').margin({ top: 6 })
          Text('基于 ArkWeb 的 X 客户端').fontSize(13).fontColor('#999999').margin({ top: 4 })
        }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
      }
    }
    .width('100%').height('100%').alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      Row() {
        Button('‹ 设置').backgroundColor('#00000000').fontColor('#007DFF')
          .onClick(() => this.onClose())
        Blank()
      }.width('100%').height(52).padding({ left: 8, right: 12 })

      if (this.wide) {
        Row() {
          Column() { this.list() }.width(300).height('100%')
          Divider().strokeWidth(1.5).vertical(true).color('#E5E5E5')
          Column() { this.detail() }.layoutWeight(1).height('100%')
        }.layoutWeight(1).width('100%')
      } else {
        Column() {
          if (this.foldedDetail) {
            this.detail()
          } else {
            this.list()
          }
        }.layoutWeight(1).width('100%')
      }
    }
    .width('100%').height('100%').backgroundColor('#FFFFFF')
  }
}
