import { UIAbility, AbilityConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { BackDispatcher } from '../model/BackDispatcher';
import { DetailCache } from '../model/DetailCache';

export default class EntryAbility extends UIAbility {
  onMemoryLevel(level: AbilityConstant.MemoryLevel): void {
    DetailCache.clear();
  }

  onBackPressed(): boolean {
    return BackDispatcher.handler();
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index');
  }
}
