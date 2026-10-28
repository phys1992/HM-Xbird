import { media } from '@kit.MediaKit';

@Component
export struct InlineVideo {
  url: string = '';
  surfaceName: string = 'inline_video_surface';
  onFullscreen: (time: number) => void = () => {};
  private controller: XComponentController = new XComponentController();
  private player: media.AVPlayer | null = null;
  private surfaceId: string = '';
  @State playing: boolean = true;
  @State buffering: boolean = true;
  @State current: number = 0;
  @State error: string = '';

  aboutToDisappear(): void {
    this.release();
  }

  private release(): void {
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
        this.error = `播放器初始化失败：${err.message}`;
        return;
      }
      this.player = player;
      player.on('stateChange', (state: string) => {
        if (state == 'initialized') {
          // SurfaceID is only writable in the initialized state.
          player.surfaceId = sid;
          player.prepare();
        } else if (state == 'prepared') {
          player.loop = true;
          this.error = '';
          this.buffering = false;
          player.play();
          this.playing = true;
        }
      });
      player.on('timeUpdate', (time: number) => {
        this.current = time / 1000;
      });
      player.on('bufferingUpdate', (infoType: number, value: number) => {
        if (infoType == media.BufferingInfoType.BUFFERING_START) this.buffering = true;
        else if (infoType == media.BufferingInfoType.BUFFERING_END) this.buffering = false;
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
      }
    });
  }

  private toggle(): void {
    if (this.player == null) return;
    if (this.playing) {
      this.player.pause();
      this.playing = false;
    } else {
      this.player.play();
      this.playing = true;
    }
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
          TapGesture({ count: 1 })
            .onAction(() => this.toggle())
        )

      Row() {
        Button() {
          Image(this.playing ? $r('sys.media.ohos_ic_public_pause') : $r('sys.media.ohos_ic_public_play'))
            .width(20).height(20)
        }
        .width(32).height(32).backgroundColor('#99000000')
        .onClick(() => this.toggle())
        Blank()
        Button() {
          Image($r('app.media.ic_fullscreen')).width(18).height(18)
        }
        .width(32).height(32).backgroundColor('#99000000')
        .onClick(() => {
          if (this.player != null) this.player.pause();
          this.playing = false;
          this.onFullscreen(this.current);
        })
      }.width('100%').padding({ left: 8, right: 8, bottom: 8 })

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
    .width('100%').aspectRatio(1.7)
    .borderRadius(12).clip(true)
    .backgroundColor('#000000')
  }
}
