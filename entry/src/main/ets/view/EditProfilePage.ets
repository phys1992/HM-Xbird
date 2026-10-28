import { webview } from '@kit.ArkWeb';
import { WebTheme } from '../model/WebTheme';
import { promptAction } from '@kit.ArkUI';
import { UserProfile } from '../model/UserProfile';
import { XApi } from '../api/XApi';

@Component
export struct EditProfilePage {
  cookie: string = '';
  profile: UserProfile = new UserProfile();
  onClose: () => void = () => {};
  onSaved: (profile: UserProfile) => void = () => {};
  @State ready: boolean = false;
  @State loading: boolean = true;
  @State syncing: boolean = false;
  @State error: string = '';
  @StorageProp('tuichuang_dark') isDarkTheme: boolean = false;
  controller: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    try {
      webview.WebCookieManager.configCookieSync('https://x.com', this.cookie, false, true);
      webview.WebCookieManager.configCookieSync('https://api.x.com', this.cookie, false, true);
      this.ready = true;
    } catch (e) {
      this.error = `同步登录状态失败：${e}`;
    }
  }

  private async syncAndClose(): Promise<void> {
    if (this.syncing) return;
    this.syncing = true;
    this.error = '';
    try {
      const updated = await XApi.viewerProfile(this.cookie);
      promptAction.showToast({ message: '资料已同步' });
      this.onSaved(updated);
    } catch (e) {
      this.error = `资料同步失败：${e}`;
    } finally {
      this.syncing = false;
    }
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
        Text('编辑资料').fontSize(22).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary')).margin({ left: 12 }).layoutWeight(1)
        Button(this.syncing ? '同步中…' : '完成')
          .height(34).fontSize(13)
          .enabled(!this.syncing)
          .onClick(() => this.syncAndClose())
      }.width('100%').padding({ left: 20, right: 20, top: 12, bottom: 8 })

      Text('在 X 官方页面修改资料，完成后点“完成”同步到应用。')
        .fontSize(12).fontColor($r('app.color.text_secondary'))
        .width('100%').padding({ left: 20, right: 20, bottom: 10 })

      if (this.error.length > 0) {
        Text(this.error).fontSize(12).fontColor('#F4212E')
          .width('100%').padding({ left: 20, right: 20, bottom: 8 })
      }

      if (this.ready) {
        Column() {
          if (this.loading) {
            Row() {
              LoadingProgress().width(18).height(18)
              Text('加载 X 资料编辑页…').fontSize(12).fontColor($r('app.color.text_secondary')).margin({ left: 8 })
            }.width('100%').justifyContent(FlexAlign.Center).padding(8)
          }
          Web({ src: 'https://x.com/settings/profile', controller: this.controller })
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
            .onPageBegin(() => { this.loading = true; })
            .onPageEnd(() => {
              this.loading = false;
              this.controller.runJavaScript(WebTheme.script(this.isDarkTheme)).catch(() => {});
            })
            .onErrorReceive((event) => {
              this.loading = false;
              this.error = `页面加载失败：${event.error.getErrorInfo()}`;
            })
        }
        .width('100%').layoutWeight(1)
        .margin({ left: 12, right: 12, bottom: 12 })
        .borderRadius(20).clip(true)
        .backgroundColor($r('app.color.surface'))
      } else {
        Column() {
          Text(this.error.length > 0 ? this.error : '正在准备 X 登录状态…')
            .fontSize(13).fontColor($r('app.color.text_secondary'))
            .width('100%').textAlign(TextAlign.Center).padding(20)
        }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      }
    }
    .width('100%').height('100%')
    .backgroundColor($r('app.color.grouped_bg'))
  }
}
