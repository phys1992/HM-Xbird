import { webview } from '@kit.ArkWeb';
import { WebTheme } from '../model/WebTheme';
import { UserProfile } from '../model/UserProfile';
import { I18n } from '../model/I18n';

@Component
export struct EditProfilePage {
  @StorageProp('clientLang') clientLanguage: string = 'zh';
  private tr(value: string): string {
    return this.clientLanguage.length >= 0 ? I18n.t(value) : I18n.t(value);
  }

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
  private watchTimer: number = -1;
  private finished: boolean = false;

  aboutToAppear(): void {
    try {
      webview.WebCookieManager.configCookieSync('https://x.com', this.cookie, false, true);
      webview.WebCookieManager.configCookieSync('https://api.x.com', this.cookie, false, true);
      this.ready = true;
      this.startSaveWatch();
    } catch (e) {
      this.error = this.tr(`同步登录状态失败：${e}`);
    }
  }

  aboutToDisappear(): void {
    this.stopSaveWatch();
  }

  private startSaveWatch(): void {
    if (this.watchTimer >= 0) clearInterval(this.watchTimer);
    this.watchTimer = setInterval(() => {
      if (!this.ready || this.finished) return;
      this.controller.runJavaScript('window.__hmProfileSaveState || ""')
        .then((result: string) => this.onSaveState(result))
        .catch(() => {});
    }, 600);
  }

  private stopSaveWatch(): void {
    if (this.watchTimer >= 0) {
      clearInterval(this.watchTimer);
      this.watchTimer = -1;
    }
  }

