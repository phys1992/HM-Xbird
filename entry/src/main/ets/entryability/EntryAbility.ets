import { UIAbility, AbilityConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { WindowBridge } from '../model/WindowBridge';
import { BackDispatcher } from '../model/BackDispatcher';

export default class EntryAbility extends UIAbility {
  onMemoryLevel(level: AbilityConstant.MemoryLevel): void {
    const tick = AppStorage.get<number>('memoryTrimTick') ?? 0;
    AppStorage.setOrCreate('memoryTrimTick', tick + 1);
  }

  onBackPressed(): boolean {
    return BackDispatcher.handler();
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    WindowBridge.stage = windowStage;
    windowStage.loadContent('pages/Index');
  }
}
