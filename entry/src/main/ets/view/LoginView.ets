import { webview } from '@kit.ArkWeb';
import { SessionStore } from '../model/SessionStore';

const CAPTURE_SCRIPT = `(function(){
  if (window.__xGql) return;
  window.__xGql = [];
  function push(u){ try { var s = String(u); var i = s.indexOf('/i/api/graphql/'); if (i >= 0) window.__xGql.push(s.substring(i)); } catch(e){} }
  var of = window.fetch;
  if (of) { window.fetch = function(input){ try { push(typeof input === 'string' ? input : (input && input.url)); } catch(e){} return of.apply(this, arguments); }; }
  var oo = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function(method, url){ try { push(url); } catch(e){} return oo.apply(this, arguments); };
})();`;

@Component
export struct LoginView {
  controller: webview.WebviewController = new webview.WebviewController();
  onLoggedIn: (cookie: string, jsUrls: string) => void = () => {};
  @State status: string = '请在下方登录 X，成功后点“完成”';
  @State busy: boolean = false;

  private async finish(): Promise<void> {
    this.busy = true;
    try {
      const cookie = await webview.WebCookieManager.fetchCookie('https://x.com');
      if (SessionStore.cookieValue(cookie, 'auth_token').length == 0) {
        this.status = '还没拿到 auth_token，请确认已经登录成功';
        return;
      }
      // Give the home timeline a moment to issue its GraphQL request so the
      // document-start hook can record the real URL (which contains queryId).
      await new Promise<void>((resolve) => setTimeout(resolve, 1500));
      let captured = '';
      for (let attempt = 0; attempt < 2; attempt++) {
        try {
          const raw = await this.controller.runJavaScript(
            'JSON.stringify((window.__xGql && window.__xGql.length) ? window.__xGql : [])'
          ) as string;
          let value = raw;
          if (value.startsWith('"') && value.endsWith('"')) {
            value = JSON.parse(value) as string;
          }
          if (value.startsWith('[')) {
            captured = value;
          }
        } catch (e) {
          this.status = `读取 GraphQL 请求失败：${e}`;
        }
        if (captured.length > 2) break;
        await new Promise<void>((resolve) => setTimeout(resolve, 1500));
      }
      this.status = captured.length > 2 ? '已捕获接口请求与 Cookie' : '未捕获到接口请求，将尝试扫描脚本';
      this.onLoggedIn(cookie, captured.length > 2 ? captured : '[]');
    } catch (e) {
      this.status = `读取 Cookie 失败：${e}`;
    } finally {
      this.busy = false;
    }
  }

  build() {
    Column() {
      Row() {
        Text(this.status)
          .fontSize(12)
          .fontColor('#666')
          .layoutWeight(1)
        Button(this.busy ? '处理中…' : '完成')
          .height(32)
          .enabled(!this.busy)
          .onClick(() => this.finish())
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })

      Web({ src: 'https://x.com/i/flow/login', controller: this.controller })
        .userAgent('Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Mobile Safari/537.36')
        .javaScriptOnDocumentStart([{ script: CAPTURE_SCRIPT, scriptRules: ['*'] }])
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .databaseAccess(true)
        .onlineImageAccess(true)
        .mixedMode(MixedMode.All)
        .width('100%')
        .layoutWeight(1)
        .onPageEnd((event) => {
          if (event.url.indexOf('/home') >= 0) {
            this.status = '已到主页，点“完成”保存登录';
          }
        })
        .onConsole((event) => {
          const message = event.message.getMessage();
          if (message.indexOf('Uncaught') >= 0 || message.indexOf('error') >= 0) {
            this.status = `页面 JS 错误：${message}`;
          }
          return false;
        })
        .onErrorReceive((event) => {
          this.status = `资源加载失败：${event.error.getErrorInfo()}`;
        })
        .onHttpErrorReceive((event) => {
          this.status = `HTTP ${event.response.getResponseCode()}：${event.request.getRequestUrl()}`;
        })
    }
    .width('100%')
    .height('100%')
  }
}
