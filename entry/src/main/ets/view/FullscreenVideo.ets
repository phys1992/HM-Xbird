import { media } from '@kit.MediaKit';
import { audio } from '@kit.AudioKit';
import { window, display } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { PlaybackSettingsStore } from '../model/PlaybackSettings';
import { I18n } from '../model/I18n';
import { SystemVolumeBridge } from './SystemVolumeBridge';

@Component
export struct FullscreenVideo {
  @StorageProp('clientLang') clientLanguage: string = 'zh';
  private tr(value: string): string {
    return this.clientLanguage.length >= 0 ? I18n.t(value) : I18n.t(value);
  }

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
  private gestureAxis: number = 0;
  private gestureActive: boolean = false;
  private hideTimer: number = -1;
  private lastTapAt: number = 0;
  private lastPlayTapAt: number = 0;
  private hudTimer: number = -1;
  private prepared: boolean = false;
  private pendingStart: boolean = false;
  private ignoreGesture: boolean = false;
  private previousOrientation: number = window.Orientation.UNSPECIFIED;
  private systemVolumeListener: ((event: audio.VolumeEvent) => void) | null = null;
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
  @State videoVolume: number = 0;
  @State systemVolume: number = 0;
  @State systemVolumeMax: number = 15;
  @State systemVolumeReady: boolean = false;
  @State configuredVolume: number = 0.5;
  @State muted: boolean = true;
  @State gesturesEnabled: boolean = true;

