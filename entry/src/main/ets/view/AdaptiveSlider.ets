export enum AdaptiveSliderMode {
  STEPS = 0,
  CONTINUOUS = 1,
  CONTINUOUS_SNAP = 2
}

export class AdaptiveSliderConfig {
  mode: AdaptiveSliderMode = AdaptiveSliderMode.STEPS;
  steps: number = 3;
  snapPoints: number[] = [];
  snapOnRelease: boolean = true;
  magneticThreshold: number = 0;
  showStepDots: boolean = true;

  static fixed(steps: number, showStepDots: boolean = true): AdaptiveSliderConfig {
    const c = new AdaptiveSliderConfig();
    c.mode = AdaptiveSliderMode.STEPS;
    c.steps = steps;
    c.showStepDots = showStepDots;
    return c;
  }

  static continuous(): AdaptiveSliderConfig {
    const c = new AdaptiveSliderConfig();
    c.mode = AdaptiveSliderMode.CONTINUOUS;
    c.showStepDots = false;
    return c;
  }

  static continuousSnap(points: number[], snapOnRelease: boolean = true,
    magneticThreshold: number = 0): AdaptiveSliderConfig {
    const c = new AdaptiveSliderConfig();
    c.mode = AdaptiveSliderMode.CONTINUOUS_SNAP;
    c.snapPoints = points;
    c.snapOnRelease = snapOnRelease;
    c.magneticThreshold = magneticThreshold;
    return c;
  }
}

@Component
export struct AdaptiveSlider {
  @Prop @Watch('syncValue') value: number = 0.5;
  @Prop config: AdaptiveSliderConfig = AdaptiveSliderConfig.fixed(3);
  onChange: (value: number) => void = (value: number) => {};

  @State private sliderWidth: number = 0;
  @State private thumbPosition: number = 0.5;
  @State private pressed: boolean = false;
  @State private settling: boolean = false;
  @State private trackHeight: number = 20;
  @StorageProp('themeConfigRevision') @Watch('onThemeConfig') themeConfigRevision: number = 0;
  private lastNotified: number = 0.5;
  private readonly centerY: number = 20;

  aboutToAppear(): void {
    this.thumbPosition = this.clamp(this.value);
    this.lastNotified = this.thumbPosition;
    this.loadTrackHeight();
  }

  private onThemeConfig(): void {
    this.loadTrackHeight();
  }

  private loadTrackHeight(): void {
    let h = 20;
    try {
      const raw = getContext(this).resourceManager
        .getNumber($r('sys.float.ohos_id_inset_track_thickness').id);
      if (raw > 0) {
        const vp = raw > 32 ? px2vp(raw) : raw;
        if (vp >= 8 && vp <= 40) h = vp;
      }
    } catch (e) {}
    this.trackHeight = h;
  }

  private syncValue(): void {
    if (!this.pressed && !this.settling) {
      this.thumbPosition = this.clamp(this.value);
      this.lastNotified = this.thumbPosition;
    }
  }

  private clamp(v: number): number {
    return Math.max(0, Math.min(1, v));
  }

  private thumbX(): number {
    const w = Math.max(1, this.sliderWidth);
    return 16 + this.thumbPosition * (w - 32);
  }

  private anchorX(position: number): number {
    const w = Math.max(1, this.sliderWidth);
    return 16 + position * (w - 32);
  }

  private thumbDiameter(): number {
    return this.trackHeight * 0.6;
  }

  private pressedDiameter(): number {
    return this.trackHeight * 1.2;
  }

  private grooveWidth(): number {
    return Math.max(0, this.sliderWidth - 12);
  }

  private flowLength(): number {
    return this.grooveWidth() / 3;
  }

  private flowStart(): number {
    return Math.max(6, this.thumbX() - this.flowLength());
  }

  private flowWidth(): number {
    return Math.max(0, this.thumbX() - this.flowStart());
  }

  private pressedSnapRange(): number {
    if (this.sliderWidth <= 32) return 0;
    return (this.pressedDiameter() / 2) / (this.sliderWidth - 32);
  }

  private snapToPressedNode(raw: number): number {
    const list = this.points();
    if (list.length == 0) return raw;
    let best = list[0];
    let distance = Number.MAX_VALUE;
    for (const p of list) {
      const d = Math.abs(p - raw);
      if (d < distance) {
        distance = d;
        best = p;
      }
    }
    return distance < this.pressedSnapRange() ? best : raw;
  }

  private points(): number[] {
    if (this.config.mode == AdaptiveSliderMode.STEPS) {
      const n = Math.max(2, Math.min(32, Math.round(this.config.steps)));
      const result: number[] = [];
      for (let i = 0; i < n; i++) result.push(i / (n - 1));
      return result;
    }
    if (this.config.mode == AdaptiveSliderMode.CONTINUOUS_SNAP) {
      return this.config.snapPoints.map((p: number) => this.clamp(p)).sort((a: number, b: number) => a - b);
    }
    return [];
  }

  private nearestIn(list: number[]): number {
    if (list.length == 0) return this.thumbPosition;
    let best = list[0];
    let distance = Number.MAX_VALUE;
    for (const p of list) {
      const d = Math.abs(p - this.thumbPosition);
      if (d < distance) {
        distance = d;
        best = p;
      }
    }
    return best;
  }

