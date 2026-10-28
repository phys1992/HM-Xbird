import { media } from '@kit.MediaKit';
import { window, display } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';

@Component
export struct FullscreenVideo {
  url: string = '';
  startTime: number = 0;
  posterUrl: string = '';
  onClose: () => void = () => {};
  private controller: XComponentController = new XComponentController();
  private player: media.AVPlayer | null = null;
  private surfaceId: string = '';
  private mainWin: window.Window | null = null;
  private gestureStart: number = 0;
  private gestureMode: number = 0;
  private seekStart: number = 0;
  private hideTimer: number = -1;
  private hudTimer: number = -1;
  private prepared: boolean = false;
  private pendingStart: boolean = false;
  private ignoreGesture: boolean = false;
  private previousOrientation: number = window.Orientation.UNSPECIFIED;
  @State playing: boolean = true;
  @State buffering: boolean = true;
  @State current: number = 0;
  @State duration: number = 0;
  @State error: string = '';
  @State viewW: number = 1;
  @State viewH: number = 1;
  @State fitW: number = 1;
  @State fitH: number = 1;
  @State videoW: number = 16;
  @State videoH: number = 9;
  @State hudVisible: boolean = false;
  @State hudKind: number = 0;
  @State hudValue: number = 0;
  @State seeking: boolean = false;
  @State seekTarget: number = 0;
  @State controlsVisible: boolean = true;
  @State firstFrame: boolean = false;
  @State edgeLeft: number = 0;
  @State edgeRight: number = 0;
  @State videoBrightness: number = 0.5;
  @State videoVolume: number = 0.6;

