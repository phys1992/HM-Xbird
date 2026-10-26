import { display } from '@kit.ArkUI';

@Entry
@Component
struct BarWindow {
  @StorageLink('barSide') @Watch('onSideChanged') side: number = 1;
  @State pillX: number = 0;
  @State sheenX: number = -160;
  private readonly pillW: number = 320;

  onBackPress(): boolean {
    const tick = AppStorage.get<number>('backTick') ?? 0;
    AppStorage.setOrCreate('backTick', tick + 1);
    return true;
  }

  aboutToAppear(): void {
    this.pillX = this.xForSide(this.side);
    animateTo({
      duration: 2600,
      curve: Curve.EaseInOut,
      iterations: -1,
      playMode: PlayMode.Alternate
    }, () => {
      this.sheenX = 340;
    });
  }

  private screenWidthVp(): number {
    try {
      const d = display.getDefaultDisplaySync();
      return d.width / (d.densityPixels > 0 ? d.densityPixels : 3);
    } catch (e) {
      return 400;
    }
  }

  private xForSide(side: number): number {
    const w = this.screenWidthVp();
    if (side == 0) return 10;
    if (side == 2) return Math.max(10, w - this.pillW - 10);
    return Math.max(10, (w - this.pillW) / 2);
  }

  onSideChanged(): void {
    animateTo({ duration: 300, curve: Curve.Friction }, () => {
      this.pillX = this.xForSide(this.side);
    });
  }

  build() {
    Stack({ alignContent: Alignment.BottomStart }) {
      Stack({ alignContent: Alignment.Start }) {
        Row() {
          this.item('主页', $r('app.media.ic_home'), 'home')
          this.item('搜索', $r('app.media.ic_search'), 'search')
          this.centerItem()
          this.item('通知', $r('app.media.ic_bell'), 'notify')
          this.item('我的', $r('app.media.ic_user'), 'me')
        }
        .width('100%').height('100%')
        .padding({ left: 6, right: 6 })

        // Ambient light sweep.
        Row()
          .width(90).height('100%')
          .linearGradient({
            angle: 90,
            colors: [['#00FFFFFF', 0.0], ['#80FFFFFF', 0.5], ['#00FFFFFF', 1.0]]
          })
          .blur(8)
          .opacity(0.55)
          .offset({ x: this.sheenX })
          .hitTestBehavior(HitTestMode.None)
      }
      .width(this.pillW).height(60)
      .borderRadius(30)
      .clip(true)
      .backgroundColor('#D9FFFFFF')
      .backgroundBlurStyle(BlurStyle.Thin)
      .border({ width: 0.5, color: '#B3FFFFFF' })
      .shadow({ radius: 18, color: '#26000000', offsetY: 5 })
      .offset({ x: this.pillX })
      .margin({ bottom: 10 })
    }
    .width('100%').height('100%')
    .backgroundColor('#00000000')
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.pillX = this.xForSide(this.side);
    })
  }

  @Builder
  item(label: string, icon: Resource, action: string) {
    Column() {
      Image(icon).width(24).height(24).fillColor('#536471')
      Text(label).fontSize(10).fontColor('#536471').margin({ top: 2 })
    }
    .layoutWeight(1).height('100%').justifyContent(FlexAlign.Center)
    .onClick(() => this.dispatch(action))
  }

  @Builder
  centerItem() {
    Column() {
      Button() {
        Image($r('app.media.ic_plus')).width(22).height(22).fillColor('#FFFFFF')
      }
      .width(44).height(44).borderRadius(22)
      .backgroundColor('#0F1419')
      .onClick(() => this.dispatch('compose'))
    }
    .layoutWeight(1).height('100%').justifyContent(FlexAlign.Center)
  }

  private dispatch(action: string): void {
    const tick = AppStorage.get<number>('barActionTick') ?? 0;
    AppStorage.setOrCreate('barAction', action);
    AppStorage.setOrCreate('barActionTick', tick + 1);
  }
}
