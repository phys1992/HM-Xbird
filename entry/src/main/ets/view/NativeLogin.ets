import { SavedAccount } from '../model/AccountStore';

@Component
export struct NativeLogin {
  onLoggedIn: (cookie: string, save: boolean) => void = () => {};
  onWebLogin: () => void = () => {};
  savedAccounts: SavedAccount[] = [];
  onUseSaved: (account: SavedAccount) => void = () => {};
  @Link page: string;
  @State authToken: string = '';
  @State csrfToken: string = '';
  @State error: string = '';
  @State saveAccount: boolean = true;

  private go(page: string): void {
    animateTo({ duration: 280, curve: Curve.FastOutSlowIn }, () => {
      this.page = page;
    });
  }

  private submit(): void {
    const auth = this.authToken.trim();
    const csrf = this.csrfToken.trim();
    if (auth.length == 0 || csrf.length == 0) {
      this.error = '请分别填写 auth_token 和 ct0';
      return;
    }
    if (auth.indexOf(';') >= 0 || csrf.indexOf(';') >= 0) {
      this.error = 'auth_token 和 ct0 中不能包含分号';
      return;
    }
    this.error = '';
    this.onLoggedIn(`auth_token=${auth}; ct0=${csrf}`, this.saveAccount);
  }

  @Builder
  pageHeader(title: string) {
    Text(title).fontSize(22).fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.text_primary'))
      .width('100%').margin({ bottom: 18 })
  }

  @Builder
  entryRow(title: string, subtitle: string, enabled: boolean, action: () => void) {
    Row() {
      Column() {
        Text(title).fontSize(17).fontWeight(FontWeight.Medium)
          .fontColor(enabled ? $r('app.color.text_primary') : $r('app.color.text_secondary'))
        Text(subtitle).fontSize(12).fontColor($r('app.color.text_secondary')).margin({ top: 3 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text('›').fontSize(20).fontColor($r('app.color.text_secondary'))
    }
    .width('100%').padding(16)
    .backgroundColor($r('app.color.surface')).borderRadius(18)
    .margin({ bottom: 10 })
    .enabled(enabled)
    .onClick(() => { if (enabled) action(); })
  }

  @Builder
  homePage() {
    Column() {
      Text('登录 X').fontSize(28).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary')).width('100%').margin({ bottom: 6 })
      Text('选择一种登录方式').fontSize(13).fontColor($r('app.color.text_secondary'))
        .width('100%').margin({ bottom: 22 })
      this.entryRow('继续使用已保存账号',
        this.savedAccounts.length > 0 ? `已保存 ${this.savedAccounts.length} 个账号` : '暂无保存的账号',
        this.savedAccounts.length > 0, () => this.go('saved'))
      this.entryRow('使用 Cookie 登录', '分别填写 auth_token 与 ct0', true, () => this.go('cookie'))
      this.entryRow('使用网页登录', '登录 X 后自动获取 Cookie', true, () => this.onWebLogin())
    }
    .width('100%').alignItems(HorizontalAlign.Start)
    .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ x: 18 }))
      .animation({ duration: 280, curve: Curve.FastOutSlowIn }))
  }

  @Builder
  savedPage() {
    Column() {
      this.pageHeader('已保存账号')
      ForEach(this.savedAccounts, (account: SavedAccount) => {
        Row() {
          if (account.avatarUrl.length > 0) {
            Image(account.avatarUrl).width(46).height(46).borderRadius(23)
          } else {
            Circle({ width: 46, height: 46 }).fill($r('app.color.accent_soft'))
          }
          Column() {
            Text(account.name).fontSize(15).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary')).maxLines(1)
            Text(`@${account.handle}`).fontSize(12)
              .fontColor($r('app.color.text_secondary')).margin({ top: 2 })
          }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 10 })
          Text('使用 ›').fontSize(13).fontColor($r('app.color.accent'))
        }
        .width('100%').padding(12)
        .backgroundColor($r('app.color.surface')).borderRadius(16)
        .margin({ bottom: 8 })
        .onClick(() => this.onUseSaved(account))
      }, (account: SavedAccount) => account.id)
      Text('使用保存账号需要先通过系统指纹、人脸或锁屏密码认证。')
        .fontSize(12).fontColor($r('app.color.text_secondary')).width('100%').margin({ top: 12 })
    }
    .width('100%').alignItems(HorizontalAlign.Start)
    .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ x: 18 }))
      .animation({ duration: 280, curve: Curve.FastOutSlowIn }))
  }

  @Builder
  cookiePage() {
    Column() {
      this.pageHeader('使用 Cookie 登录')
      Column() {
        Text('auth_token').fontSize(13).fontColor($r('app.color.text_secondary'))
          .width('100%').margin({ bottom: 8 })
        TextInput({ placeholder: '粘贴 auth_token 的值', text: this.authToken })
          .width('100%').height(46)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.surface_secondary'))
          .onChange((value: string) => this.authToken = value)

        Text('ct0').fontSize(13).fontColor($r('app.color.text_secondary'))
          .width('100%').margin({ top: 18, bottom: 8 })
        TextInput({ placeholder: '粘贴 ct0 的值', text: this.csrfToken })
          .width('100%').height(46)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.surface_secondary'))
          .onChange((value: string) => this.csrfToken = value)
      }
      .width('100%').padding(16)
      .backgroundColor($r('app.color.surface')).borderRadius(20)
      if (this.error.length > 0) {
        Text(this.error).fontSize(12).fontColor('#F4212E').margin({ top: 8 }).width('100%')
      }
      Row() {
        Text('保存此账号').fontSize(16).fontColor($r('app.color.text_primary')).layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.saveAccount })
          .onChange((value: boolean) => this.saveAccount = value)
      }.width('100%').padding(16).margin({ top: 12 })
      .backgroundColor($r('app.color.surface')).borderRadius(16)
      Button('导入 Cookie 并登录')
        .width('100%').height(44).margin({ top: 12 })
        .backgroundColor($r('app.color.accent')).fontColor('#FFFFFF')
        .onClick(() => this.submit())
      Column() {
        Text('如何获取 Cookie').fontSize(13).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary')).width('100%')
        Text('1. 浏览器登录 x.com；\n2. 开发者工具 → Application → Cookies → x.com；\n3. 分别复制 auth_token 和 ct0 的值，填入上方两个输入框。')
          .fontSize(12).fontColor($r('app.color.text_secondary')).lineHeight(18).margin({ top: 6 }).width('100%')
      }
      .margin({ top: 22, bottom: 24 }).padding(12).borderRadius(14)
      .backgroundColor($r('app.color.surface_secondary'))
    }
    .width('100%').alignItems(HorizontalAlign.Start)
    .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ x: 18 }))
      .animation({ duration: 280, curve: Curve.FastOutSlowIn }))
  }

  build() {
    Column() {
      Scroll() {
        Column() {
          if (this.page == 'saved') {
            this.savedPage()
          } else if (this.page == 'cookie') {
            this.cookiePage()
          } else {
            this.homePage()
          }
        }.width('100%').alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1).width('100%').scrollBar(BarState.Off)
    }
    .width('100%').height('100%')
    .padding({ left: 20, right: 20, top: 12 })
    .backgroundColor($r('app.color.grouped_bg'))
  }
}
