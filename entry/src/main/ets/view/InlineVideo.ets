import { media } from '@kit.MediaKit';
import { VideoAutoplay } from '../model/VideoAutoplay';
import { PlaybackSettingsStore } from '../model/PlaybackSettings';
import { common } from '@kit.AbilityKit';
import { I18n } from '../model/I18n';

@Component
export struct InlineVideo {
  @StorageProp('clientLang') clientLanguage: string = 'zh';
  private tr(value: string): string {
    return this.clientLanguage.length >= 0 ? I18n.t(value) : I18n.t(value);
  }

  url: string = '';
  posterUrl: string = '';
  videoId: string = '';
  pane: string = 'left';
  index: number = 0;
  surfaceName: string = 'inline_video_surface';
  onFullscreen: (time: number) => void = () => {};
  private controller: XComponentController = new XComponentController();
  private player: media.AVPlayer | null = null;
  private surfaceId: string = '';
  @State playing: boolean = true;
  @State buffering: boolean = true;
  @State current: number = 0;
  @State firstFrame: boolean = false;
  @State duration: number = 0;
  @State error: string = '';
  @State muted: boolean = true;
  @State controlsVisible: boolean = true;
  @State volumeRatio: number = 0.5;
  @State videoAspect: number = 16 / 9;
  private pendingAuto: boolean = false;
  private pendingAutoMuted: boolean = true;
  private pendingAutoVolume: number = 0.5;
  private prepared: boolean = false;
  private hasAudio: boolean = false;
  private hideTimer: number = -1;

  aboutToAppear(): void {
    try {
      const settings = PlaybackSettingsStore.load(getContext(this) as common.UIAbilityContext);
      this.volumeRatio = settings.volumeRatio;
      this.muted = settings.autoPlayMuted;
    } catch (e) {}
  }

  aboutToDisappear(): void {
    if (this.hideTimer >= 0) clearTimeout(this.hideTimer);
    VideoAutoplay.remove(this.videoId);
    this.release();
  }

  private release(): void {
    this.prepared = false;
    if (this.player != null) {
      this.player.release();
      this.player = null;
    }
    this.surfaceId = '';
  }

  private init(): void {
    if (this.url.length == 0 || this.surfaceId.length == 0) return;
    const sid = this.surfaceId;
    this.release();
    this.surfaceId = sid;
    media.createAVPlayer((err, player) => {
      if (err) {
        this.error = this.tr(`播放器初始化失败：${err.message}`);
        return;
      }
      this.player = player;
      player.on('stateChange', (state: string) => {
        if (state == 'initialized') {
          // SurfaceID is only writable in the initialized state.
          player.surfaceId = sid;
          player.prepare();
        } else if (state == 'prepared') {
          player.loop = false;
          this.error = '';
          this.duration = player.duration > 0 ? player.duration / 1000 : 0;
          this.buffering = false;
          player.videoScaleType = media.VideoScaleType.VIDEO_SCALE_TYPE_FIT;
          player.getTrackDescription().then((tracks: media.MediaDescription[]) => {
            this.hasAudio = false;
            for (const track of tracks) {
              if (track[media.MediaDescriptionKey.MD_KEY_TRACK_TYPE] == media.MediaType.MEDIA_TYPE_AUD) {
                this.hasAudio = true;
              }
            }
            this.prepared = true;
            this.playing = false;
            if (this.pendingAuto) {
              this.pendingAuto = false;
              this.startAuto(this.pendingAutoMuted, this.pendingAutoVolume);
            }
          }).catch(() => {
            this.prepared = true;
            this.playing = false;
            if (this.pendingAuto) {
              this.pendingAuto = false;
              this.startAuto(this.pendingAutoMuted, this.pendingAutoVolume);
            }
          });
        } else if (state == 'playing') {
          this.applyAudio(this.muted, this.volumeRatio);
        } else if (state == 'completed') {
          this.playing = false;
          this.showControls();
          VideoAutoplay.onCompleted(this.videoId);
        }
      });
      player.on('startRenderFrame', () => {
        this.firstFrame = true;
        this.buffering = false;
      });
      player.on('timeUpdate', (time: number) => {
        this.current = time / 1000;
      });
      player.on('durationUpdate', (duration: number) => {
        if (duration > 0) this.duration = duration / 1000;
      });
      player.on('videoSizeChange', (w: number, h: number) => {
        if (w > 0 && h > 0) this.videoAspect = w / h;
      });
      player.on('bufferingUpdate', (infoType: number, value: number) => {
        if (infoType == media.BufferingInfoType.BUFFERING_START) this.buffering = true;
        else if (infoType == media.BufferingInfoType.BUFFERING_END) this.buffering = false;
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
          showFirstFrameOnPrepare: true
        };
        player.setMediaSource(media.createMediaSourceWithUrl(this.url, headers), strategy);
      } catch (e) {
        this.error = this.tr(`视频源设置失败：${e}`);
      }
    });
  }

  private applyAudio(muted: boolean, volume: number): void {
    this.muted = muted;
    this.volumeRatio = volume;
    if (this.player != null && this.hasAudio) {
      try {
        this.player.setVolume(muted ? 0 : volume);
      } catch (e) {}
    }
  }

