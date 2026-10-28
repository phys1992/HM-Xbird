import { UIAbility, AbilityConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { BackDispatcher } from '../model/BackDispatcher';
import { DetailCache } from '../model/DetailCache';
import { SessionStore } from '../model/SessionStore';
import { ThemeUtil } from '../model/ThemeUtil';

export default class EntryAbility extends UIAbility {
  onMemoryLevel(level: AbilityConstant.MemoryLevel): void {
    DetailCache.clear();
  }

  onBackPressed(): boolean {
    return BackDispatcher.handler();
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    const dark = ThemeUtil.apply(this.context, SessionStore.loadThemeMode(this.context));
    windowStage.loadContent('pages/Index');
    windowStage.getMainWindow().then((win: window.Window) => {
      win.setWindowLayoutFullScreen(true).catch(() => {});
      win.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000',
        isStatusBarLightIcon: dark,
        isNavigationBarLightIcon: dark,
        statusBarContentColor: dark ? '#FFFFFF' : '#000000',
        navigationBarContentColor: dark ? '#FFFFFF' : '#000000'
      }).catch(() => {});
    }).catch(() => {});
  }
}
