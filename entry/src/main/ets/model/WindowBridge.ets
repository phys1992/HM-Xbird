import { window } from '@kit.ArkUI';
import { display } from '@kit.ArkUI';

/**
 * Hosts the selected post in a separate app sub-window. ArkWeb surfaces in one
 * ArkUI page do not compose reliably side by side, so the right pane is a
 * real window positioned over the right half of the screen.
 */
export class WindowBridge {
  static stage: window.WindowStage | undefined = undefined;
  static sub: window.Window | undefined = undefined;
  static opening: boolean = false;

  static async open(url: string): Promise<void> {
    if (WindowBridge.stage == undefined) return;
    AppStorage.setOrCreate('detailUrl', url);
    if (WindowBridge.sub != undefined) {
      await WindowBridge.position();
      await WindowBridge.sub.showWindow();
      if (WindowBridge.bar != undefined) { try { await WindowBridge.bar.raiseToAppTop(); } catch (e) {} }
      return;
    }
    if (WindowBridge.opening) return;
    WindowBridge.opening = true;
    try {
      const sub = await WindowBridge.stage.createSubWindow('xh_detail');
      await sub.setUIContent('pages/DetailWindow');
      WindowBridge.sub = sub;
      await WindowBridge.position();
      await WindowBridge.slideIn();
    } catch (e) {
      WindowBridge.sub = undefined;
    } finally {
      WindowBridge.opening = false;
    }
  }

  private static sleep(ms: number): Promise<void> {
    return new Promise<void>((resolve) => setTimeout(resolve, ms));
  }

  static async slideTo(from: number, to: number, duration: number): Promise<void> {
    if (WindowBridge.sub == undefined) return;
    const steps = Math.max(1, Math.round(duration / 16));
    for (let i = 1; i <= steps; i++) {
      const x = Math.round(from + (to - from) * i / steps);
      try { await WindowBridge.sub.moveWindowTo(x, 0); } catch (e) {}
      await WindowBridge.sleep(16);
    }
  }

  static async slideIn(): Promise<void> {
    if (WindowBridge.sub == undefined) return;
    try {
      const d = display.getDefaultDisplaySync();
      await WindowBridge.sub.moveWindowTo(d.width, 0);
      await WindowBridge.sub.showWindow();
      if (WindowBridge.bar != undefined) { try { await WindowBridge.bar.raiseToAppTop(); } catch (e) {} }
      await WindowBridge.slideTo(d.width, Math.floor(d.width / 2), 300);
    } catch (e) {}
  }

  static async slideOutAndClose(): Promise<void> {
    if (WindowBridge.sub == undefined) return;
    try {
      const d = display.getDefaultDisplaySync();
      await WindowBridge.slideTo(Math.floor(d.width / 2), d.width, 260);
    } catch (e) {}
    await WindowBridge.close();
  }

  static async position(): Promise<void> {
    if (WindowBridge.sub == undefined) return;
    try {
      const d = display.getDefaultDisplaySync();
      const width = Math.floor(d.width / 2);
      // Full height; the bar lives in a higher window.
      await WindowBridge.sub.resize(width, d.height);
      await WindowBridge.sub.moveWindowTo(width, 0);
    } catch (e) {}
  }

  static bar: window.Window | undefined = undefined;
  static hidden: boolean = false;

  static async openBar(): Promise<void> {
    if (WindowBridge.stage == undefined) return;
    if (WindowBridge.bar != undefined) {
      await WindowBridge.positionBar(1);
      await WindowBridge.bar.showWindow();
      return;
    }
    try {
      const bar = await WindowBridge.stage.createSubWindow('xh_bar');
      await bar.setUIContent('pages/BarWindow');
      await bar.setWindowBackgroundColor('#00000000');
      WindowBridge.bar = bar;
      await WindowBridge.positionBar(1);
      await bar.showWindow();
      try { await bar.raiseToAppTop(); } catch (e) {}
    } catch (e) {
      WindowBridge.bar = undefined;
    }
  }

  static async positionBar(side: number): Promise<void> {
    if (WindowBridge.bar == undefined) return;
    try {
      const d = display.getDefaultDisplaySync();
      const density = d.densityPixels > 0 ? d.densityPixels : 3;
      const h = Math.round(80 * density);
      let safeBottom = 0;
      try {
        const area = WindowBridge.bar.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
        safeBottom = area.bottomRect.height;
      } catch (e) {}
      await WindowBridge.bar.resize(d.width, h);
      await WindowBridge.bar.moveWindowTo(0, d.height - h - safeBottom);
    } catch (e) {}
  }

  static async moveBar(side: number): Promise<void> {
    await WindowBridge.positionBar(side);
  }

  static async closeBar(): Promise<void> {
    if (WindowBridge.bar == undefined) return;
    try { await WindowBridge.bar.destroyWindow(); } catch (e) {}
    WindowBridge.bar = undefined;
  }

  static async hide(): Promise<void> {
    if (WindowBridge.sub == undefined) return;
    WindowBridge.hidden = true;
    try {
      const d = display.getDefaultDisplaySync();
      await WindowBridge.sub.moveWindowTo(0, -d.height);
    } catch (e) {}
  }

  static async show(): Promise<void> {
    if (WindowBridge.sub == undefined) return;
    WindowBridge.hidden = false;
    await WindowBridge.position();
  }

  static async close(): Promise<void> {
    if (WindowBridge.sub == undefined) return;
    try {
      await WindowBridge.sub.destroyWindow();
    } catch (e) {}
    WindowBridge.sub = undefined;
  }
}
