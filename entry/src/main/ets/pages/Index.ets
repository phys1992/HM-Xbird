import { BackDispatcher } from '../model/BackDispatcher';
import { WebShell } from '../view/WebShell';

@Entry
@Component
struct Index {
  onBackPress(): boolean {
    return BackDispatcher.handler();
  }

  build() {
    Column() {
      WebShell()
    }
    .width('100%')
    .height('100%')
  }
}
