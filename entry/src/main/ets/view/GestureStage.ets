@Component
export struct GestureStage {
  @Prop phase: number = 0;
  @Prop progress: number = 0;
  @Prop availableWidth: number = 0;
  @Prop screenAspect: number = 0.9;
  @Prop isDark: boolean = false;
  @Prop caption: string = '';
  @Prop subtitle: string = '';
  @Prop videoLabel: string = '';

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

  private screenWidth(): number {
    return Math.max(1, this.deviceWidth() - 10);
  }

  private screenHeight(): number {
    return Math.max(1, this.deviceHeight() - 10);
  }

  private fingerWidth(): number {
    return Math.min(46, Math.max(28, this.deviceWidth() * 0.18));
  }

  private fingerHeight(): number {
    return this.fingerWidth() * (150 / 90);
  }

  private contactX(): number {
    if (this.phase == 0) return this.screenWidth() * 0.10;
    if (this.phase == 1) return this.screenWidth() * 0.90;
    return this.screenWidth() * (0.10 + this.progress * 0.80);
  }

  private contactY(): number {
    if (this.phase == 2) return this.screenHeight() * 0.91;
    return this.screenHeight() * (0.70 - this.progress * 0.40);
  }

  private fingerX(): number {
    if (this.phase == 0) return -this.fingerWidth() * 0.55;
    if (this.phase == 1) return this.deviceWidth() - this.fingerWidth() * 0.45;
    return 5 + this.contactX() - this.fingerWidth() * 0.5;
  }

  private fingerY(): number {
    return 5 + this.contactY() - this.fingerHeight() * 0.13;
  }

  private fingerTilt(): number {
    if (this.phase == 0) return 30;
    if (this.phase == 1) return -30;
    return 0;
  }

  private hudWidth(): number {
    return Math.min(126, this.deviceWidth() * 0.66);
  }

  private hudBarWidth(): number {
    return this.hudWidth() - 18;
  }

  private percent(): number {
    return this.phase == 0 ? 30 + this.progress * 62 : 30 + this.progress * 58;
  }

  private timeText(): string {
    const total = 225;
    const current = 12 + this.progress * (total - 12);
    return `${this.clock(current)} / 03:45`;
  }

  private clock(seconds: number): string {
    const s = Math.max(0, Math.round(seconds));
    const m = Math.floor(s / 60);
    const r = s % 60;
    return `${m < 10 ? '0' : ''}${m}:${r < 10 ? '0' : ''}${r}`;
  }

  private frameColor(): string {
    return this.isDark ? '#C7D2DA' : '#303941';
  }

  private frameEdge(): string {
    return this.isDark ? '#EEF3F7' : '#10161B';
  }

  private screenColor(): string {
    return this.isDark ? '#05080B' : '#F4F7F9';
  }

  private hintColor(): string {
    return this.isDark ? 'rgba(255,255,255,0.24)' : 'rgba(15,20,25,0.34)';
  }

  build() {
    Column() {
      Stack({ alignContent: Alignment.TopStart }) {
        Stack({ alignContent: Alignment.Center }) {
          Stack({ alignContent: Alignment.Center }) {
            Text(this.videoLabel).fontSize(8).fontColor(this.hintColor())
            Column() {
              if (this.phase == 2) {
                Text(this.timeText()).fontSize(9).fontColor('#FFFFFF')
              } else {
                Row() {
                  Image(this.phase == 0 ? $r('app.media.ic_brightness') : $r('app.media.ic_volume_hud'))
                    .width(13).height(13)
                  Text(`${Math.round(this.percent())}%`).fontSize(10).fontColor('#FFFFFF').margin({ left: 5 })
                }.alignItems(VerticalAlign.Center)
              }
              Progress({
                value: this.phase == 2 ? this.progress * 100 : this.percent(),
                total: 100,
                type: ProgressType.Linear
              })
                .width(this.hudBarWidth()).height(3)
                .color('#FFFFFF').backgroundColor('#5CFFFFFF')
                .margin({ top: 5 })
            }
            .padding({ left: 9, right: 9, top: 8, bottom: 7 })
            .width(this.hudWidth())
            .backgroundColor('#B8000000').borderRadius(12)
          }
          .width(this.screenWidth()).height(this.screenHeight())
          .backgroundColor(this.screenColor()).borderRadius(12)
          .clip(true)
          .position({ x: 5, y: 5 })
        }
        .width(this.deviceWidth()).height(this.deviceHeight())
        .backgroundColor(this.frameColor())
        .border({ width: 2, color: this.frameEdge() })
        .borderRadius(22)

        Image($r('app.media.gesture_finger'))
          .width(this.fingerWidth()).height(this.fingerHeight())
          .position({ x: this.fingerX(), y: this.fingerY() })
          .rotate({ angle: this.fingerTilt() })
          .zIndex(10)
      }
      .width(this.deviceWidth()).height(this.deviceHeight())
      .clip(false)

      Text(this.caption).fontSize(14).fontColor($r('app.color.text_primary')).margin({ top: 12 })
      Text(this.subtitle).fontSize(10).fontColor($r('app.color.text_secondary')).margin({ top: 3 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }
}
