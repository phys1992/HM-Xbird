import { webview } from '@kit.ArkWeb';
import { WebTheme } from '../model/WebTheme';
import { SessionStore } from '../model/SessionStore';

const CAPTURE_SCRIPT = ``;

@Component
export struct LoginView {
  controller: webview.WebviewController = new webview.WebviewController();
  onLoggedIn: (cookie: string, jsUrls: string, save: boolean) => void = () => {};
  onManualLogin: () => void = () => {};
  onBack: () => void = () => {};
  @State status: string = '请在下方登录 X，成功后点“完成”';
  @State busy: boolean = false;
  @State saveAccount: boolean = true;
  @StorageProp('tuichuang_dark') isDarkTheme: boolean = false;
  private capturedUrls: string[] = [];

  private async finish(): Promise<void> {
    this.busy = true;
    try {
      const cookie = await webview.WebCookieManager.fetchCookie('https://x.com');
      if (SessionStore.cookieValue(cookie, 'auth_token').length == 0) {
        this.status = '还没拿到 auth_token，请确认已经登录成功';
        return;
      }
      await new Promise<void>((resolve) => setTimeout(resolve, 800));
      let captured = this.capturedUrls.length > 0 ? JSON.stringify(this.capturedUrls) : '[]';
      this.status = captured.length > 2 ? '已捕获接口请求与 Cookie' : '未捕获到接口请求，将尝试扫描脚本';
      this.onLoggedIn(cookie, captured.length > 2 ? captured : '[]', this.saveAccount);
    } catch (e) {
      this.status = `读取 Cookie 失败：${e}`;
    } finally {
      this.busy = false;
    }
  }

  build() {
    Column() {
      Row() {
        Text('网页登录').fontSize(22).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary')).layoutWeight(1)
        Button(this.busy ? '处理中…' : '完成')
          .height(34).fontSize(13)
          .enabled(!this.busy)
          .onClick(() => this.finish())
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 12, bottom: 8 })

      Text(this.status).fontSize(12).fontColor($r('app.color.text_secondary'))
        .width('100%').padding({ left: 20, right: 20, bottom: 8 })

      Row() {
        Text('保存此账号').fontSize(16).fontColor($r('app.color.text_primary')).layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.saveAccount })
          .onChange((value: boolean) => this.saveAccount = value)
      }
      .width('100%').padding(14).margin({ left: 20, right: 20, bottom: 10 })
      .backgroundColor($r('app.color.surface')).borderRadius(16)

      Column() {
      Web({ src: 'https://x.com/i/flow/login', controller: this.controller })
        .darkMode(this.isDarkTheme ? WebDarkMode.On : WebDarkMode.Off)
        .forceDarkAccess(this.isDarkTheme)
        .javaScriptOnDocumentStart([{ script: WebTheme.script(this.isDarkTheme), scriptRules: ['https://x.com', 'https://*.x.com'] }])
        .backgroundColor(WebTheme.background(this.isDarkTheme))
        .userAgent('Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Mobile Safari/537.36')
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .databaseAccess(true)
        .onlineImageAccess(true)
        .mixedMode(MixedMode.All)
        .width('100%')
        .layoutWeight(1)
        .onPageBegin((event) => {
          console.info(`XHLogin begin ${event.url}`);
        })
        .onInterceptRequest((event) => {
          try {
            const url = event.request.getRequestUrl();
            const marker = '/i/api/graphql/';
            const at = url.indexOf(marker);
            if (at >= 0 && this.capturedUrls.length < 24) {
              const clean = url.substring(at, url.indexOf('?', at) > 0 ? url.indexOf('?', at) : url.length);
              if (this.capturedUrls.indexOf(clean) < 0) this.capturedUrls.push(clean);
            }
          } catch (e) {}
          return null;
        })
        .onPageEnd((event) => {
          console.info(`XHLogin end ${event.url}`);
          this.controller.runJavaScript(WebTheme.script(this.isDarkTheme)).catch(() => {});
          if (event.url.indexOf('/home') >= 0) {
            this.status = '已到主页，点“完成”保存登录';
          }
          const probe = 'JSON.stringify({url:location.href,title:document.title,inputs:Array.from(document.querySelectorAll("input")).map(function(i){return {v:String(i.value).slice(0,30),t:i.type};}),buttons:Array.from(document.querySelectorAll("button")).slice(0,12).map(function(b){return {t:String(b.innerText||"").trim().slice(0,30),d:!!b.disabled};})})';
          this.controller.runJavaScript(probe).then((value: string) => {
            console.info(`XHDOM ${value}`);
          }).catch((e: Error) => {
            console.info(`XHDOM error ${e.message}`);
          });
        })
        .onConsole((event) => {
          const message = event.message.getMessage();
          console.info(`XHLoginConsole ${message}`);
          if (message.indexOf('Uncaught') >= 0 || message.indexOf('error') >= 0) {
            this.status = `页面 JS 错误：${message}`;
          }
          return false;
        })
        .onErrorReceive((event) => {
          console.info(`XHLoginError ${event.error.getErrorInfo()} ${event.request.getRequestUrl()}`);
          this.status = `资源加载失败：${event.error.getErrorInfo()}`;
        })
        .onHttpErrorReceive((event) => {
          console.info(`XHLoginHttp ${event.response.getResponseCode()} ${event.request.getRequestUrl()}`);
          this.status = `HTTP ${event.response.getResponseCode()}：${event.request.getRequestUrl()}`;
        })
      }
      .width('100%').layoutWeight(1)
      .margin({ left: 16, right: 16, bottom: 12 })
      .borderRadius(20).clip(true)
      .backgroundColor($r('app.color.surface'))
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.grouped_bg'))
  }
}
