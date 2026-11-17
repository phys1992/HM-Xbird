import { AVVolumePanel } from '@kit.AudioKit';

@Component
export struct SystemVolumeBridge {
  @Prop volume: number = 0;

  build() {
    AVVolumePanel({
      volumeLevel: this.volume,
      volumeParameter: {
        position: { x: -1000, y: -1000 }
      }
    })
      .width(1)
      .height(1)
  }
}
