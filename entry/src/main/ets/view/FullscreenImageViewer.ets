import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';

@Component
export struct FullscreenImageViewer {
  url: string = '';

  @State private imageScale: number = 1;
  @State private imageOffsetX: number = 0;
  @State private imageOffsetY: number = 0;
  @State private viewW: number = 1;
  @State private viewH: number = 1;

  private mainWin: window.Window | null = null;
  private panStartX: number = 0;
  private panStartY: number = 0;
  private panTargetX: number = 0;
  private panTargetY: number = 0;
  private panTimer: number = -1;
  private pinchStartScale: number = 1;

  aboutToAppear(): void {
    window.getLastWindow(getContext(this) as common.UIAbilityContext).then((win: window.Window) => {
      this.mainWin = win;
      win.setWindowSystemBarEnable([]).catch(() => {});
    }).catch(() => {});
  }

  aboutToDisappear(): void {
    this.stopPanTracking();
    if (this.mainWin == null) return;
    this.mainWin.setWindowSystemBarEnable(['status', 'navigation']).then(() => {
      const dark = AppStorage.get<boolean>('tuichuang_dark') ?? false;
      if (this.mainWin != null) {
        this.mainWin.setWindowSystemBarProperties({
          statusBarColor: '#00000000',
          navigationBarColor: '#00000000',
          isStatusBarLightIcon: dark,
          isNavigationBarLightIcon: dark,
          statusBarContentColor: dark ? '#FFFFFF' : '#000000',
          navigationBarContentColor: dark ? '#FFFFFF' : '#000000'
        }).catch(() => {});
      }
    }).catch(() => {});
  }

  private maxOffsetX(): number {
    return Math.max(0, (this.imageScale - 1) * this.viewW / 2);
  }

  private maxOffsetY(): number {
    return Math.max(0, (this.imageScale - 1) * this.viewH / 2);
  }

  private clampX(value: number): number {
    const max = this.maxOffsetX();
    return Math.max(-max, Math.min(max, value));
  }

  private clampY(value: number): number {
    const max = this.maxOffsetY();
    return Math.max(-max, Math.min(max, value));
  }

  private clampOffsets(): void {
    this.imageOffsetX = this.clampX(this.imageOffsetX);
    this.imageOffsetY = this.clampY(this.imageOffsetY);
    this.panTargetX = this.clampX(this.panTargetX);
    this.panTargetY = this.clampY(this.panTargetY);
  }

  private startPanTracking(): void {
    if (this.panTimer >= 0) return;
    this.panTimer = setInterval(() => {
      if (this.imageScale <= 1) return;
      // Critically damped follow: ~60ms time constant means the image is
      // within the finger's tracking window well below 200ms.
      this.imageOffsetX += (this.panTargetX - this.imageOffsetX) * 0.27;
      this.imageOffsetY += (this.panTargetY - this.imageOffsetY) * 0.27;
      if (Math.abs(this.panTargetX - this.imageOffsetX) < 0.15) {
        this.imageOffsetX = this.panTargetX;
      }
      if (Math.abs(this.panTargetY - this.imageOffsetY) < 0.15) {
        this.imageOffsetY = this.panTargetY;
      }
    }, 16);
  }

  private stopPanTracking(): void {
    if (this.panTimer >= 0) {
      clearInterval(this.panTimer);
      this.panTimer = -1;
    }
  }

  private settlePan(): void {
    this.stopPanTracking();
    this.panTargetX = this.clampX(this.panTargetX);
    this.panTargetY = this.clampY(this.panTargetY);
    animateTo({ duration: 50, curve: Curve.Friction }, () => {
      this.imageOffsetX = this.panTargetX;
      this.imageOffsetY = this.panTargetY;
    });
  }

  private resetImage(): void {
    this.stopPanTracking();
    this.panTargetX = 0;
    this.panTargetY = 0;
    animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
      this.imageScale = 1;
      this.imageOffsetX = 0;
      this.imageOffsetY = 0;
    });
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Image(this.url)
          .width('100%').height('100%')
          .objectFit(ImageFit.Contain)
          .backgroundColor('#000000')
          .scale({ x: this.imageScale, y: this.imageScale })
      }
      .width('100%').height('100%')
      // Translation lives on the wrapper, outside the scaled Image. This
      // keeps one screen pixel of finger movement equal to one screen pixel
      // of image movement at every zoom level.
      .translate({ x: this.imageOffsetX, y: this.imageOffsetY })
    }
    .width('100%').height('100%')
    .backgroundColor('#000000')
    .clip(true)
    // This gesture layer is stationary. If it were attached to the moving
    // image, ArkUI would calculate the pan offset in a moving local
    // coordinate space and the image would no longer track the finger 1:1.
    .gesture(
      GestureGroup(GestureMode.Parallel,
        PinchGesture()
          .onActionStart(() => {
            this.pinchStartScale = this.imageScale;
          })
          .onActionUpdate((event: GestureEvent) => {
            // event.scale is relative to this pinch gesture's starting span.
            // Multiply by the scale at pinch start so a small pinch-out from
            // an already zoomed image does not jump back to 1x.
            this.imageScale = Math.max(1, Math.min(4,
              this.pinchStartScale * event.scale));
            this.clampOffsets();
            if (this.imageScale <= 1) this.stopPanTracking();
          }),
        PanGesture({ fingers: 1, distance: 1 })
          .onActionStart(() => {
            this.panStartX = this.imageOffsetX;
            this.panStartY = this.imageOffsetY;
            this.panTargetX = this.imageOffsetX;
            this.panTargetY = this.imageOffsetY;
            if (this.imageScale > 1) this.startPanTracking();
          })
          .onActionUpdate((event: GestureEvent) => {
            if (this.imageScale <= 1) return;
            this.panTargetX = this.clampX(this.panStartX + event.offsetX);
            this.panTargetY = this.clampY(this.panStartY + event.offsetY);
            this.startPanTracking();
          })
          .onActionEnd(() => this.settlePan())
          .onActionCancel(() => this.settlePan())
      )
    )
    .onClick(() => this.resetImage())
    .onAreaChange((oldValue: Area, newValue: Area) => {
      const w = parseFloat(`${newValue.width}`);
      const h = parseFloat(`${newValue.height}`);
      if (!isNaN(w) && w > 0) this.viewW = w;
      if (!isNaN(h) && h > 0) this.viewH = h;
      this.clampOffsets();
    })
  }
}