  aboutToAppear(): void {
    window.getLastWindow(getContext(this) as common.UIAbilityContext).then((win: window.Window) => {
      this.mainWin = win;
      this.previousOrientation = win.getPreferredOrientation();
      win.setPreferredOrientation(window.Orientation.AUTO_ROTATION).catch(() => {});
      try {
        const gestureArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM_GESTURE);
        const d = display.getDefaultDisplaySync();
        this.edgeLeft = gestureArea.leftRect.width / d.densityPixels;
        this.edgeRight = gestureArea.rightRect.width / d.densityPixels;
      } catch (e) {}
      const props = win.getWindowProperties();
      if (props.brightness != undefined && props.brightness > 0) {
        this.videoBrightness = props.brightness;
      }
    }).catch(() => {});
    display.on('change', () => {
      try {
        const d = display.getDefaultDisplaySync();
        const density = d.densityPixels;
        this.viewW = d.width / density;
        this.viewH = d.height / density;
        this.updateFit();
      } catch (e) {}
    });
  }

  aboutToDisappear(): void {
    if (this.hideTimer >= 0) clearTimeout(this.hideTimer);
    this.release();
    if (this.mainWin != null) {
      this.mainWin.setPreferredOrientation(this.previousOrientation as window.Orientation).catch(() => {});
    }
    try { display.off('change'); } catch (e) {}
  }

  private release(): void {
    if (this.player != null) {
      this.player.release();
      this.player = null;
    }
    this.surfaceId = '';
  }

  private updateFit(): void {
    if (this.viewW <= 0 || this.viewH <= 0 || this.videoW <= 0 || this.videoH <= 0) return;
    const scale = Math.min(this.viewW / this.videoW, this.viewH / this.videoH);
    this.fitW = this.videoW * scale;
    this.fitH = this.videoH * scale;
  }

  private init(): void {
    if (this.url.length == 0 || this.surfaceId.length == 0) return;
    const sid = this.surfaceId;
    this.release();
    this.surfaceId = sid;
    media.createAVPlayer((err, player) => {
      if (err) {
        this.error = `播放器初始化失败：${err.message}`;
        this.buffering = false;
        return;
      }
      this.player = player;
      player.on('stateChange', (state: string) => {
        if (state == 'initialized') {
          player.surfaceId = sid;
          player.prepare();
        } else if (state == 'prepared') {
          player.videoScaleType = media.VideoScaleType.VIDEO_SCALE_TYPE_FIT;
          this.duration = player.duration > 0 ? player.duration / 1000 : 0;
          this.prepared = true;
          this.buffering = false;
          this.current = this.startTime;
          player.setVolume(this.videoVolume);
          if (this.startTime > 0) {
            this.pendingStart = true;
            player.seek(Math.floor(this.startTime * 1000));
            setTimeout(() => {
              if (this.pendingStart) {
                this.pendingStart = false;
                this.firstFrame = true;
                player.play();
                this.playing = true;
                this.scheduleHide();
              }
            }, 900);
          } else {
            this.firstFrame = true;
            player.play();
            this.playing = true;
            this.scheduleHide();
          }
        }
      });
      player.on('seekDone', (time: number) => {
        this.current = time / 1000;
        if (this.pendingStart) {
          this.pendingStart = false;
          this.firstFrame = true;
          player.play();
          this.playing = true;
          this.scheduleHide();
        }
      });
      player.on('timeUpdate', (time: number) => {
        if (this.duration > 0) this.current = time / 1000;
      });
      player.on('bufferingUpdate', (infoType: number, value: number) => {
        if (infoType == media.BufferingInfoType.BUFFERING_START) {
          this.buffering = true;
        } else if (infoType == media.BufferingInfoType.BUFFERING_END) {
          this.buffering = false;
        }
      });
      player.on('videoSizeChange', (w: number, h: number) => {
        if (w > 0 && h > 0) {
          this.videoW = w;
          this.videoH = h;
          this.updateFit();
        }
      });
      player.on('error', (e) => {
        this.error = `播放失败：${e.message}`;
        this.buffering = false;
      });
      const headers: Record<string, string> = {
        'Referer': 'https://x.com/',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/142.0.0.0 Safari/537.36'
      };
      try {
        const strategy: media.PlaybackStrategy = {
          preferredBufferDuration: 2,
          preferredBufferDurationForPlaying: 1,
          showFirstFrameOnPrepare: true
        };
        player.setMediaSource(media.createMediaSourceWithUrl(this.url, headers), strategy);
      } catch (e) {
        this.error = `视频源设置失败：${e}`;
        this.buffering = false;
      }
    });
  }

  private scheduleHide(): void {
    if (this.hideTimer >= 0) clearTimeout(this.hideTimer);
    this.hideTimer = setTimeout(() => {
      if (this.playing) {
        animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
          this.controlsVisible = false;
        });
      }
    }, 3000);
  }

  private showControls(): void {
    animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
      this.controlsVisible = true;
    });
    this.scheduleHide();
  }

  private toggleControls(): void {
    if (this.controlsVisible) {
      if (this.hideTimer >= 0) clearTimeout(this.hideTimer);
      animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
        this.controlsVisible = false;
      });
    } else {
      this.showControls();
    }
  }

  private toggle(): void {
    if (this.player == null) return;
    if (this.playing) {
      this.player.pause();
      this.playing = false;
      this.showControls();
      if (this.hideTimer >= 0) clearTimeout(this.hideTimer);
    } else {
      this.player.play();
      this.playing = true;
      this.scheduleHide();
    }
  }

  private seek(value: number): void {
    if (this.player == null || !this.prepared) return;
    this.player.seek(Math.floor(value * 1000));
    this.current = value;
  }

  private time(seconds: number): string {
    const total = Math.max(0, Math.floor(seconds));
    const m = Math.floor(total / 60);
    const s = total % 60;
    return `${m < 10 ? '0' : ''}${m}:${s < 10 ? '0' : ''}${s}`;
  }

  private showHud(kind: number, value: number): void {
    this.hudKind = kind;
    this.hudValue = value;
    this.hudVisible = true;
    if (this.hudTimer >= 0) clearTimeout(this.hudTimer);
    this.hudTimer = setTimeout(() => { this.hudVisible = false; }, 900);
  }

  private adjustBrightness(value: number): void {
    this.videoBrightness = Math.max(0.05, Math.min(1, value));
    if (this.mainWin != null) {
      this.mainWin.setWindowBrightness(this.videoBrightness).catch(() => {});
    }
    this.showHud(0, this.videoBrightness);
  }

  private adjustVolume(value: number): void {
    this.videoVolume = Math.max(0, Math.min(1, value));
    if (this.player != null) this.player.setVolume(this.videoVolume);
    this.showHud(1, this.videoVolume);
  }

  private isFastShort(offset: number, velocity: number): boolean {
    return Math.abs(offset) < 24 && Math.abs(velocity) > 800;
  }

  private seekGestureStart(): void {
    this.ignoreGesture = false;
    this.seekStart = this.current;
    this.seekTarget = this.current;
  }

  private seekGestureUpdate(event: GestureEvent): void {
    if (this.isFastShort(event.offsetX, event.velocityX)) {
      this.ignoreGesture = true;
      this.seeking = false;
      return;
    }
    if (this.ignoreGesture || this.duration <= 0) return;
    const target = this.seekStart + (event.offsetX / this.viewW) * this.duration;
    this.seekTarget = Math.max(0, Math.min(this.duration, target));
    this.seeking = true;
  }

  private seekGestureEnd(event: GestureEvent): void {
    if (this.ignoreGesture || this.isFastShort(event.offsetX, event.velocityX)) {
      this.ignoreGesture = false;
      this.seeking = false;
      return;
    }
    if (this.seeking) {
      this.seek(this.seekTarget);
      setTimeout(() => { this.seeking = false; }, 500);
    }
  }

  private verticalGestureStart(event: GestureEvent): void {
    this.ignoreGesture = false;
    if (event.fingerList.length == 0) return;
    this.gestureMode = event.fingerList[0].localX < this.viewW / 2 ? 0 : 1;
    this.gestureStart = this.gestureMode == 0 ? this.videoBrightness : this.videoVolume;
  }

  private verticalGestureUpdate(event: GestureEvent): void {
    if (this.isFastShort(event.offsetY, event.velocityY)) {
      this.ignoreGesture = true;
      return;
    }
    if (this.ignoreGesture) return;
    const delta = -event.offsetY / (this.viewH * 0.5);
    if (this.gestureMode == 0) this.adjustBrightness(this.gestureStart + delta);
    else this.adjustVolume(this.gestureStart + delta);
  }

  private verticalGestureEnd(): void {
    this.ignoreGesture = false;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      XComponent({
        id: 'fullscreen_video_surface',
        type: XComponentType.SURFACE,
        controller: this.controller
      })
        .width(this.fitW).height(this.fitH)
        .onLoad(() => {
          this.surfaceId = this.controller.getXComponentSurfaceId();
          this.init();
        })
        .onDestroy(() => this.release())

      if (!this.firstFrame && this.posterUrl.length > 0) {
        Image(this.posterUrl)
          .width('100%').height('100%')
          .objectFit(ImageFit.Contain)
          .backgroundColor('#000000')
      }

      // Horizontal seek + tap: whole screen.
      Column()
        .width(this.viewW - this.edgeLeft - this.edgeRight)
        .height('100%')
        .position({ x: this.edgeLeft, y: 0 })
        .backgroundColor(Color.Transparent)
        .gesture(
          GestureGroup(GestureMode.Exclusive,
            TapGesture({ count: 1 }).onAction(() => this.toggle()),
            PanGesture({ direction: PanDirection.Horizontal })
              .onActionStart(() => this.seekGestureStart())
              .onActionUpdate((event: GestureEvent) => this.seekGestureUpdate(event))
              .onActionEnd((event: GestureEvent) => this.seekGestureEnd(event))
          )
        )

      // Brightness/volume: only the middle 50% band.
      Column()
        .width(this.viewW - this.edgeLeft - this.edgeRight)
        .height(this.viewH * 0.5)
        .position({ x: this.edgeLeft, y: this.viewH * 0.25 })
        .backgroundColor(Color.Transparent)
        .gesture(
          GestureGroup(GestureMode.Exclusive,
            TapGesture({ count: 1 }).onAction(() => this.toggle()),
            PanGesture({ direction: PanDirection.Horizontal })
              .onActionStart(() => this.seekGestureStart())
              .onActionUpdate((event: GestureEvent) => this.seekGestureUpdate(event))
              .onActionEnd((event: GestureEvent) => this.seekGestureEnd(event))
          )
        )
        .parallelGesture(
          PanGesture({ direction: PanDirection.Vertical })
            .onActionStart((event: GestureEvent) => this.verticalGestureStart(event))
            .onActionUpdate((event: GestureEvent) => this.verticalGestureUpdate(event))
            .onActionEnd(() => this.verticalGestureEnd())
        )

      if (this.buffering) {
        LoadingProgress()
          .width(48).height(48)
          .color('#FFFFFF')
      }

      if (this.error.length > 0) {
        Text(this.error).fontSize(12).fontColor('#FFFFFF')
          .backgroundColor('#99000000').padding(10).borderRadius(8)
      }

      if (this.hudVisible) {
        Column() {
          Image(this.hudKind == 0 ? $r('app.media.ic_brightness') : $r('sys.media.ohos_ic_public_sound'))
            .width(26).height(26)
          Progress({ value: this.hudValue * 100, total: 100, type: ProgressType.Linear })
            .width(150).height(4).color('#FFFFFF').backgroundColor('#66FFFFFF')
            .margin({ top: 10 })
          Text(`${Math.round(this.hudValue * 100)}%`)
            .fontSize(12).fontColor('#FFFFFF').margin({ top: 6 })
        }
        .padding({ left: 20, right: 20, top: 14, bottom: 14 })
        .borderRadius(18)
        .backgroundColor('#99000000')
      }

      if (this.seeking) {
        Column() {
          Text(`${this.time(this.seekTarget)} / ${this.time(this.duration)}`)
            .fontSize(13).fontColor('#FFFFFF')
          Progress({ value: this.seekTarget, total: this.duration > 0 ? this.duration : 1, type: ProgressType.Linear })
            .width(160).height(3).color('#FFFFFF').backgroundColor('#66FFFFFF')
            .margin({ top: 8 })
        }
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })
        .borderRadius(14)
        .backgroundColor('#99000000')
      }

      if (this.controlsVisible) {
      Column() {
        Row() {
          Button() {
            Image($r('sys.media.ohos_ic_public_close')).width(22).height(22)
          }
          .backgroundColor('#66000000').width(36).height(36)
          .onClick(() => this.onClose())
          Blank()
        }.width('100%').padding({ top: 16, left: 16, right: 16 })

        Blank()

        Row() {
          Button() {
            Image(this.playing ? $r('sys.media.ohos_ic_public_pause') : $r('sys.media.ohos_ic_public_play'))
              .width(26).height(26)
          }
          .backgroundColor('#66000000').width(48).height(48).borderRadius(24)
          .onClick(() => this.toggle())
        }

        Blank()

        Column() {
          Row() {
            Text(this.time(this.current)).fontSize(12).fontColor('#FFFFFF').width(44)
            Slider({
              value: this.seeking ? this.seekTarget : this.current,
              min: 0,
              max: this.duration > 0 ? this.duration : 1,
              step: 1,
              style: SliderStyle.OutSet
            })
              .layoutWeight(1)
              .selectedColor('#FFFFFF')
              .trackColor('#66FFFFFF')
              .blockColor('#FFFFFF')
              .onChange((value: number, mode: SliderChangeMode) => {
                if (mode == SliderChangeMode.End) this.seek(value);
              })
            Text(this.time(this.duration)).fontSize(12).fontColor('#FFFFFF').width(44)
          }.width('100%')
        }.width('100%').padding({ left: 16, right: 16, bottom: 24 })
      }
      .width('100%').height('100%')
      .hitTestBehavior(HitTestMode.Transparent)
      .transition(TransitionEffect.OPACITY.animation({ duration: 180, curve: Curve.EaseOut }))
      }
    }
    .width('100%').height('100%')
    .backgroundColor('#000000')
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.viewW = parseFloat(`${newValue.width}`);
      this.viewH = parseFloat(`${newValue.height}`);
      this.updateFit();
    })
  }
}