  private startAuto(muted: boolean, volume: number): void {
    this.muted = muted;
    this.volumeRatio = volume;
    if (this.player == null || !this.prepared) {
      this.pendingAuto = true;
      this.pendingAutoMuted = muted;
      this.pendingAutoVolume = volume;
      return;
    }
    this.player.play();
    this.playing = true;
    this.applyAudio(muted, volume);
    this.scheduleHide();
  }

  private resumeManual(): void {
    if (this.player == null || !this.prepared) return;
    this.player.play();
    this.playing = true;
    this.scheduleHide();
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
      VideoAutoplay.manualPause(this.videoId);
      this.showControls();
      if (this.hideTimer >= 0) clearTimeout(this.hideTimer);
    } else {
      if (VideoAutoplay.hasCandidate(this.videoId)) {
        VideoAutoplay.manualPlay(this.videoId);
      } else {
        this.resumeManual();
      }
      this.showControls();
    }
  }

  private toggleMuted(): void {
    const next = !this.muted;
    this.applyAudio(next, 1);
    this.showControls();
  }

  private seek(value: number): void {
    if (this.player == null || !this.prepared) return;
    this.player.seek(Math.floor(value * 1000));
    this.current = value;
  }

  private reportVisible(ratio: number): void {
    VideoAutoplay.report(this.videoId, this.pane, this.index, ratio,
      (muted: boolean, volume: number) => this.startAuto(muted, volume),
      () => this.resumeManual(),
      () => { if (this.player != null) { this.player.pause(); this.playing = false; } },
      () => this.playing);
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      XComponent({
        id: this.surfaceName,
        type: XComponentType.SURFACE,
        controller: this.controller
      })
        .width('100%').height('100%')
        .onLoad(() => {
          this.surfaceId = this.controller.getXComponentSurfaceId();
          this.init();
        })
        .onDestroy(() => this.release())
        .gesture(
          GestureGroup(GestureMode.Exclusive,
            TapGesture({ count: 2 }).onAction(() => this.toggle()),
            TapGesture({ count: 1 }).onAction(() => this.toggleControls())
          )
        )

      if (!this.firstFrame && this.posterUrl.length > 0) {
        Image(this.posterUrl)
          .width('100%').height('100%')
          .objectFit(ImageFit.Contain)
          .backgroundColor('#000000')
      }

      if (this.controlsVisible) {
        Row() {
          Button() {
            Image(this.playing ? $r('sys.media.ohos_ic_public_pause') : $r('sys.media.ohos_ic_public_play'))
              .width(18).height(18).fillColor('#FFFFFF')
          }
          .width(32).height(32).padding(0).borderRadius(16)
          .backgroundColor('#99000000')
          .onClick(() => this.toggle())

          Slider({
            value: this.current,
            min: 0,
            max: this.duration > 0 ? this.duration : 1,
            step: 1,
            style: SliderStyle.InSet
          })
            .layoutWeight(1).margin({ left: 8, right: 8 })
            .selectedColor('#FFFFFF')
            .trackColor('#66FFFFFF')
            .blockColor('#FFFFFF')
            .onChange((value: number, mode: SliderChangeMode) => {
              this.showControls();
              if (mode == SliderChangeMode.End) this.seek(value);
            })

          Button() {
            Image(this.muted ? $r('sys.media.ohos_ic_public_sound_off') : $r('sys.media.ohos_ic_public_sound'))
              .width(18).height(18).fillColor('#FFFFFF')
          }
          .width(32).height(32).padding(0).borderRadius(16)
          .backgroundColor('#99000000')
          .onClick(() => this.toggleMuted())

          Button() {
            Image($r('app.media.ic_fullscreen')).width(18).height(18).fillColor('#FFFFFF')
          }
          .width(32).height(32).padding(0).borderRadius(16)
          .backgroundColor('#99000000').margin({ left: 8 })
          .onClick(() => {
            if (this.player != null) this.player.pause();
            this.playing = false;
            VideoAutoplay.manualPause(this.videoId);
            this.onFullscreen(this.current);
          })
        }.width('100%').padding({ left: 8, right: 8, bottom: 8 })
        .transition(TransitionEffect.OPACITY.animation({ duration: 180, curve: Curve.EaseOut }))
      }

      if (this.buffering) {
        Column() {
          LoadingProgress().width(32).height(32).color('#FFFFFF')
        }.width('100%').height('100%').justifyContent(FlexAlign.Center)
      }

      if (this.error.length > 0) {
        Text(this.error).fontSize(11).fontColor('#FFFFFF')
          .backgroundColor('#99000000').padding(6).borderRadius(6)
          .margin({ bottom: 40 })
      }
    }
    .width('100%').aspectRatio(this.videoAspect)
    .borderRadius(12).clip(true)
    .backgroundColor('#000000')
    .onVisibleAreaChange([0, 0.25, 0.5, 0.99, 1], (isExpanding: boolean, ratio: number) => {
      this.reportVisible(ratio);
    })
  }
}