  private onSaveState(result: string): void {
    const state = `${result}`.replace(/"/g, '').replace(/'/g, '').trim();
    if (state == 'saved') {
      this.finishAfterSave();
    } else if (state == 'saving') {
      this.error = '';
    } else if (state == 'failed' && this.error.length == 0) {
      this.error = this.tr('保存失败，请在页面内重试');
    }
  }

  private finishAfterSave(): void {
    if (this.finished || this.syncing) return;
    this.finished = true;
    this.syncing = true;
    this.stopSaveWatch();
    setTimeout(() => {
      this.onClose();
    }, 50);
  }

  private saveWatchScript(): string {
    return `(function () {
  if (window.__hmProfileHooked) return;
  window.__hmProfileHooked = true;
  window.__hmProfileSaveState = 'idle';

  var markSaving = function () {
    if (window.__hmProfileSaveState !== 'saved') {
      window.__hmProfileSaveState = 'saving';
    }
  };
  var markSaved = function () {
    window.__hmProfileSaveState = 'saved';
  };
  var markFailed = function () {
    if (window.__hmProfileSaveState !== 'saved') {
      window.__hmProfileSaveState = 'failed';
    }
  };

  document.addEventListener('click', function (event) {
    var target = event.target;
    if (!target) return;
    var button = target.closest ? target.closest('[data-testid="ProfileSaveButton"]') : null;
    if (!button) {
      var buttons = document.querySelectorAll('[role="button"], button');
      for (var i = 0; i < buttons.length; i++) {
        var text = (buttons[i].textContent || '').trim().toLowerCase();
        if ((text === 'save' || text === '保存' || text === '存储') &&
            (buttons[i] === target || (buttons[i].contains && buttons[i].contains(target)))) {
          button = buttons[i];
          break;
        }
      }
    }
    if (button) markSaving();
  }, true);

  var originalFetch = window.fetch;
  if (originalFetch) {
    window.fetch = function (input, init) {
      var url = typeof input === 'string' ? input : ((input && input.url) || '');
      var body = init && typeof init.body === 'string' ? init.body : '';
      var isUpdate = /UpdateProfile|update_profile|ProfileUpdate/i.test(url + ' ' + body);
      var request = originalFetch.apply(this, arguments);
      return request.then(function (response) {
        if (isUpdate) {
          response.clone().json().then(function (data) {
            if (data && data.errors && data.errors.length) markFailed();
            else markSaved();
          }).catch(function () {
            if (response.ok) markSaved();
            else markFailed();
          });
        }
        return response;
      }).catch(function (error) {
        if (isUpdate) markFailed();
        throw error;
      });
    };
  }

  var originalOpen = XMLHttpRequest.prototype.open;
  var originalSend = XMLHttpRequest.prototype.send;
  var xhrUrl = '';
  XMLHttpRequest.prototype.open = function (method, url) {
    xhrUrl = String(url || '');
    return originalOpen.apply(this, arguments);
  };
  XMLHttpRequest.prototype.send = function () {
    var xhr = this;
    xhr.addEventListener('load', function () {
      if (/UpdateProfile|update_profile|ProfileUpdate/i.test(xhrUrl)) {
        if (xhr.status >= 200 && xhr.status < 300) markSaved();
        else markFailed();
      }
    });
    return originalSend.apply(this, arguments);
  };

  var observer = new MutationObserver(function () {
    if (window.__hmProfileSaveState !== 'saving') return;
    var nodes = document.querySelectorAll('[role="alert"], [data-testid="toast"]');
    for (var i = 0; i < nodes.length; i++) {
      var text = nodes[i].textContent || '';
      if (/updated|saved|保存成功|已更新|已保存/i.test(text)) {
        markSaved();
        return;
      }
    }
  });
  var attachObserver = function () {
    if (!document.documentElement) {
      document.addEventListener('DOMContentLoaded', attachObserver, { once: true });
      return;
    }
    observer.observe(document.documentElement, { childList: true, subtree: true, characterData: true });
  };
  attachObserver();
})();`;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.ready) {
        Web({ src: 'https://x.com/settings/profile', controller: this.controller })
          .darkMode(this.isDarkTheme ? WebDarkMode.On : WebDarkMode.Off)
          .forceDarkAccess(this.isDarkTheme)
          .javaScriptOnDocumentStart([
            { script: WebTheme.script(this.isDarkTheme), scriptRules: ['https://x.com', 'https://*.x.com'] },
            { script: this.saveWatchScript(), scriptRules: ['https://x.com', 'https://*.x.com'] }
          ])
          .backgroundColor(WebTheme.background(this.isDarkTheme))
          .userAgent('Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Mobile Safari/537.36')
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .databaseAccess(true)
          .onlineImageAccess(true)
          .mixedMode(MixedMode.All)
          .width('100%').height('100%')
          .onPageBegin(() => {
            this.loading = true;
            this.error = '';
          })
          .onPageEnd(() => {
            this.loading = false;
            this.controller.runJavaScript(WebTheme.script(this.isDarkTheme)).catch(() => {});
          })
          .onErrorReceive((event) => {
            this.loading = false;
            this.error = this.tr(`页面加载失败：${event.error.getErrorInfo()}`);
          })

        if (this.loading) {
          Row() {
            LoadingProgress().width(18).height(18)
            Text(this.tr('加载 X 资料编辑页…')).fontSize(12)
              .fontColor($r('app.color.text_secondary')).margin({ left: 8 })
          }
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .backgroundColor($r('app.color.surface'))
          .borderRadius(16)
          .position({ x: 20, y: 20 })
        }

        if (this.error.length > 0) {
          Text(this.error).fontSize(12).fontColor('#FFFFFF')
            .backgroundColor('#E5484D').padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .borderRadius(12).position({ x: 20, y: 20 })
        }
      } else {
        Column() {
          LoadingProgress().width(28).height(28)
          Text(this.error.length > 0 ? this.error : this.tr('正在准备 X 登录状态…'))
            .fontSize(13).fontColor($r('app.color.text_secondary'))
            .width('100%').textAlign(TextAlign.Center).padding(20)
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      }
    }
    .width('100%').height('100%')
    .backgroundColor(this.isDarkTheme ? '#000000' : $r('app.color.grouped_bg'))
  }
}
