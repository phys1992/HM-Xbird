import { BackDispatcher } from '../model/BackDispatcher';
import { NativeShell } from '../view/NativeShell';

@Entry
@Component
struct Index {
  onBackPress(): boolean {
    return BackDispatcher.handler();
  }

  build() {
    Column() {
      NativeShell()
    }
    .width('100%')
    .height('100%')
  }
}
