import { display } from '@kit.ArkUI';
import { I18n } from '../model/I18n';
import { GestureStage } from './GestureStage';

@Component
export struct GestureDemo {
  @StorageProp('clientLang') clientLanguage: string = 'zh';
  @StorageProp('tuichuang_dark') isDark: boolean = false;
  @State private availableWidth: number = 0;
  @State private phase: number = 0;
  @State private phaseProgress: number = 0;
  @State private screenAspect: number = 0.9;
  @State private indicatorX: number = 0;
  private timerId: number = -1;
  private controller: SwiperController = new SwiperController();

  private tr(value: string): string {
    return this.clientLanguage.length >= 0 ? I18n.t(value) : I18n.t(value);
  }

  aboutToAppear(): void {
    this.refreshScreenModel();
    if (this.timerId > 0) clearInterval(this.timerId);
    this.timerId = setInterval(() => {
      let next = this.phaseProgress + 0.035;
      if (next >= 1) next = 0;
      this.phaseProgress = next;
    }, 50);
  }

  aboutToDisappear(): void {
    if (this.timerId > 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private refreshScreenModel(): void {
    try {
      const d = display.getDefaultDisplaySync();
      if (d.width > 0 && d.height > 0) {
        this.screenAspect = d.width / d.height;
      }
    } catch (e) {
      this.screenAspect = this.availableWidth >= 540 ? 0.9 : 0.5625;
    }
  }

  private wide(): boolean {
    return this.screenAspect >= 0.8;
  }

  private deviceWidth(): number {
    return Math.min(260, Math.max(150, this.availableWidth * 0.48));
  }

  private deviceHeight(): number {
    const aspect = this.wide() ? Math.max(0.8, this.screenAspect) : (16 / 9);
    return this.deviceWidth() / aspect;
  }

  private stageHeight(): number {
    return this.deviceHeight() + 58;
  }

  private indicatorLeft(index: number): number {
    return index * 14.5;
  }

  private animateIndicatorTo(index: number, duration: number): void {
    const target = this.indicatorLeft(index);
    if (duration <= 0) {
      this.indicatorX = target;
      return;
    }
    animateTo({ duration: duration, curve: Curve.EaseOut }, () => {
      this.indicatorX = target;
    });
  }

  private updateSwipeIndicator(index: number, offset: number): void {
    if (this.availableWidth <= 0) return;
    const ratio = Math.min(1, Math.abs(offset) / this.availableWidth);
    let next = index;
    if (offset < 0 && index < 2) next = index + 1;
    else if (offset > 0 && index > 0) next = index - 1;
    const fraction = index + (next - index) * ratio;
    this.indicatorX = fraction * 14.5;
  }

  private caption(index: number): string {
    if (index == 0) return this.tr('亮度调节');
    if (index == 1) return this.tr('音量调节');
    return this.tr('播放进度');
  }

  private subtitle(index: number): string {
    if (index == 0) return this.tr('左侧上下滑动');
    if (index == 1) return this.tr('右侧上下滑动');
    return this.tr('横向滑动');
  }

  build() {
    Column() {
      if (this.availableWidth > 0) {
        Swiper(this.controller) {
          ForEach([0, 1, 2], (index: number) => {
            GestureStage({
              phase: index,
              progress: this.phaseProgress,
              availableWidth: this.availableWidth,
              screenAspect: this.screenAspect,
              isDark: this.isDark,
              caption: this.caption(index),
              subtitle: this.subtitle(index),
              videoLabel: this.tr('全屏视频')
            })
          }, (index: number) => `${index}`)
        }
        .index(this.phase)
        .indicator(false)
        .loop(false)
        .duration(280)
        .curve(Curve.EaseOut)
        .cachedCount(2)
        .width('100%')
        .height(this.stageHeight())
        .onChange((index: number) => {
          this.phase = index;
          this.phaseProgress = 0;
          this.indicatorX = this.indicatorLeft(index);
        })
        .onAnimationStart((index: number, targetIndex: number, event: SwiperAnimationEvent) => {
          this.phaseProgress = 0;
          this.animateIndicatorTo(targetIndex, 280);
        })
        .onGestureSwipe((index: number, event: SwiperAnimationEvent) => {
          this.updateSwipeIndicator(index, event.currentOffset);
        })
        .onAnimationEnd((index: number, event: SwiperAnimationEvent) => {
          this.phase = index;
          this.phaseProgress = 0;
          this.indicatorX = this.indicatorLeft(index);
        })
      }

      Stack({ alignContent: Alignment.TopStart }) {
        ForEach([0, 1, 2], (index: number) => {
          Circle({ width: 5, height: 5 })
            .fill('#C5D1D9')
            .position({ x: 5 + index * 14.5, y: 0 })
        }, (index: number) => `dot${index}`)
        Row()
          .width(15).height(5).borderRadius(2.5)
          .backgroundColor($r('app.color.accent'))
          .position({ x: this.indicatorX, y: 0 })
      }
      .width(44).height(5).margin({ top: 10 })

      Text(this.tr('左右滑动切换演示')).fontSize(10)
        .fontColor($r('app.color.text_secondary')).margin({ top: 8 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .onAreaChange((oldValue: Area, newValue: Area) => {
      const w = parseFloat(`${newValue.width}`);
      if (!isNaN(w) && w > 0) {
        this.availableWidth = w;
        this.refreshScreenModel();
      }
    })
  }
}
