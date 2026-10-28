@Component
export struct AboutPage {
  @Link page: string;
  onClose: () => void = () => {};
  private licenseText: string = `MIT License

Copyright (c) 2026 tuichuang contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.`;

  @Builder
  header(title: string, showBack: boolean) {
    Row() {
      if (showBack) {
        Button() {
          Text('‹').fontSize(26).fontColor($r('app.color.text_primary'))
        }
        .width(40).height(40).borderRadius(20)
        .backgroundColor($r('app.color.surface'))
        .onClick(() => this.page = 'main')
        .margin({ right: 10 })
      }
      Text(title).fontSize(24).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary')).layoutWeight(1)
    }.width('100%').padding({ left: 20, right: 20, top: 12, bottom: 12 })
  }

  @Builder
  infoRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(15).fontColor($r('app.color.text_primary')).layoutWeight(1)
      Text(value).fontSize(14).fontColor($r('app.color.text_secondary')).textAlign(TextAlign.End).maxLines(2)
    }.width('100%').padding({ left: 16, right: 16, top: 14, bottom: 14 })
  }

  build() {
    Column() {
      if (this.page == 'license') {
        this.header('开源许可', true)
        Scroll() {
          Column() {
            Text('本应用采用 MIT License 开源。')
              .fontSize(14).fontColor($r('app.color.text_primary')).width('100%').margin({ bottom: 10 })
            Text(this.licenseText)
              .fontSize(12).lineHeight(18)
              .fontColor($r('app.color.text_secondary')).width('100%')
              .copyOption(CopyOptions.LocalDevice)
            Divider().strokeWidth(1.5).color($r('app.color.divider')).margin({ top: 18, bottom: 14 })
            Text('第三方组件').fontSize(15).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary')).width('100%')
            Text('HarmonyOS / ArkUI 与 OpenHarmony 相关组件遵循其各自开源许可。本应用为非官方个人项目，与任何商标权利人无隶属或授权关系。')
              .fontSize(12).lineHeight(18).fontColor($r('app.color.text_secondary'))
              .width('100%').margin({ top: 8 })
            Blank().height(24)
          }.width('100%').padding({ left: 20, right: 20 })
        }.layoutWeight(1).scrollBar(BarState.Off)
      } else {
        this.header('关于', false)
        Scroll() {
          Column() {
            Column() {
              Image($r('app.media.app_icon')).width(76).height(76).borderRadius(18)
              Text('HM-Xbird').fontSize(22).fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary')).margin({ top: 12 })
              Text('1.0.0').fontSize(13).fontColor($r('app.color.text_secondary')).margin({ top: 3 })
              Text('HarmonyOS 原生应用')
                .fontSize(13).fontColor($r('app.color.text_secondary')).margin({ top: 6 })
            }.width('100%').alignItems(HorizontalAlign.Center).padding({ top: 10, bottom: 22 })

            Text('HM-Xbird 是一个基于 HarmonyOS 原生技术开发的应用，使用 ArkTS / ArkUI 构建界面，注重折叠屏适配与系统交互。')
              .fontSize(14).lineHeight(21).fontColor($r('app.color.text_primary'))
              .width('100%').padding({ left: 16, right: 16, bottom: 16 })

            Column() {
              this.infoRow('版本', '1.0.0')
              Divider().strokeWidth(1.5).color($r('app.color.divider')).margin({ left: 16 })
              this.infoRow('发布者', 'phys1992')
              Divider().strokeWidth(1.5).color($r('app.color.divider')).margin({ left: 16 })
              this.infoRow('应用名称', 'HM-Xbird')
              Divider().strokeWidth(1.5).color($r('app.color.divider')).margin({ left: 16 })
              this.infoRow('包名', 'io.github.phys1992.hmxbird')
              Divider().strokeWidth(1.5).color($r('app.color.divider')).margin({ left: 16 })
              this.infoRow('GitHub', 'github.com/phys1992')
              Divider().strokeWidth(1.5).color($r('app.color.divider')).margin({ left: 16 })
              this.infoRow('技术栈', 'ArkTS · ArkUI · ArkWeb')
            }.width('100%').backgroundColor($r('app.color.surface')).borderRadius(20)

            Column() {
              Row() {
                Text('开源许可').fontSize(15).fontColor($r('app.color.text_primary')).layoutWeight(1)
                Text('MIT').fontSize(13).fontColor($r('app.color.text_secondary'))
                Text('›').fontSize(20).fontColor($r('app.color.text_secondary')).margin({ left: 6 })
              }.width('100%').padding(16).onClick(() => this.page = 'license')
            }.width('100%').backgroundColor($r('app.color.surface')).borderRadius(20).margin({ top: 12 })

            Text('本应用为非官方个人项目。')
              .fontSize(11).fontColor($r('app.color.text_secondary'))
              .width('100%').textAlign(TextAlign.Center).margin({ top: 20 })
            Text('© 2026 phys1992')
              .fontSize(11).fontColor($r('app.color.text_secondary'))
              .width('100%').textAlign(TextAlign.Center).margin({ top: 6 })
            Blank().height(24)
          }.width('100%')
        }.layoutWeight(1).scrollBar(BarState.Off)
      }
    }
    .width('100%').height('100%')
    .backgroundColor($r('app.color.grouped_bg'))
  }
}
