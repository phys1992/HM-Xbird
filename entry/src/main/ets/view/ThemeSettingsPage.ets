@Component
export struct ThemeSettingsPage {
  @Prop mode: string = 'system';
  splitEnabled: boolean = true;
  barOpaque: boolean = false;
  onSplitChange: (value: boolean) => void = () => {};
  onBarOpaqueChange: (value: boolean) => void = () => {};
  onSelect: (mode: string) => void = () => {};
  onClose: () => void = () => {};

  private selected(value: string): boolean {
    return this.mode == value;
  }

  @Builder
  previewCard(dark: boolean, label: string) {
    Column() {
      Column() {
        Row() {
          Column().width(20).height(20).borderRadius(10)
            .backgroundColor(dark ? '#FFFFFF' : '#0A0A0A')
          Column() {
            Row().width(62).height(6).borderRadius(3)
              .backgroundColor(dark ? '#E7E9EA' : '#0F1419')
            Row().width(42).height(5).borderRadius(3)
              .backgroundColor(dark ? '#71767B' : '#8A8F98').margin({ top: 5 })
          }.alignItems(HorizontalAlign.Start).margin({ left: 8 }).layoutWeight(1)
        }.width('100%')
        Divider().strokeWidth(1.5).color(dark ? '#2F3336' : '#EFF3F4').margin({ top: 10, bottom: 8 })
        ForEach([0, 1, 2], (item: number) => {
          Row() {
            Circle({ width: 16, height: 16 }).fill(dark ? '#2F3336' : '#E8F3FD')
            Column() {
              Row().width(item == 1 ? 70 : 84).height(5).borderRadius(3)
                .backgroundColor(dark ? '#E7E9EA' : '#0F1419')
              Row().width('92%').height(5).borderRadius(3)
                .backgroundColor(dark ? '#71767B' : '#536471').margin({ top: 5 })
            }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 8 })
          }.width('100%').margin({ bottom: 10 })
        })
        Row() {
          Row().width(30).height(18).borderRadius(9)
            .backgroundColor(dark ? '#1D9BF0' : '#1D9BF0')
          Blank()
          Circle({ width: 10, height: 10 }).fill(dark ? '#71767B' : '#536471')
          Circle({ width: 10, height: 10 }).fill(dark ? '#71767B' : '#536471').margin({ left: 8 })
        }.width('100%').margin({ top: 2 })
      }
      .width('100%').height(176).padding(12)
      .backgroundColor(dark ? '#111113' : '#FFFFFF')
      .borderRadius(16)
      .border({ width: 1, color: dark ? '#2F3336' : '#E6E8EB' })

      Text(label).fontSize(15).fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary')).margin({ top: 10 })

      if (this.selected(dark ? 'dark' : 'light')) {
        Stack({ alignContent: Alignment.Center }) {
          Circle({ width: 24, height: 24 }).fill($r('app.color.accent'))
          Text('✓').fontSize(14).fontColor('#FFFFFF').fontWeight(FontWeight.Bold)
        }.width(24).height(24).margin({ top: 8 })
      } else {
        Row()
          .width(24).height(24).borderRadius(12)
          .backgroundColor(Color.Transparent)
          .border({ width: 1.5, color: $r('app.color.text_secondary') })
          .margin({ top: 8 })
      }
    }
    .layoutWeight(1)
    .onClick(() => this.onSelect(dark ? 'dark' : 'light'))
  }

  build() {
    Column() {
      Row() {
        Button() {
          Text('‹').fontSize(26).fontColor($r('app.color.text_primary'))
        }
        .width(40).height(40).borderRadius(20)
        .backgroundColor($r('app.color.surface'))
        .onClick(() => this.onClose())
        Text('显示与主题')
          .fontSize(24).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .margin({ left: 14 }).layoutWeight(1)
      }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 12 })

      Scroll() {
        Column() {
          Text('选择外观').fontSize(13).fontColor($r('app.color.text_secondary'))
            .width('100%').padding({ left: 4, bottom: 8 })

          Row() {
            this.previewCard(false, '浅色')
            Blank().width(12)
            this.previewCard(true, '深色')
          }
          .width('100%').padding(16)
          .backgroundColor($r('app.color.surface')).borderRadius(20)

          Text('显示').fontSize(13).fontColor($r('app.color.text_secondary'))
            .width('100%').padding({ left: 4, top: 20, bottom: 8 })

          Column() {
            Row() {
              Text('启用分栏').fontSize(16).fontColor($r('app.color.text_primary')).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.splitEnabled })
                .onChange((value: boolean) => this.onSplitChange(value))
            }.width('100%').padding(16)
            Divider().strokeWidth(1.5).color($r('app.color.divider')).margin({ left: 16 })
            Row() {
              Text('底栏纯白模式').fontSize(16).fontColor($r('app.color.text_primary')).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.barOpaque })
                .onChange((value: boolean) => this.onBarOpaqueChange(value))
            }.width('100%').padding(16)
          }
          .width('100%').backgroundColor($r('app.color.surface')).borderRadius(20)

          Text('跟随系统').fontSize(13).fontColor($r('app.color.text_secondary'))
            .width('100%').padding({ left: 4, top: 20, bottom: 8 })

          Row() {
            Column() {
              Text('跟随系统').fontSize(16).fontColor($r('app.color.text_primary'))
              Text('根据系统浅色/深色设置自动切换')
                .fontSize(12).fontColor($r('app.color.text_secondary')).margin({ top: 3 })
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            if (this.selected('system')) {
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
          .backgroundColor($r('app.color.surface')).borderRadius(20)
          .onClick(() => this.onSelect('system'))

          Text('深色模式会同步调整状态栏、导航栏和底栏材质。')
            .fontSize(12).fontColor($r('app.color.text_secondary'))
            .width('100%').padding({ left: 4, top: 12 })
          Blank().height(28)
        }.width('100%').padding({ left: 16, right: 16 })
      }
      .layoutWeight(1).width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%').height('100%')
    .backgroundColor($r('app.color.grouped_bg'))
  }
}