  aboutToAppear(): void {
    try {
      const settings = PlaybackSettingsStore.load(getContext(this) as common.UIAbilityContext);
      // Fullscreen output is controlled by system media volume. Keep the
      // stream at unity so there is no second, conflicting attenuation.
      this.muted = false;
      this.configuredVolume = 1;
      this.videoVolume = 1;
      this.gesturesEnabled = settings.fullscreenGestures;
    } catch (e) {}
    this.initSystemVolume();
    window.getLastWindow(getContext(this) as common.UIAbilityContext).then((win: window.Window) => {
      this.mainWin = win;
      this.previousOrientation = win.getPreferredOrientation();
      win.setPreferredOrientation(window.Orientation.AUTO_ROTATION_UNSPECIFIED).catch(() => {});
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
    this.unsubscribeSystemVolume();
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
        this.error = this.tr(`播放器初始化失败：${err.message}`);
        this.buffering = false;
        return;
      }
      this.player = player;
      player.on('stateChange', (state: string) => {
        if (state == 'initialized') {
          player.surfaceId = sid;
          player.prepare();
        } else if (state == 'prepared') {
          player.loop = false;
          player.videoScaleType = media.VideoScaleType.VIDEO_SCALE_TYPE_FIT;
          this.duration = player.duration > 0 ? player.duration / 1000 : 0;
          this.prepared = true;
          this.buffering = false;
          this.current = this.startTime;
          this.applyVolume();
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
        } else if (state == 'completed') {
          this.playing = false;
          this.showControls();
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
      player.on('durationUpdate', (duration: number) => {
        if (duration > 0) this.duration = duration / 1000;
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
        this.error = this.tr(`播放失败：${e.message}`);
        this.buffering = false;
      });
      const headers: Record<string, string> = {
        'Referer': 'https://x.com/',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/142.0.0.0 Safari/537.36'
      };
      try {
        const strategy: media.PlaybackStrategy = {
          preferredBufferDuration: 3,
          showFirstFrameOnPrepare: true,
          // Request the HDR variant when the source and device support it.
          // Actual HDR rendering remains controlled by the system display settings.
          preferredHdr: true
        };
        player.setMediaSource(media.createMediaSourceWithUrl(this.url, headers), strategy);
      } catch (e) {
        this.error = this.tr(`视频源设置失败：${e}`);
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
    const now = Date.now();
    if (now - this.lastTapAt < 250) return;
    this.lastTapAt = now;
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
      this.showControls();
    }
  }

  private toggleFromDoubleTap(): void {
    const now = Date.now();
    if (now - this.lastPlayTapAt < 300) return;
    this.lastPlayTapAt = now;
    this.toggle();
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

  private initSystemVolume(): void {
    try {
      const volumeManager = audio.getAudioManager().getVolumeManager();
      const group = volumeManager.getVolumeGroupManagerSync(audio.DEFAULT_VOLUME_GROUP_ID);
      group.getMaxVolume(audio.AudioVolumeType.MEDIA).then((max: number) => {
        this.systemVolumeMax = Math.max(1, max);
        group.getVolume(audio.AudioVolumeType.MEDIA).then((current: number) => {
          this.systemVolume = Math.max(0, Math.min(this.systemVolumeMax, current));
          this.systemVolumeReady = true;
        }).catch(() => {});
      }).catch(() => {});
      this.systemVolumeListener = (event: audio.VolumeEvent) => {
        if (event.volumeType != audio.AudioVolumeType.MEDIA) return;
        this.systemVolume = Math.max(0, Math.min(this.systemVolumeMax, event.volume));
        if (this.hudVisible && this.hudKind == 1) {
          this.hudValue = this.systemVolume / this.systemVolumeMax;
        }
      };
      volumeManager.on('volumeChange', this.systemVolumeListener);
    } catch (e) {}
  }

  private unsubscribeSystemVolume(): void {
    if (this.systemVolumeListener == null) return;
    try {
      audio.getAudioManager().getVolumeManager().off('volumeChange', this.systemVolumeListener);
    } catch (e) {}
    this.systemVolumeListener = null;
  }

  private adjustSystemVolume(value: number): void {
    if (!this.systemVolumeReady) {
      this.adjustVolume(value);
      return;
    }
    const max = Math.max(1, this.systemVolumeMax);
    const next = Math.max(0, Math.min(max, Math.round(value * max)));
    this.systemVolume = next;
    // A system-volume gesture must not remain inaudible because the player
    // stream was left muted or attenuated from an earlier session.
    if (this.muted || this.videoVolume < 1) {
      this.videoVolume = 1;
      this.muted = false;
      this.applyVolume();
    }
    this.showHud(1, next / max);
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

  private applyVolume(): void {
    if (this.player != null) {
      try {
        this.player.setVolume(this.muted ? 0 : this.videoVolume);
      } catch (e) {}
    }
  }

  private adjustVolume(value: number): void {
    this.videoVolume = Math.max(0, Math.min(1, value));
    if (this.videoVolume > 0) this.configuredVolume = this.videoVolume;
    this.muted = this.videoVolume <= 0;
    this.applyVolume();
    this.showHud(1, this.videoVolume);
  }

  private isFastShort(offset: number, velocity: number): boolean {
    return Math.abs(offset) < 24 && Math.abs(velocity) > 800;
  }

  private beginGesture(): void {
    if (!this.gestureActive) {
      this.gestureActive = true;
      this.gestureAxis = 0;
    }
  }

  private seekGestureStart(): void {
    this.beginGesture();
    if (!this.gesturesEnabled) {
      this.ignoreGesture = true;
      return;
    }
    this.ignoreGesture = false;
    this.seekStart = this.current;
    this.seekTarget = this.current;
  }

  private resolveGestureAxis(event: GestureEvent): number {
    if (this.gestureAxis == 0) {
      const ax = Math.abs(event.offsetX);
      const ay = Math.abs(event.offsetY);
      if (ax < 3 && ay < 3) return 0;
      // Once the dominant direction is picked, this touch keeps that mode.
      this.gestureAxis = ax > ay ? 1 : 2;
    }
    return this.gestureAxis;
  }

  private seekGestureUpdate(event: GestureEvent): void {
    if (this.resolveGestureAxis(event) != 1) return;
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
    this.gestureActive = false;
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
    this.beginGesture();
    if (!this.gesturesEnabled) return;
    this.ignoreGesture = false;
    if (event.fingerList.length == 0) return;
    this.gestureMode = event.fingerList[0].localX < this.viewW / 2 ? 0 : 1;
    this.gestureStart = this.gestureMode == 0 ? this.videoBrightness :
      (this.systemVolumeReady ? this.systemVolume / this.systemVolumeMax : this.videoVolume);
  }

  private verticalGestureUpdate(event: GestureEvent): void {
    if (!this.gesturesEnabled) return;
    if (this.resolveGestureAxis(event) != 2) return;
    if (this.isFastShort(event.offsetY, event.velocityY)) {
      this.ignoreGesture = true;
      return;
    }
    if (this.ignoreGesture) return;
    const delta = -event.offsetY / (this.viewH * 0.5);
    if (this.gestureMode == 0) this.adjustBrightness(this.gestureStart + delta);
    else this.adjustSystemVolume(this.gestureStart + delta);
  }

  private verticalGestureEnd(): void {
    this.gestureActive = false;
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
            TapGesture({ count: 2 }).onAction(() => this.toggleFromDoubleTap()),
            TapGesture({ count: 1 }).onAction((event: GestureEvent) => {
              if (event.fingerList.length > 0 && event.fingerList[0].localY > this.viewH - 140) return;
              this.toggleControls();
            }),
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
            TapGesture({ count: 2 }).onAction(() => this.toggleFromDoubleTap()),
            TapGesture({ count: 1 }).onAction(() => this.toggleControls()),
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
          Image(this.hudKind == 0 ? $r('app.media.ic_brightness') : $r('app.media.ic_volume_hud'))
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
        Button() {
          Image($r('sys.media.ohos_ic_public_close')).width(22).height(22).fillColor('#FFFFFF')
        }
        .backgroundColor('#66000000').width(36).height(36).borderRadius(18)
        .position({ x: 16, y: 16 })
        .onClick(() => this.onClose())
        .transition(TransitionEffect.OPACITY.animation({ duration: 180, curve: Curve.EaseOut }))

        Row() {
          Button() {
            Image(this.playing ? $r('sys.media.ohos_ic_public_pause') : $r('sys.media.ohos_ic_public_play'))
              .width(22).height(22).fillColor('#FFFFFF')
          }
          .backgroundColor('#66000000').width(36).height(36).borderRadius(18)
          .onClick(() => this.toggle())

          Text(`${this.time(this.current)} / ${this.time(this.duration)}`)
            .fontSize(11).fontColor('#FFFFFF').margin({ left: 8 })

          Slider({
            value: this.seeking ? this.seekTarget : this.current,
            min: 0,
            max: this.duration > 0 ? this.duration : 1,
            step: 1,
            style: SliderStyle.InSet
          })
            .layoutWeight(1).margin({ left: 8 })
            .selectedColor('#FFFFFF')
            .trackColor('#66FFFFFF')
            .blockColor('#FFFFFF')
            .enabled(!this.gesturesEnabled)
            .onChange((value: number, mode: SliderChangeMode) => {
              this.showControls();
              if (mode == SliderChangeMode.End) this.seek(value);
            })

          if (!this.gesturesEnabled) {
            Slider({
              value: this.muted ? 0 : this.videoVolume,
              min: 0,
              max: 1,
              step: 0.01,
              style: SliderStyle.InSet
            })
              .width(120).margin({ left: 12 })
              .selectedColor('#FFFFFF')
              .trackColor('#66FFFFFF')
              .blockColor('#FFFFFF')
              .onChange((value: number) => {
                this.showControls();
                this.adjustVolume(value);
              })
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 24 })
        .position({ x: 0, y: Math.max(0, this.viewH - 84) })
        .transition(TransitionEffect.OPACITY.animation({ duration: 180, curve: Curve.EaseOut }))
      }
      if (this.systemVolumeReady) {
        SystemVolumeBridge({ volume: this.systemVolume })
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
