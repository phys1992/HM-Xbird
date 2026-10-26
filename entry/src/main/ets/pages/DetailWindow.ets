import { webview } from '@kit.ArkWeb';
import { display } from '@kit.ArkUI';

@Entry
@Component
struct DetailWindow {
  @StorageLink('detailUrl') @Watch('onUrlChange') url: string = '';
  private controller: webview.WebviewController = new webview.WebviewController();

  private readonly ua: string =
    'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 ' +
    '(KHTML, like Gecko) Chrome/142.0.0.0 Mobile Safari/537.36';

  private hideChrome(): void {
    this.controller.runJavaScript(`(function(){
      var css = 'header, [data-testid="sidebarColumn"], [data-testid="BottomBar"], ' +
        '[data-testid="TopBar"], [data-testid="SideNav_AccountSwitcher_Button"], ' +
        '[data-testid="FloatingActionButtons_Tweet_Button"], ' +
        '[data-testid="FloatingActionButton"], [data-testid="SideNav_NewTweet_Button"] { display:none !important; }';
      var st = document.getElementById('xh-detail-style');
      if (!st) {
        st = document.createElement('style');
        st.id = 'xh-detail-style';
        (document.head || document.documentElement).appendChild(st);
      }
      st.textContent = css;
    })()`).catch(() => {});
  }

  onBackPress(): boolean {
    if (this.controller.accessBackward()) {
      this.controller.backward();
      return true;
    }
    return false;
  }

  onUrlChange(): void {
    if (this.url.length > 0) {
      this.controller.loadUrl(this.url);
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.url.length == 0) {
        Column() {
          Text('选择左侧推文').fontSize(16).fontColor('#536471')
          Text('这里会显示推文与评论').fontSize(12).fontColor('#8B98A5').margin({ top: 6 })
        }.width('100%').height('100%').justifyContent(FlexAlign.Center)
      } else {
        Web({ src: this.url, controller: this.controller })
          .userAgent(this.ua)
          .javaScriptAccess(true).domStorageAccess(true).databaseAccess(true)
          .onlineImageAccess(true).fileAccess(true).mixedMode(MixedMode.All).zoomAccess(true)
          .width('100%').height('100%')
          .onPageEnd(() => this.hideChrome())
          .onTouchIntercept((event: TouchEvent) => {
            if (event.type == TouchType.Down && event.touches.length > 0) {
              AppStorage.setOrCreate('barMoveSide', 2);
            }
            return HitTestMode.Default;
          })
      }
    }
    .width('100%').height('100%')
    .padding({ top: 38 })
    .backgroundColor('#FFFFFF')
  }
}