  private finishPress(): void {
    this.pressed = false;
    if (this.config.mode != AdaptiveSliderMode.STEPS) {
      this.lastNotified = this.thumbPosition;
      this.onChange(this.thumbPosition);
      return;
    }
    const snapped = this.nearestIn(this.points());
    this.settling = true;
    this.lastNotified = snapped;
    animateTo({ duration: 280, curve: Curve.Friction }, () => {
      this.thumbPosition = snapped;
    });
    this.onChange(snapped);
    setTimeout(() => {
      this.settling = false;
      this.thumbPosition = this.clamp(this.value);
    }, 300);
  }

  private emitChange(raw: number, mode: SliderChangeMode): void {
    if (mode == SliderChangeMode.Begin || mode == SliderChangeMode.Moving) {
      this.pressed = true;
      const next = this.clamp(raw);
      if (this.config.mode == AdaptiveSliderMode.CONTINUOUS) {
        this.thumbPosition = next;
        this.lastNotified = next;
        this.onChange(next);
      } else if (this.config.mode == AdaptiveSliderMode.CONTINUOUS_SNAP) {
        const snapped = this.snapToPressedNode(next);
        this.thumbPosition = snapped;
        if (snapped != this.lastNotified) {
          this.lastNotified = snapped;
          this.onChange(snapped);
        }
      } else {
        // Fixed tiers: move the thumb continuously, but do not reveal or
        // commit an intermediate position. The nearest tier is chosen on end.
        this.thumbPosition = next;
      }
    } else if (mode == SliderChangeMode.End || mode == SliderChangeMode.Click) {
      const next = this.clamp(raw);
      if (this.config.mode == AdaptiveSliderMode.CONTINUOUS_SNAP) {
        this.thumbPosition = this.snapToPressedNode(next);
      } else {
        this.thumbPosition = next;
      }
      this.finishPress();
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Slider({
        value: this.thumbPosition * 2,
        min: 0,
        max: 2,
        step: 0.01,
        style: SliderStyle.NONE
      })
        .trackThickness(this.trackHeight)
        .trackColor(Color.Transparent)
        .selectedColor(Color.Transparent)
        .width('100%')
        .height(40)
        .onChange((v: number, mode: SliderChangeMode) => this.emitChange(v / 2, mode))
        .onTouch((event: TouchEvent) => {
          if (event.type == TouchType.Down) {
            this.pressed = true;
          } else if (event.type == TouchType.Up || event.type == TouchType.Cancel) {
            this.finishPress();
          }
        })

      if (this.sliderWidth > 0) {
        Row()
          .width(Math.max(0, this.sliderWidth - 12))
          .height(this.trackHeight).borderRadius(this.trackHeight / 2)
          .backgroundColor($r('sys.color.ohos_id_color_component_normal'))
          .position({ x: 6, y: this.centerY - this.trackHeight / 2 })
          .hitTestBehavior(HitTestMode.None)
      }

      if (this.sliderWidth > 0 && this.thumbPosition > 0.001) {
        Row()
          .width(this.thumbX() + 4)
          .height(this.trackHeight).borderRadius(this.trackHeight / 2)
          .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
          .position({ x: 6, y: this.centerY - this.trackHeight / 2 })
          .hitTestBehavior(HitTestMode.None)
      }

      if (this.config.showStepDots) {
        ForEach(this.points(), (position: number) => {
          if (this.anchorX(position) > this.thumbX() + 10) {
            Circle({ width: 4, height: 4 })
              .fill($r('sys.color.ohos_id_color_foreground'))
              .opacity(0.28)
              .position({ x: this.anchorX(position) - 2, y: this.centerY - 2 })
              .hitTestBehavior(HitTestMode.None)
          }
        }, (position: number) => `point_${position}`)
      }

      if (this.pressed && this.flowWidth() > 4) {
        Particle({
          particles: [
            {
              emitter: {
                particle: {
                  type: ParticleType.POINT,
                  config: { radius: 1.2 },
                  count: -1,
                  lifetime: 12000,
                  lifetimeRange: 0
                },
                emitRate: 72,
                position: [0, 0],
                size: [this.flowWidth(), this.trackHeight],
                shape: ParticleEmitterShape.RECTANGLE
              },
              color: {
                range: [
                  $r('sys.color.ohos_id_color_foreground_contrary'),
                  $r('sys.color.ohos_id_color_emphasize')
                ]
              },
              opacity: { range: [0.65, 1.0] },
              scale: { range: [0.5, 1.2] },
              velocity: { speed: [60, 110], angle: [0, 0] }
            }
          ]
        })
          .width(this.flowWidth()).height(this.trackHeight)
          .position({ x: this.flowStart(), y: this.centerY - this.trackHeight / 2 })
          .clip(true)
          .hitTestBehavior(HitTestMode.None)
      }

      Circle({
        width: this.pressed ? this.pressedDiameter() : this.thumbDiameter(),
        height: this.pressed ? this.pressedDiameter() : this.thumbDiameter()
      })
        .fill($r('sys.color.ohos_id_color_foreground_contrary'))
        .position({
          x: this.thumbX() - (this.pressed ? this.pressedDiameter() : this.thumbDiameter()) / 2,
          y: this.centerY - (this.pressed ? this.pressedDiameter() : this.thumbDiameter()) / 2
        })
        .hitTestBehavior(HitTestMode.None)
    }
    .width('100%').height(40)
    .onAreaChange((oldValue: Area, newValue: Area) => {
      const w = parseFloat(`${newValue.width}`);
      if (!isNaN(w) && w > 0) this.sliderWidth = w;
    })
  }
}
