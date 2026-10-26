@Component
export struct NativeLogin {
  onLoggedIn: (cookie: string) => void = () => {};
  onWebLogin: () => void = () => {};
  @State input: string = '';
  @State error: string = '';

  private submit(): void {
    const value = this.input.trim();
    if (value.length == 0) {
      this.error = '请粘贴包含 auth_token 和 ct0 的 Cookie';
      return;
    }
    if (value.indexOf('auth_token=') < 0 || value.indexOf('ct0=') < 0) {
      this.error = 'Cookie 必须同时包含 auth_token 和 ct0';
      return;
    }
    this.error = '';
    this.onLoggedIn(value);
  }

  build() {
    Column() {
      Text('登录 X').fontSize(26).fontWeight(FontWeight.Bold).width('100%')
      Text('tuichuang 使用 X 的登录 Cookie，不上传账号密码。')
        .fontSize(13).fontColor('#536471').margin({ top: 8 }).width('100%')

      TextArea({ placeholder: 'auth_token=...; ct0=...', text: this.input })
        .width('100%').height(120).margin({ top: 20 })
        .onChange((value: string) => this.input = value)

      if (this.error.length > 0) {
        Text(this.error).fontSize(12).fontColor('#F4212E').margin({ top: 8 }).width('100%')
      }

      Button('导入 Cookie 并登录')
        .width('100%').height(44).margin({ top: 16 })
        .backgroundColor('#1D9BF0').fontColor('#FFFFFF')
        .onClick(() => this.submit())

      Button('使用网页登录（获取 Cookie 与接口参数）')
        .width('100%').height(44).margin({ top: 10 })
        .backgroundColor('#00000000').fontColor('#1D9BF0')
        .onClick(() => this.onWebLogin())

      Column() {
        Text('如何获取 Cookie').fontSize(13).fontWeight(FontWeight.Bold).width('100%')
        Text('1. 浏览器登录 x.com；\n2. 开发者工具 → Application → Cookies → x.com；\n3. 复制 auth_token 与 ct0，拼成一行粘贴。')
          .fontSize(12).fontColor('#536471').lineHeight(18).margin({ top: 6 }).width('100%')
      }
      .margin({ top: 24 }).padding(12).borderRadius(12).backgroundColor('#F7F9F9')

      Blank()
    }
    .width('100%').height('100%')
    .padding({ left: 20, right: 20, top: 48 })
    .alignItems(HorizontalAlign.Start)
    .backgroundColor('#FFFFFF')
  }
}
