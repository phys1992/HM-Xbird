import { webview } from '@kit.ArkWeb';
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { display, window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { SessionStore } from '../model/SessionStore';
import { ComposeView } from './ComposeView';
import { BackDispatcher } from '../model/BackDispatcher';
import { WindowBridge } from '../model/WindowBridge';

class WebBridge {
  onOpenTweet: (url: string) => void = () => {};
  onOpenMe: () => void = () => {};
  onPath: (path: string) => void = () => {};
  onPrefetch: (url: string) => void = () => {};
  onDom: (json: string) => void = () => {};
  onSwipeTab: (dir: number) => void = () => {};

  openTweet(url: string): void {
    this.onOpenTweet(url);
  }

  openMe(): void {
    this.onOpenMe();
  }

  reportPath(path: string): void {
    this.onPath(path);
  }

  prefetch(url: string): void {
    this.onPrefetch(url);
  }

  reportDom(json: string): void {
    this.onDom(json);
  }

  swipeTab(dir: number): void {
    this.onSwipeTab(dir);
  }
}

/**
 * ArkWeb shell with a native bottom bar and a foldable two-pane layout.
 *
 * Left pane: normal X feed. Right pane: the selected post URL (post + replies).
 * Both are independent Web views. On large foldables (Mate X5/X7/XT/XT2) the
 * layout switches to two panes once the window is wider than 600vp.
 */
@Component
export struct WebShell {
  private leftController: webview.WebviewController = new webview.WebviewController();
  private rightController: webview.WebviewController = new webview.WebviewController();
  private auxController: webview.WebviewController = new webview.WebviewController();
  private followingController: webview.WebviewController = new webview.WebviewController();
  @State composeCookie: string = '';
  private bridge: WebBridge = new WebBridge();
  private followingBridge: WebBridge = new WebBridge();
  private swiperController: SwiperController = new SwiperController();

  @State progress: number = 0;
  @State tab: number = 0;
  @State loggedIn: boolean = false;
  @State showCompose: boolean = false;
  @State selectedUrl: string = '';
  @State viewportWidth: number = 360;
  @State viewportHeight: number = 0;
  @State screenWidthVp: number = 400;
  @State leftFraction: number = 1.0;
  @State isFoldModel: boolean = false;
  @State isExpanded: boolean = false;
  @State foldAngle: number = 180;
  @State splitRatio: number = 0.5;
  @State paneCollapsed: boolean = false;
  @State rowWidth: number = 0;
  @State leftWidth: number = 0;
  @State currentPath: string = '/home';
  @State webReady: boolean = false;
  @State auxPath: string = '';
  @State auxLoaded: boolean = false;
  @State followingLoaded: boolean = false;
  @State followingPath: string = '/home';
  @State foldedDetail: boolean = false;
  @State domInfo: string = '';
  @State statusBarVp: number = 0;
  @State feedAlpha: number = 1;
  @State feedShift: number = 0;
  @State homeIndex: number = 0;
  @State leftReady: boolean = false;
  @State splitEnabled: boolean = true;
  @State @Watch('onMeChanged') showMe: boolean = false;
  @StorageLink('barMoveSide') @Watch('onBarMoveSide') barMoveSide: number = 1;
  @StorageLink('barActionTick') @Watch('onBarAction') barActionTick: number = 0;
  @StorageLink('barAction') barAction: string = '';
  @StorageLink('backTick') @Watch('onBackTick') backTick: number = 0;
  @StorageLink('memoryTrimTick') @Watch('onMemoryTrim') memoryTrimTick: number = 0;
  @State showSplitSettings: boolean = false;
  @State barMode: number = 1;
  @State barX: number = 0;
  private readonly barW: number = 320;
  @State ownHandle: string = '';
  private dragStartRatio: number = 0.5;
  private dragOvershoot: number = 0;

  private readonly chromeUa: string =
    'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 ' +
    '(KHTML, like Gecko) Chrome/142.0.0.0 Mobile Safari/537.36';

  aboutToDisappear(): void {
    try {
      display.off('foldAngleChange');
      display.off('foldStatusChange');
    } catch (e) {}
  }

  aboutToAppear(): void {
    BackDispatcher.handler = () => this.handleBack();
    AppStorage.setOrCreate('barMoveSide', 1);
    AppStorage.setOrCreate('backTick', 0);
    AppStorage.setOrCreate('barActive', 0);
    const context = getContext(this) as common.UIAbilityContext;
    try {
      const d = display.getDefaultDisplaySync();
      this.viewportHeight = d.height / (d.densityPixels > 0 ? d.densityPixels : 3);
    } catch (e) {}
    window.getLastWindow(context).then((win) => {
      try {
        const area = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
        this.statusBarVp = px2vp(area.topRect.height);
      } catch (e) {}
    });
    try {
      const d = display.getDefaultDisplaySync();
      this.screenWidthVp = d.width / (d.densityPixels > 0 ? d.densityPixels : 3);
    } catch (e) {}
    // Older builds persisted ratios outside the current 30–70 constraint.
    // Diagnostic: force 50/50 to separate ratio-state problems from ArkWeb
    // layout problems. Re-enable persistence once the pane sizing is verified.
    this.splitRatio = 0.5;
    SessionStore.saveSplitRatio(context, 0.5);
    // productModel is often the model code (e.g. DEL-AL10); marketName and
    // productModelAlias carry the marketing name (Mate X7).
    const model = `${deviceInfo.productModel} ${deviceInfo.marketName} ${deviceInfo.productModelAlias}`.toLowerCase();
    const code = deviceInfo.productModel.toUpperCase();
    // Huawei foldable model-code families (productModel is usually the code,
    // e.g. DEL-AL10 for Mate X7, not the marketing name):
    //   ALT- Mate X3 / X5
    //   DEL- Mate X7
    //   GRL- Mate XT / XT2
    //   ICL- Mate X6
    //   TET- Mate X2
    //   TAH- Mate X / Xs
    //   PXA- Pura X (wide fold)
    const foldCodes = ['ALT-', 'DEL-', 'GRL-', 'ICL-', 'TET-', 'TAH-', 'PXA-'];
    let byCode = false;
    for (const prefix of foldCodes) {
      if (code.startsWith(prefix)) {
        byCode = true;
        break;
      }
    }
    this.isFoldModel = byCode ||
      model.indexOf('mate x5') >= 0 || model.indexOf('mate x7') >= 0 ||
      model.indexOf('mate xt') >= 0 || model.indexOf('mate xt2') >= 0 ||
      model.indexOf('matex5') >= 0 || model.indexOf('matex7') >= 0 ||
      model.indexOf('pura x') >= 0;
    if (!this.isFoldModel) {
      try {
        // Fallback: any foldable panel that is currently wide enough should
        // still get the two-pane layout, even if the marketing name changes.
        this.isFoldModel = display.isFoldable();
      } catch (e) {
        this.isFoldModel = false;
      }
    }
    if (this.isFoldModel) {
      try {
        const status = display.getFoldStatus();
        this.isExpanded = status == display.FoldStatus.FOLD_STATUS_EXPANDED;
        this.foldAngle = this.isExpanded ? 180 : 0;
        display.on('foldAngleChange', (angles: Array<number>) => this.onFoldAngle(angles));
        display.on('foldStatusChange', (status: number) => this.onFoldStatus(status));
      } catch (e) {
        this.isExpanded = this.viewportWidth >= 600;
      }
      this.leftFraction = this.isExpanded ? 0.5 : 1.0;
      // Let onAreaChange provide the real width; no synthetic value on launch.
    }
    this.bridge.onOpenMe = () => {
      this.openMe();
    };
    this.bridge.onPath = (path: string) => {
      if (path.length > 0) this.currentPath = path;
    };
    this.followingBridge.onOpenMe = () => this.openMe();
    this.followingBridge.onOpenTweet = (url: string) => {
      if (!this.splitEnabled) {
        this.followingController.loadUrl(url);
      } else if (this.isExpanded) {
        this.selectedUrl = url;
        this.rightController.loadUrl(url);
      } else {
        this.selectedUrl = url;
        this.rightController.loadUrl(url);
        this.foldedDetail = true;
      }
    };
    this.followingBridge.onPath = (path: string) => {
      if (path.length > 0) this.followingPath = path;
    };
    this.followingBridge.onSwipeTab = (dir: number) => {};
    this.bridge.onPrefetch = (url: string) => this.prefetchDetail(url);
    this.bridge.onDom = (json: string) => {
      console.info('XHDOM', json);
    };
    this.bridge.onSwipeTab = (dir: number) => {};
    this.bridge.onOpenTweet = (url: string) => {
      if (!this.splitEnabled) {
        this.leftController.loadUrl(url);
      } else if (this.isExpanded) {
        this.selectedUrl = url;
        this.rightController.loadUrl(url);
      } else {
        this.selectedUrl = url;
        this.rightController.loadUrl(url);
        this.foldedDetail = true;
      }
    };
  }

  private lastPrefetchAt: number = 0;
  private prefetched: Set<string> = new Set<string>();
  private prefetchOrder: string[] = [];

  private keepRightAnchor(): void {
    this.rightController.runJavaScript(`(function(){
      var arts = document.querySelectorAll('article');
      for (var i = 0; i < arts.length; i++) {
        var r = arts[i].getBoundingClientRect();
        if (r.bottom > 80) {
          var a = arts[i].querySelector('a[href*="/status/"]');
          window.__xhAnchor = a ? a.href : '';
          return;
        }
      }
      window.__xhAnchor = '';
    })()`).catch(() => {});
  }

  private repairWebChrome(): void {
    const js = 'if(window.__xhHideFixedHeader)window.__xhHideFixedHeader();';
    this.leftController.runJavaScript(js).catch(() => {});
    this.followingController.runJavaScript(js).catch(() => {});
  }

  private earlyCssScript(): string {
    return `(function(){var s=document.createElement('style');s.id='xh-early';s.textContent='header,[data-testid="TopBar"],[role="tablist"],[aria-label*="Add"],[aria-label*="添加"],div:has(> [role="tablist"]){display:none!important;}';if(document.head){document.head.appendChild(s);}else{document.documentElement.appendChild(s);}})();`;
  }

  private animateTabSwitch(dir: number, action: () => void): void {
    const shift = dir == 0 ? 0 : (dir < 0 ? -28 : 28);
    animateTo({ duration: 140, curve: Curve.EaseIn }, () => {
      this.feedAlpha = 0.25;
      this.feedShift = shift;
    });
    setTimeout(() => {
      action();
      animateTo({ duration: 260, curve: Curve.EaseOut }, () => {
        this.feedAlpha = 1;
        this.feedShift = 0;
      });
    }, 140);
  }

  private swipeHome(dir: number): void {
    if (this.tab != 0) return;
    const next = (this.homeIndex + dir + 2) % 2;
    // changeIndex(..., true) uses Swiper's own duration/curve animation.
    this.swiperController.changeIndex(next, true);
  }

  private switchHomeTab(dir: number): void {
    if (this.tab != 0) return;
    const js = `(function(){
      var tabs = Array.prototype.slice.call(document.querySelectorAll('[role="tab"]'));
      tabs = tabs.filter(function(t){ return t.offsetParent !== null; });
      if (tabs.length < 2) return;
      var idx = -1;
      for (var i = 0; i < tabs.length; i++) {
        if (tabs[i].getAttribute('aria-selected') === 'true') { idx = i; break; }
      }
      if (idx < 0) idx = 0;
      var next = (idx + (${dir}) + tabs.length) % tabs.length;
      tabs[next].click();
    })()`;
    this.animateTabSwitch(dir, () => {
      this.leftController.runJavaScript(js).catch(() => {});
    });
  }

  private dumpTopDom(): void {
    this.leftController.runJavaScript(`(function(){
      var tab = null;
      var nodes = document.querySelectorAll('div, span');
      for (var i = 0; i < nodes.length; i++) {
        var t = (nodes[i].textContent || '').trim();
        if (t.indexOf('为你推荐') === 0 && t.length < 40) { tab = nodes[i]; break; }
      }
      var chain = [];
      if (tab) {
        var p = tab;
        for (var d = 0; d < 6 && p; d++) {
          var r = p.getBoundingClientRect();
          var cs = window.getComputedStyle(p);
          chain.push(p.tagName + '.' + String(p.className).slice(0, 40) +
            ' top=' + Math.round(r.top) + ' h=' + Math.round(r.height) +
            ' pos=' + cs.position + ' mt=' + cs.marginTop + ' pt=' + cs.paddingTop);
          p = p.parentElement;
        }
      }
      return 'W' + innerWidth + ' H' + innerHeight + ' TAB ' + (tab ? Math.round(tab.getBoundingClientRect().top) : -1) +
        ' || ' + chain.join(' || ');
    })()`).then((info: string) => {
      this.domInfo = info;
      hilog.info(0x0000, 'XHDOM', '%{public}s', info);
      console.info('XHDOM', info);
    }).catch((e: Error) => {
      this.domInfo = 'ERR ' + e;
      hilog.error(0x0000, 'XHDOM', '%{public}s', String(e));
    });
  }

  private keepLeftAnchor(): void {
    this.leftController.runJavaScript(`(function(){
      var arts = document.querySelectorAll('article');
      for (var i = 0; i < arts.length; i++) {
        var r = arts[i].getBoundingClientRect();
        if (r.bottom > 80) {
          var a = arts[i].querySelector('a[href*="/status/"]');
          window.__xhLeftAnchor = a ? a.href : '';
          return;
        }
      }
    })()`).catch(() => {});
  }

  private restoreLeftAnchor(): void {
    setTimeout(() => {
      this.leftController.runJavaScript(`(function(){
        if (!window.__xhLeftAnchor) return;
        var links = document.querySelectorAll('a[href*="/status/"]');
        for (var i = 0; i < links.length; i++) {
          if (links[i].href === window.__xhLeftAnchor) {
            var art = links[i].closest('article');
            if (art) art.scrollIntoView({ block: 'start' });
            return;
          }
        }
      })()`).catch(() => {});
    }, 550);
  }

  private restoreRightAnchor(): void {
    setTimeout(() => {
      this.rightController.runJavaScript(`(function(){
        if (!window.__xhAnchor) return;
        var links = document.querySelectorAll('a[href*="/status/"]');
        for (var i = 0; i < links.length; i++) {
          if (links[i].href === window.__xhAnchor) {
            var art = links[i].closest('article');
            if (art) art.scrollIntoView({ block: 'start' });
            return;
          }
        }
      })()`).catch(() => {});
    }, 550);
  }

  private prefetchDetail(url: string): void {
    if (this.prefetched.has(url)) return;
    const now = Date.now();
    if (now - this.lastPrefetchAt < 500) return;
    this.lastPrefetchAt = now;
    if (this.prefetched.size >= 20) {
      const oldest = this.prefetchOrder.shift();
      if (oldest != undefined) this.prefetched.delete(oldest);
    }
    this.prefetched.add(url);
    this.prefetchOrder.push(url);
    this.leftController.prefetchPage(url);
  }

  private onMemoryTrim(): void {
    try { this.leftController.removeCache(false); } catch (e) {}
    try { this.rightController.removeCache(false); } catch (e) {}
    try { this.auxController.removeCache(false); } catch (e) {}
    this.prefetched.clear();
    this.prefetchOrder = [];
    this.lastPrefetchAt = 0;
  }

  private applyHalfWidthCss(): void {}

  private clearHalfWidthCss(): void {}

  private onFoldAngle(angles: Array<number>): void {
    if (angles == undefined || angles.length == 0) return;
    const angle = angles[0];
    if (angle < 0 || angle > 180) return;
    this.foldAngle = angle;
    const expanded = angle > 90;
    if (expanded != this.isExpanded) {
      this.keepLeftAnchor();
      this.keepRightAnchor();
      this.restoreLeftAnchor();
      this.restoreRightAnchor();
    }
    if (!expanded) {
      // Always recenter on every folded event, not only on the transition.
      this.barMode = 1;
      AppStorage.setOrCreate('barSide', 1);
      WindowBridge.positionBar(1);
      setTimeout(() => WindowBridge.positionBar(1), 300);
      setTimeout(() => WindowBridge.positionBar(1), 900);
    }
    if (expanded == this.isExpanded) return;
    this.isExpanded = expanded;
    this.leftFraction = expanded ? 0.5 : 1.0;
    if (!expanded) {
      this.foldedDetail = this.selectedUrl.length > 0;
    } else {
      this.foldedDetail = false;
    }
    this.leftReady = false;
    setTimeout(() => this.repairWebChrome(), 350);
    setTimeout(() => this.repairWebChrome(), 900);
    setTimeout(() => this.repairWebChrome(), 1600);
    setTimeout(() => this.repairWebChrome(), 2600);
    setTimeout(() => { this.leftReady = true; }, 1200);
    this.leftController.runJavaScript(`window.__xhTwoPane = ${expanded};`).catch(() => {});
  }

  private onFoldStatus(status: number): void {
    // Angle is authoritative; status events are only a fallback for devices
    // that do not emit foldAngleChange.
    const expanded = status == display.FoldStatus.FOLD_STATUS_EXPANDED;
    if (expanded != this.isExpanded) {
      this.keepLeftAnchor();
      this.keepRightAnchor();
      this.restoreLeftAnchor();
      this.restoreRightAnchor();
    }
    if (!expanded) {
      this.barMode = 1;
      AppStorage.setOrCreate('barSide', 1);
      WindowBridge.positionBar(1);
      setTimeout(() => WindowBridge.positionBar(1), 300);
      setTimeout(() => WindowBridge.positionBar(1), 900);
    }
    if (expanded == this.isExpanded) return;
    this.isExpanded = expanded;
    if (this.webReady) {
      this.leftController.runJavaScript(`window.__xhTwoPane = ${this.isExpanded};`).catch(() => {});
    }
    animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
      this.leftFraction = this.isExpanded ? 0.5 : 1.0;
    });
    if (!this.isExpanded) {
      this.barMode = 1;
      this.updateBarX();
      AppStorage.setOrCreate('barSide', 1);
      WindowBridge.positionBar(1);
      this.foldedDetail = this.selectedUrl.length > 0;
    } else {
      this.foldedDetail = false;
    }
    this.leftReady = false;
    setTimeout(() => this.repairWebChrome(), 350);
    setTimeout(() => this.repairWebChrome(), 900);
    setTimeout(() => this.repairWebChrome(), 1600);
    setTimeout(() => this.repairWebChrome(), 2600);
    setTimeout(() => { this.leftReady = true; }, 1200);
  }

  private async openCompose(): Promise<void> {
    try {
      this.composeCookie = await webview.WebCookieManager.fetchCookie('https://x.com');
    } catch (e) {
      promptAction.showToast({ message: `读取登录态失败：${e}` });
      return;
    }
    animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
      this.showCompose = true;
    });
  }

  private moveBarTo(target: number): void {
    if (!this.isExpanded) return;
    // Keep the shared side in sync so the next cross-window touch is a real
    // state change (StorageLink only fires when the value changes).
    AppStorage.setOrCreate('barMoveSide', target);
    AppStorage.setOrCreate('barSide', target);
    WindowBridge.moveBar(target);
    if (target == this.barMode) return;
    animateTo({ duration: 300, curve: Curve.Friction }, () => {
      this.barMode = target;
      this.updateBarX();
    });
  }

  private updateBarX(): void {
    const w = this.viewportWidth;
    const mode = this.isExpanded ? this.barMode : 1;
    let x = (w - this.barW) / 2;
    if (this.isExpanded && mode == 0) x = 12;
    if (this.isExpanded && mode == 2) x = w - this.barW - 12;
    this.barX = Math.max(8, x);
  }

  private get twoPane(): boolean {
    return this.isFoldModel && this.isExpanded && this.splitEnabled && !this.paneCollapsed;
  }

  private get minRatio(): number {
    return 0.3;
  }

  private get maxRatio(): number {
    return 0.7;
  }

  private saveRatio(): void {
    SessionStore.saveSplitRatio(getContext(this) as common.UIAbilityContext, this.splitRatio);
  }

  private hideCss(): string {
    return `
      html, body, #react-root, main, [role="main"],
      [data-testid="primaryColumn"] {
        padding-bottom: 0 !important;
        margin-bottom: 0 !important;
      }
      header[role="banner"], [data-testid="sidebarColumn"],
      [data-testid="BottomBar"], [data-testid="bottom-bar"] { display: none !important; }
      a[href="/messages"], a[href="/i/grok"], a[href="/grok"],
      a[href="/i/calls"], a[href*="/calls"],
      a[href="/i/lists"], a[href^="/i/lists/"],
      a[href="/i/communities"], a[href^="/i/communities/"],
      a[href="/i/premium_sign_up"], a[href^="/i/premium"],
      a[href^="/i/creator_studio"], a[href^="/i/business"], a[href^="/i/ads"],
      a[href^="/i/spaces/start"], a[href="/settings"], a[href^="/settings"],
      a[href="/compose/post"], a[href*="/compose/post"],
      [data-testid="toolBar"],
      [data-testid="tweetButtonInline"], [data-testid="tweetTextarea_0"] {
        display: none !important;
      }
    `;
  }

  private injectUi(controller: webview.WebviewController, captureTweets: boolean, hideComposer: boolean = true): void {
    const css = JSON.stringify(this.hideCss());
    const script = `(function(){
      window.__xhNoComposerHide = ${!hideComposer};
      window.__xhStatusBar = ${this.statusBarVp};
      window.__xhHideFixedHeader = function(){
        var tab = null;
        var nodes = document.querySelectorAll('div, span');
        for (var i = 0; i < nodes.length; i++) {
          var t = (nodes[i].textContent || '').trim();
          if (t.indexOf('为你推荐') === 0 && t.length < 40) { tab = nodes[i]; break; }
        }
        if (!tab) return;
        var row = tab;
        for (var r = 0; r < 6 && row; r++) {
          var rr = row.getBoundingClientRect();
          if (rr.height >= 30 && rr.height <= 90 && rr.width > 200 &&
              !row.querySelector('article')) {
            row.style.setProperty('display', 'none', 'important');
            break;
          }
          row = row.parentElement;
        }
        var h = tab;
        for (var d = 0; d < 8 && h; d++) {
          var cs = window.getComputedStyle(h);
          if ((cs.position === 'fixed' || cs.position === 'sticky') &&
              !h.querySelector('article')) {
            h.style.setProperty('display', 'none', 'important');
            break;
          }
          h = h.parentElement;
        }
        if (!window.__xhHeaderObs) {
          window.__xhHeaderObs = new MutationObserver(function(){ window.__xhHideFixedHeader(); });
          window.__xhHeaderObs.observe(document.body, { childList: true, subtree: true });
        }
      };
      window.__xhHideFixedHeader();
      setTimeout(window.__xhHideFixedHeader, 900);
      setTimeout(window.__xhHideFixedHeader, 2200);
      window.__xhLiftHeader = function(){
        var tab = null;
        var nodes = document.querySelectorAll('div, span');
        for (var i = 0; i < nodes.length; i++) {
          var t = (nodes[i].textContent || '').trim();
          if (t.indexOf('为你推荐') === 0 && t.length < 40) { tab = nodes[i]; break; }
        }
        if (!tab) return;
        var shift = Math.round(tab.getBoundingClientRect().top);
        if (shift < 4) return;
        var header = tab;
        for (var d = 0; d < 8 && header; d++) {
          if (window.getComputedStyle(header).position === 'fixed') break;
          header = header.parentElement;
        }
        if (!header) return;
        header.style.setProperty('top', '-' + shift + 'px', 'important');
        header.style.setProperty('transform', 'none', 'important');
        header.style.setProperty('height', '101px', 'important');
        header.style.setProperty('overflow', 'visible', 'important');
        var tabsRow = tab;
        for (var tr = 0; tr < 6 && tabsRow; tr++) {
          var trr = tabsRow.getBoundingClientRect();
          if (trr.height >= 40 && trr.height <= 70) { tabsRow.style.setProperty('transform', 'none', 'important'); break; }
          tabsRow = tabsRow.parentElement;
        }

        var col = document.querySelector('[data-testid="primaryColumn"]');
        if (!col) {
          var art = document.querySelector('article');
          if (art) {
            var p = art;
            for (var k = 0; k < 10 && p; k++) {
              var r = p.getBoundingClientRect();
              if (r.height > 300 && r.top >= shift - 5) { col = p; break; }
              p = p.parentElement;
            }
          }
        }
        if (col) {
          col.style.setProperty('margin-top', '-' + shift + 'px', 'important');
          // Keep the first article below the detached tab bar (51px).
          var art3 = document.querySelector('article');
          if (art3) {
            var firstTop = art3.getBoundingClientRect().top;
            if (firstTop < 51) {
              var cur = parseFloat(col.style.marginTop) || 0;
              col.style.setProperty('margin-top', (cur + (51 - firstTop)) + 'px', 'important');
            }
          }
        }
        try {
          var art2 = document.querySelector('article');
          if (window.xharmony && window.xharmony.reportDom) {
            window.xharmony.reportDom(JSON.stringify({
              stage: 'lift', tab: Math.round(tab.getBoundingClientRect().top),
              headerTop: header.style.top,
              headerH: Math.round(header.getBoundingClientRect().height),
              col: col ? String(col.className).slice(0, 50) : 'NONE',
              colMargin: col ? col.style.marginTop : 'NONE',
              first: art2 ? Math.round(art2.getBoundingClientRect().top) : -1
            }));
          }
        } catch (e) {}
      };
      if (!document.getElementById('xh-style')) {
        var style = document.createElement('style');
        style.id = 'xh-style';
        style.textContent = ${css};
        document.head.appendChild(style);
      }
      var chrome = 'header[role="banner"], [data-testid="TopBar"], ' +
        '[data-testid="SideNav_AccountSwitcher_Button"], [data-testid="AppTabBar_Profile_Link"], ' +
        '[data-testid="FloatingActionButtons_Tweet_Button"], [data-testid="FloatingActionButton"], ' +
        '[data-testid="SideNav_NewTweet_Button"], [data-testid="BottomBar"], a[aria-label="X"], ' +
        'a[href="/compose/post"], a[href*="/compose/post"]';
      function hideChrome(){
        var nodes = document.querySelectorAll(chrome);
        for (var i = 0; i < nodes.length; i++) nodes[i].style.display = 'none';
        var logo = document.querySelector('a[aria-label="X"], a[href="/home"] svg');
        if (logo) {
          var p = logo;
          for (var j = 0; j < 10 && p && p.parentElement; j++) {
            p = p.parentElement;
            var r = p.getBoundingClientRect();
            if (r.height > 30 && r.height < 120 && r.width > window.innerWidth * 0.8) {
              p.style.display = 'none';
              break;
            }
          }
        }
        var acct = document.querySelector('[data-testid="SideNav_AccountSwitcher_Button"], [aria-label="Account menu"]');
        if (acct) acct.style.display = 'none';

        // Top-left avatar image (not inside a testid button).
        var imgs = document.querySelectorAll('img');
        for (var k = 0; k < imgs.length; k++) {
          var ir = imgs[k].getBoundingClientRect();
          if (ir.top < 110 && ir.left < 110 && ir.width > 20 && ir.width < 70) {
            var ip = imgs[k];
            for (var m = 0; m < 8 && ip && ip.parentElement; m++) {
              ip = ip.parentElement;
              var pr = ip.getBoundingClientRect();
              if (pr.height > 30 && pr.height < 130 && pr.width > window.innerWidth * 0.8) {
                ip.style.display = 'none';
                break;
              }
              if (ip.tagName === 'A' || ip.tagName === 'BUTTON') {
                ip.style.display = 'none';
              }
            }
          }
        }

        // X logo SVG near the top center.
        var svgs = document.querySelectorAll('svg');
        for (var n = 0; n < svgs.length; n++) {
          var sr = svgs[n].getBoundingClientRect();
          if (sr.top < 120 && sr.width > 20 && sr.width < 60 &&
              sr.left > window.innerWidth / 2 - 100 && sr.left < window.innerWidth / 2 + 100) {
            var sp = svgs[n];
            for (var q = 0; q < 10 && sp && sp.parentElement; q++) {
              sp = sp.parentElement;
              var rr = sp.getBoundingClientRect();
              if (rr.height > 30 && rr.height < 120 && rr.width > window.innerWidth * 0.8) {
                sp.style.display = 'none';
                sp.style.height = '0';
                sp.style.minHeight = '0';
                sp.style.margin = '0';
                sp.style.padding = '0';
                sp.style.overflow = 'hidden';
                break;
              }
            }
          }
        }
        if (!window.__xhMeHooked) {
          window.__xhMeHooked = true;
          document.addEventListener('click', function(e){
            var t = e.target;
            var btn = t.closest ? t.closest(
              '[data-testid="SideNav_AccountSwitcher_Button"], [aria-label="Account menu"]') : null;
            if (btn && window.xharmony && window.xharmony.openMe) {
              e.preventDefault();
              e.stopPropagation();
              window.xharmony.openMe();
            }
          }, true);
        }
      }
      hideChrome();
      var bad = ['Messages','Grok','Calls','Lists','Communities','Premium',
                 'Creator Studio','Business','Ads','Create your Space',
                 '私信','电话','列表','社群','创作者工作室','商业','广告','创建你的空间',
                 'Settings and privacy','设置和隐私'];
      function sweep(){
        var nodes = document.querySelectorAll('a, [role="menuitem"], [role="button"]');
        for (var i = 0; i < nodes.length; i++) {
          var text = (nodes[i].textContent || '').trim();
          if (bad.indexOf(text) >= 0) nodes[i].style.display = 'none';
        }
      }
      function hideComposer(){
        if (window.__xhNoComposerHide) return;
        var tas = document.querySelectorAll('[data-testid="tweetTextarea_0"]');
        for (var t = 0; t < tas.length; t++) {
          var ta = tas[t];
          var box = ta.closest('[data-testid="cellInnerDiv"]');
          if (!box) continue;
          box.style.display = 'none';
        }
        var inlineBtn = document.querySelector('[data-testid="tweetButtonInline"]');
        if (inlineBtn) {
          var p = inlineBtn;
          for (var j = 0; j < 8 && p && p.parentElement; j++) {
            p = p.parentElement;
            var tid = p.getAttribute ? p.getAttribute('data-testid') : '';
            if (tid === 'cellInnerDiv') {
              p.style.display = 'none';
              break;
            }
          }
        }
        var bars = document.querySelectorAll('[data-testid="toolBar"]');
        for (var k = 0; k < bars.length; k++) bars[k].style.display = 'none';
      }
      hideComposer();
      setTimeout(hideComposer, 1200);
      sweep();
      hideChrome();
      setTimeout(function(){ sweep(); hideChrome(); hideComposer(); }, 800);
      if (!window.__xhObs) {
        window.__xhObs = new MutationObserver(function(){
          sweep();
          hideChrome();
          hideComposer();
                });
        window.__xhObs.observe(document.body, { childList: true, subtree: true });
      }
      ${captureTweets ? `
      window.__xhTwoPane = ${captureTweets};
      if (!window.__xhPrefetchHooked) {
        window.__xhPrefetchHooked = true;
        var prefetching = false;
        function scanPrefetch(){
          if (prefetching) return;
          prefetching = true;
          var links = document.querySelectorAll('article a[href*="/status/"]');
          var seen = {};
          var n = 0;
          for (var i = 0; i < links.length && n < 20; i++) {
            var href = links[i].href;
            if (!href || seen[href]) continue;
            seen[href] = true;
            n++;
            if (window.xharmony && window.xharmony.prefetch) window.xharmony.prefetch(href);
          }
          setTimeout(function(){ prefetching = false; }, 600);
        }
        setTimeout(scanPrefetch, 1200);
        window.addEventListener('scroll', function(){ scanPrefetch(); }, { passive: true });
      }
      if (!window.__xhPathHooked) {
        window.__xhPathHooked = true;
        function report(){ if (window.xharmony && window.xharmony.reportPath) window.xharmony.reportPath(location.pathname); }
        report();
        var push = history.pushState;
        history.pushState = function(){ var r = push.apply(history, arguments); report(); return r; };
        var replace = history.replaceState;
        history.replaceState = function(){ var r = replace.apply(history, arguments); report(); return r; };
        window.addEventListener('popstate', report);
      }
      if (!window.__xhSwipeHooked) {
        window.__xhTopInset = function(){
        var art = document.querySelector('article');
        if (!art) return;
        var p = art;
        for (var i = 0; i < 10 && p; i++) {
          var cs = window.getComputedStyle(p);
          if (cs.overflowY === 'auto' || cs.overflowY === 'scroll') break;
          p = p.parentElement;
        }
        if (p && p !== document.body) {
          p.style.setProperty('padding-top', '0px', 'important');
        } else {
          art.style.setProperty('margin-top', '0px', 'important');
        }
      };

      window.__xhSwipeHooked = true;
        var sx = 0, sy = 0, swiping = false;
        document.addEventListener('touchstart', function(e){
          if (e.touches.length == 1) {
            sx = e.touches[0].clientX;
            sy = e.touches[0].clientY;
            swiping = true;
          }
        }, { capture: true, passive: true });
        document.addEventListener('touchend', function(e){
          if (!swiping || e.changedTouches.length == 0) { swiping = false; return; }
          var dx = e.changedTouches[0].clientX - sx;
          var dy = e.changedTouches[0].clientY - sy;
          swiping = false;
          if (Math.abs(dx) > 28 && Math.abs(dx) > Math.abs(dy) * 1.1) {
            if (window.xharmony && window.xharmony.swipeTab) {
              window.xharmony.swipeTab(dx < 0 ? -1 : 1);
            }
          }
        }, { capture: true, passive: true });
      }
      if (!window.__xhTweetHooked) {
        window.__xhTweetHooked = true;
        document.addEventListener('click', function(e){
          var t = e.target;
          if (t.closest && t.closest('[data-testid="like"], [data-testid="retweet"], [data-testid="reply"], [role="button"]')) return;
          var article = t.closest ? t.closest('article') : null;
          var link = null;
          if (article) link = article.querySelector('a[href*="/status/"]');
          if (!link && t.closest) link = t.closest('a[href*="/status/"]');
          if (link && link.href && window.__xhTwoPane && window.xharmony && window.xharmony.openTweet) {
            e.preventDefault();
            e.stopPropagation();
            window.xharmony.openTweet(link.href);
          }
        }, true);
      }` : ''}
    })();`;
    controller.runJavaScript(script).catch(() => {});
  }

  private open(home: boolean, search: boolean, notifications: boolean): void {
    const next = home ? 0 : (search ? 1 : 2);
    const target = home ? '/home' : (search ? '/explore' : '/notifications');
    if (this.tab == next && this.currentPath == target) {
      this.leftController.runJavaScript(`(function(){
        window.scrollTo({ top: 0, behavior: 'smooth' });
        var pill = document.querySelector('[aria-label*="帖子"], [aria-label*="posts"], [role="button"][aria-label*="Show"]');
        if (pill) pill.click();
      })()`).catch(() => {});
      return;
    }
    if (home) {
      // Home stays mounted; returning to it is a visibility switch, not a load.
      this.tab = 0;
      AppStorage.setOrCreate('barActive', 0);
      return;
    }
    this.tab = next;
    AppStorage.setOrCreate('barActive', next);
    if (this.auxPath != target) {
      this.auxController.loadUrl('https://x.com' + target);
    }
  }

  private handleBack(): boolean {
    if (this.showMe) {
      if (this.showSplitSettings) this.showSplitSettings = false;
      else this.showMe = false;
      return true;
    }

    if (!this.isExpanded && this.foldedDetail) {
      const current = this.rightController.getUrl();
      if (this.selectedUrl.length > 0 &&
        (current == this.selectedUrl || current.indexOf(this.selectedUrl) >= 0)) {
        // Right pane root -> back to cached Home.
        this.foldedDetail = false;
        return true;
      }
      if (this.rightController.accessBackward()) {
        this.rightController.backward();
        return true;
      }
      this.foldedDetail = false;
      return true;
    }

    if (this.isExpanded && this.selectedUrl.length > 0) {
      const current = this.rightController.getUrl();
      // Initial detail page: leave the detail and show the placeholder.
      if (current == this.selectedUrl || current.indexOf(this.selectedUrl) >= 0) {
        this.selectedUrl = '';
        this.rightController.loadUrl('about:blank');
        return true;
      }
      // Deeper navigation inside the detail web view.
      if (this.rightController.accessBackward()) {
        this.rightController.backward();
        return true;
      }
      this.selectedUrl = '';
      this.rightController.loadUrl('about:blank');
      return true;
    }

    if (this.tab == 0 && this.homeIndex == 1) {
      if (this.followingPath != '/home' && this.followingPath != '/') {
        this.followingController.runJavaScript('history.back()').catch(() => {});
        return true;
      }
      this.homeIndex = 0;
      return true;
    }

    if (this.tab != 0) {
      // Auxiliary tab: back within it, then switch back to cached Home.
      if (this.auxPath != '/explore' && this.auxPath != '/notifications' && this.auxPath != '/') {
        this.auxController.runJavaScript('history.back()').catch(() => {});
        return true;
      }
      this.tab = 0;
      return true;
    }
    // Home top level exits; elsewhere navigate back.
    if (this.currentPath == '/home' || this.currentPath == '/') {
      return false;
    }
    this.leftController.runJavaScript('history.back()').catch(() => {});
    return true;
  }

  private onMeChanged(): void {
    if (this.showMe) {
      WindowBridge.hide();
    } else {
      AppStorage.setOrCreate('barActive', this.tab);
      if (this.isExpanded) WindowBridge.show();
    }
  }

  private onBarMoveSide(): void {
    if (this.isExpanded) {
      this.moveBarTo(this.barMoveSide);
      WindowBridge.moveBar(this.barMoveSide);
    }
  }

  private onBackTick(): void {
    this.handleBack();
  }

  private onBarAction(): void {
    if (this.barAction == 'home') this.open(true, false, false);
    else if (this.barAction == 'search') this.open(false, true, false);
    else if (this.barAction == 'notify') this.open(false, false, true);
    else if (this.barAction == 'compose') this.openCompose();
    else if (this.barAction == 'me') {
      if (this.showMe) this.showMe = false; else this.openMe();
    }
  }

  private async openMe(): Promise<void> {
    AppStorage.setOrCreate('barActive', 3);
    animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
      this.showMe = true;
    });
  }

  private async loadOwnPath(suffix: string): Promise<void> {
    try {
      const href = await this.leftController.runJavaScript(`(function(){
        var a = document.querySelector('[data-testid="AppTabBar_Profile_Link"]');
        return a ? (a.getAttribute('href') || '') : '';
      })()`) as string;
      const handle = href.replace(/^"|"$/g, '');
      if (handle.length > 1) {
        this.leftController.loadUrl(`https://x.com${handle}${suffix}`);
        return;
      }
    } catch (e) {}
    if (this.ownHandle.length > 0) {
      this.leftController.loadUrl(`https://x.com/${this.ownHandle}${suffix}`);
    } else {
      promptAction.showToast({ message: '无法获取账号信息' });
    }
  }

  private async openMyProfile(): Promise<void> {
    try {
      const menu = await this.leftController.runJavaScript(`(function(){
        var b = document.querySelector('[data-testid="SideNav_AccountSwitcher_Button"]');
        if (b) { b.click(); return 'ok'; }
        return 'no';
      })()`) as string;
      if (menu.indexOf('ok') >= 0) return;

      const clicked = await this.leftController.runJavaScript(`(function(){
        var a = document.querySelector('[data-testid="AppTabBar_Profile_Link"]');
        if (a) { a.click(); return 'ok'; }
        return 'no';
      })()`) as string;
      if (clicked.indexOf('ok') >= 0) return;
    } catch (e) {}
    try {
      const cookie = await webview.WebCookieManager.fetchCookie('https://x.com');
      const match = cookie.match(/twid=u%3D(\d+)/);
      if (match != null && match.length > 1) {
        this.leftController.loadUrl(`https://x.com/i/user/${match[1]}`);
      }
    } catch (e) {
      promptAction.showToast({ message: '无法打开个人主页' });
    }
  }

  private goBack(): void {
    if (this.twoPane && this.selectedUrl.length > 0) {
      if (this.rightController.accessBackward()) {
        this.rightController.backward();
        return;
      }
    }
    if (this.leftController.accessBackward()) {
      this.leftController.backward();
    }
  }


  @Builder
  meDrawer() {
    Column() {
      Row() {
        Text('我的').fontSize(18).fontWeight(FontWeight.Bold).layoutWeight(1)
      }.width('100%').height(52).padding({ left: 16, right: 16 })

      Divider().color('#F0F0F0')
      this.meItem('个人资料', () => {
        this.showMe = false;
        this.openMyProfile();
      })
      this.meItem('关注', () => {
        this.showMe = false;
        this.loadOwnPath('/following');
      })
      this.meItem('历史', () => {
        this.showMe = false;
        this.leftController.loadUrl('https://x.com/i/history');
      })
      this.meItem('分栏设置', () => {
        this.showSplitSettings = true;
      })
      this.meItem('登出', () => {
        this.showMe = false;
        this.leftController.loadUrl('https://x.com/logout');
      })
      Blank()
    }
    .width(300).height('100%').backgroundColor('#FFFFFF')
    .transition(TransitionEffect.translate({ x: 300 }).combine(TransitionEffect.OPACITY))
  }

  @Builder
  meItem(title: string, action: () => void) {
    Row() {
      Text(title).fontSize(16).layoutWeight(1)
      Text('›').fontSize(18).fontColor('#999999')
    }
    .width('100%').height(54).padding({ left: 16, right: 16 })
    .onClick(action)
  }

  @Builder
  splitSettings() {
    Column() {
      Row() {
        Button('‹ 返回').backgroundColor('#00000000').fontColor('#007DFF')
          .onClick(() => this.showSplitSettings = false)
        Text('分栏设置').fontSize(18).fontWeight(FontWeight.Bold).layoutWeight(1)
      }.width('100%').height(52).padding({ left: 8, right: 12 })

      Row() {
        Text('启用分栏').fontSize(16).layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.splitEnabled })
          .onChange((value: boolean) => {
            this.splitEnabled = value;
            this.paneCollapsed = false;
            this.saveRatio();
          })
      }.width('100%').padding(16)

      Row() {
        Text('左栏宽度').fontSize(16).layoutWeight(1)
        Text(`${Math.round(this.splitRatio * 100)}%`).fontSize(14).fontColor('#666666')
      }.width('100%').padding({ left: 16, right: 16, top: 8 })

      Slider({
        value: this.splitRatio * 100,
        min: 30,
        max: 70,
        step: 1,
        style: SliderStyle.OutSet
      })
        .width('90%')
        .onChange((value: number) => {
          this.splitRatio = Math.min(0.7, Math.max(0.3, value / 100));
          this.saveRatio();
        })

      Button('恢复 50 / 50')
        .margin({ top: 16 })
        .onClick(() => {
          this.splitRatio = 0.5;
          this.saveRatio();
        })
      Blank()
    }
    .width(300).height('100%').backgroundColor('#FFFFFF')
    .transition(TransitionEffect.translate({ x: 300 }).combine(TransitionEffect.OPACITY))
  }

  @Builder
  floatingBar() {
    Row() {
      this.tabItem(0, $r('app.media.ic_home'), '主页')
      this.tabItem(1, $r('app.media.ic_search'), '搜索')

      Column() {
        Button() {
          Image($r('app.media.ic_plus')).width(22).height(22).fillColor('#FFFFFF')
        }
        .width(44).height(44).borderRadius(22)
        .backgroundColor('#0F1419')
        .onClick(async () => {
          try {
            this.composeCookie = await webview.WebCookieManager.fetchCookie('https://x.com');
          } catch (e) {
            promptAction.showToast({ message: `读取登录态失败：${e}` });
            return;
          }
          animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
            this.showCompose = true;
          });
        })
      }
      .layoutWeight(1).height(56).justifyContent(FlexAlign.Center)

      this.tabItem(2, $r('app.media.ic_bell'), '通知')

      Column() {
        Image($r('app.media.ic_user')).width(24).height(24).fillColor('#536471')
        Text('我的').fontSize(10).fontColor('#536471').margin({ top: 2 })
      }
      .layoutWeight(1).height(56).justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.openMe();
      })
    }
    .width(this.barW).height(60)
    .borderRadius(30)
    .backgroundColor('#FFFFFF')
    .backgroundBlurStyle(BlurStyle.Thin)
    .shadow({ radius: 16, color: '#1A000000', offsetY: 4 })
    .padding({ left: 6, right: 6 })
    .offset({ x: this.barX })
  }

  @Builder
  tabItem(index: number, icon: Resource, label: string) {
    Column() {
      Image(icon).width(24).height(24)
        .fillColor(this.tab == index ? '#0F1419' : '#536471')
      Text(label).fontSize(10)
        .fontColor(this.tab == index ? '#0F1419' : '#536471')
        .margin({ top: 2 })
    }
    .layoutWeight(1).height(56).justifyContent(FlexAlign.Center)
    .onClick(() => {
      animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
        this.open(index == 0, index == 1, index == 2);
      });
    })
  }

  @Builder
  feedWeb() {
    Web({ src: 'https://x.com/home', controller: this.leftController })
      .userAgent(this.chromeUa)
      .javaScriptAccess(true).domStorageAccess(true).databaseAccess(true)
      .onlineImageAccess(true).fileAccess(true).mixedMode(MixedMode.All).zoomAccess(true)
      .javaScriptProxy({
        object: this.bridge,
        name: 'xharmony',
        methodList: ['openTweet', 'openMe', 'reportPath', 'prefetch', 'reportDom', 'swipeTab'],
        controller: this.leftController
      })
      .width('100%').height('100%')
      .onProgressChange((event) => this.progress = event.newProgress)
      .onPageEnd((event) => {
        this.progress = 100;
        this.webReady = true;
        const url = event.url;
        // Once logged in, stay logged in on profile/detail routes too.
        if (url.indexOf('/home') >= 0 || url.indexOf('/explore') >= 0 ||
          url.indexOf('/notifications') >= 0) {
          this.loggedIn = true;
        }
        let path = url;
        const schemeAt = path.indexOf('://');
        if (schemeAt >= 0) {
          const slashAt = path.indexOf('/', schemeAt + 3);
          path = slashAt >= 0 ? path.substring(slashAt) : '/';
        }
        const queryAt = path.indexOf('?');
        if (queryAt >= 0) path = path.substring(0, queryAt);
        this.currentPath = path.length > 0 ? path : '/home';
        if (this.loggedIn) {
          this.leftController.runJavaScript(`window.__xhTwoPane = ${this.isExpanded};`).catch(() => {});
          this.injectUi(this.leftController, true);
          setTimeout(() => { WindowBridge.openBar(); }, 400);
          setTimeout(() => { this.leftReady = true; }, 700);
          setTimeout(() => this.dumpTopDom(), 2200);
          if (this.isExpanded) {
            this.applyHalfWidthCss();
            setTimeout(() => {
              if (this.isExpanded) {
                }
            }, 600);
          }
        }
      })
      .onErrorReceive((event) => {
        if (event.request.isMainFrame()) {
          promptAction.showToast({ message: `页面加载失败：${event.error.getErrorInfo()}` });
        }
      })
  }

  @Builder
  followingWeb() {
    Web({ src: 'https://x.com/home', controller: this.followingController })
      .userAgent(this.chromeUa)
      .javaScriptProxy({
        object: this.followingBridge,
        name: 'xharmony',
        methodList: ['openTweet', 'openMe', 'reportPath', 'prefetch', 'reportDom', 'swipeTab'],
        controller: this.followingController
      })
      .javaScriptAccess(true).domStorageAccess(true).databaseAccess(true)
      .onlineImageAccess(true).fileAccess(true).mixedMode(MixedMode.All).zoomAccess(true)
      .width('100%').height('100%')
      .onPageEnd(() => {
        this.injectUi(this.followingController, true);
        if (this.homeIndex == 1) setTimeout(() => { this.leftReady = true; }, 700);
        this.followingController.runJavaScript(`(function(){
          var tabs = Array.prototype.slice.call(document.querySelectorAll('[role="tab"]'));
          for (var i = 0; i < tabs.length; i++) {
            var t = (tabs[i].textContent || '').trim();
            if (t.indexOf('正在关注') === 0 || t === 'Following') { tabs[i].click(); return; }
          }
        })()`).catch(() => {});
        try {
          const u = this.followingController.getUrl();
          const at = u.indexOf('/', u.indexOf('://') + 3);
          this.followingPath = at >= 0 ? u.substring(at) : '/home';
        } catch (e) {}
      })
  }

  @Builder
  auxWeb() {
    Web({ src: 'about:blank', controller: this.auxController })
      .userAgent(this.chromeUa)
      .javaScriptAccess(true).domStorageAccess(true).databaseAccess(true)
      .onlineImageAccess(true).fileAccess(true).mixedMode(MixedMode.All).zoomAccess(true)
      .width('100%').height('100%')
      .visibility(this.tab == 0 ? Visibility.None : Visibility.Visible)
      .onPageEnd(() => {
        try {
          const url = this.auxController.getUrl();
          const schemeAt = url.indexOf('://');
          let path = schemeAt >= 0 ? url.substring(url.indexOf('/', schemeAt + 3)) : url;
          const q = path.indexOf('?');
          if (q >= 0) path = path.substring(0, q);
          this.auxPath = path;
          this.auxLoaded = true;
        } catch (e) {}
      })
  }

  @Builder
  detailWeb() {
    Web({ src: this.selectedUrl.length > 0 ? this.selectedUrl : 'about:blank', controller: this.rightController })
      .userAgent(this.chromeUa)
      .javaScriptAccess(true).domStorageAccess(true).databaseAccess(true)
      .onlineImageAccess(true).fileAccess(true).mixedMode(MixedMode.All).zoomAccess(true)
      .width('100%').height('100%')
      .onPageEnd(() => this.injectUi(this.rightController, false, false))
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // Extend under the system status bar; the tab bar paints that area.
      
      Column() {
        SideBarContainer(SideBarContainerType.Embed) {
          Column() {
            Stack({ alignContent: Alignment.Top }) {
              Swiper(this.swiperController) {
                Column() { this.feedWeb() }.width('100%').height('100%')
                Column() { this.followingWeb() }.width('100%').height('100%')
              }
              .index(this.homeIndex)
              .indicator(false)
              .cachedCount(2)
              .loop(false)
              .duration(600)
              .curve(Curve.Friction)
              .onChange((index: number) => {
                this.homeIndex = index;
                setTimeout(() => this.repairWebChrome(), 200);
              })
              .width('100%').height('100%')
              .visibility(this.tab == 0 ? Visibility.Visible : Visibility.None)
              .padding({ top: 30 })
              .offset({ y: this.isExpanded ? -50 : 0 })
              .height(this.isExpanded ? 'calc(100% + 50vp)' : '100%')

              if (this.tab == 0) {
                Row() {
                  Column() {
                    Text('为你推荐').fontSize(14)
                      .fontWeight(this.homeIndex == 0 ? FontWeight.Bold : FontWeight.Normal)
                      .fontColor(this.homeIndex == 0 ? '#0F1419' : '#536471')
                    if (this.homeIndex == 0) {
                      Row().width(48).height(2).borderRadius(1).backgroundColor('#1D9BF0').margin({ top: 5 })
                    }
                  }
                  .layoutWeight(1).height(30).justifyContent(FlexAlign.End)
                  .onClick(() => { this.swiperController.changeIndex(0, true); })

                  Column() {
                    Text('正在关注').fontSize(14)
                      .fontWeight(this.homeIndex == 1 ? FontWeight.Bold : FontWeight.Normal)
                      .fontColor(this.homeIndex == 1 ? '#0F1419' : '#536471')
                    if (this.homeIndex == 1) {
                      Row().width(48).height(2).borderRadius(1).backgroundColor('#1D9BF0').margin({ top: 5 })
                    }
                  }
                  .layoutWeight(1).height(30).justifyContent(FlexAlign.End)
                  .onClick(() => { this.swiperController.changeIndex(1, true); })
                }
                .width('100%').height(30)
                .backgroundColor('#FFFFFF')
                .zIndex(30)
              }

              this.auxWeb()

              if (!this.leftReady && this.tab == 0) {
                Column() {
                  LoadingProgress().width(48).height(48).color('#0A59F7')
                }
                .width('100%').height('100%')
                .backgroundColor('#FFFFFF')
                .justifyContent(FlexAlign.Center)
                .zIndex(40)
              }
            }.width('100%').height('100%')
            .opacity(this.leftReady ? this.feedAlpha : 0)
            .translate({ x: this.feedShift })
          }.width('100%').height('100%')

          Column() {
            Stack({ alignContent: Alignment.Center }) {
              this.detailWeb()
              if (this.selectedUrl.length == 0) {
                Text('选择左侧推文').fontSize(15).fontColor('#536471')
              }
            }.width('100%').height('100%')
          }.width('100%').height('100%')
        }
        .showSideBar(true)
        .sideBarWidth(this.isExpanded && this.splitEnabled ? this.viewportWidth * this.leftFraction :
          (this.foldedDetail ? 0 : this.viewportWidth))
        .minSideBarWidth(1)
        .maxSideBarWidth(this.viewportWidth)
        .minContentWidth(0)
        .showControlButton(false)
        .autoHide(false)
        .width('100%').height('100%')
        .onAreaChange((oldValue: Area, newValue: Area) => {
          const width = parseFloat(`${newValue.width}`);
          const height = parseFloat(`${newValue.height}`);
          if (!isNaN(width)) {
            this.viewportWidth = width;
            this.updateBarX();
          }
          if (!isNaN(height)) this.viewportHeight = height;
        })
        .onTouchIntercept((event: TouchEvent) => {
          if (this.isExpanded && event.type == TouchType.Down && event.touches.length > 0) {
            const x = event.touches[0].displayX;
            const y = event.touches[0].displayY;
            const onBar = y > this.viewportHeight - 110 && x >= this.barX - 8 && x <= this.barX + this.barW + 8;
            if (!onBar) this.moveBarTo(x < this.screenWidthVp / 2 ? 0 : 2);
          }
          return HitTestMode.Default;
        })
      }
      .width('100%').height('100%')

      if (this.loggedIn && this.currentPath != '/home' && this.currentPath != '/explore' &&
        this.currentPath != '/notifications') {
        Button('←')
          .width(36).height(36).borderRadius(18)
          .backgroundColor('#E6FFFFFF').fontColor('#0F1419').fontSize(18)
          .position({ x: 8, y: 8 })
          .onClick(() => this.handleBack())
      }

      if (this.showMe) {
        Row() {
          Blank().onClick(() => {
            this.showMe = false;
            this.showSplitSettings = false;
          })
          Column() {
            if (this.showSplitSettings) {
              this.splitSettings()
            } else {
              this.meDrawer()
            }
          }
          .width(300).height('100%')
        }
        .width('100%').height('100%')
        .backgroundColor('#66000000')
        .transition(TransitionEffect.OPACITY)
        .alignItems(VerticalAlign.Top)
      }

      if (this.showCompose) {
        ComposeView({
          cookie: this.composeCookie,
          onClose: () => {
            this.showCompose = false;
            this.leftController.refresh();
          }
        })
        .width('100%').height('100%')
        .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 400 })))
      }

      }
      .width('100%').height('100%')
  }
}
