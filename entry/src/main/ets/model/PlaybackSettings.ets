import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const STORE_NAME = 'x_session';
const KEY_AUTOPLAY = 'video_autoplay';
const KEY_AUTOPLAY_MUTED = 'video_autoplay_muted';
const KEY_FULLSCREEN_MUTED = 'video_fullscreen_muted';
const KEY_VOLUME = 'video_volume_ratio';
const KEY_FULLSCREEN_VOLUME = 'video_fullscreen_volume_ratio';
const KEY_GESTURES = 'video_fullscreen_gestures';

export class PlaybackSettings {
  autoPlay: boolean = false;
  autoPlayMuted: boolean = true;
  fullscreenMuted: boolean = true;
  volumeRatio: number = 0.5;
  fullscreenVolumeRatio: number = 0.5;
  fullscreenGestures: boolean = true;
}

export class PlaybackSettingsStore {
  private static store: preferences.Preferences | null = null;

  private static getStore(context: common.UIAbilityContext): preferences.Preferences {
    if (PlaybackSettingsStore.store == null) {
      PlaybackSettingsStore.store = preferences.getPreferencesSync(context, { name: STORE_NAME });
    }
    return PlaybackSettingsStore.store;
  }

  static load(context: common.UIAbilityContext): PlaybackSettings {
    const store = PlaybackSettingsStore.getStore(context);
    const settings = new PlaybackSettings();
    const auto = store.getSync(KEY_AUTOPLAY, false);
    const autoMuted = store.getSync(KEY_AUTOPLAY_MUTED, true);
    const fsMuted = store.getSync(KEY_FULLSCREEN_MUTED, true);
    const volume = store.getSync(KEY_VOLUME, 0.5);
    const gestures = store.getSync(KEY_GESTURES, true);
    settings.autoPlay = typeof auto == 'boolean' ? auto as boolean : false;
    settings.autoPlayMuted = typeof autoMuted == 'boolean' ? autoMuted as boolean : true;
    settings.fullscreenMuted = typeof fsMuted == 'boolean' ? fsMuted as boolean : true;
    settings.volumeRatio = typeof volume == 'number' ? Math.max(0, Math.min(1, volume as number)) : 0.5;
    const fsVolume = store.getSync(KEY_FULLSCREEN_VOLUME, settings.volumeRatio);
    settings.fullscreenVolumeRatio = typeof fsVolume == 'number' ?
      Math.max(0, Math.min(1, fsVolume as number)) : settings.volumeRatio;
    settings.fullscreenGestures = typeof gestures == 'boolean' ? gestures as boolean : true;
    return settings;
  }

  static save(context: common.UIAbilityContext, settings: PlaybackSettings): void {
    const store = PlaybackSettingsStore.getStore(context);
    store.putSync(KEY_AUTOPLAY, settings.autoPlay);
    store.putSync(KEY_AUTOPLAY_MUTED, settings.autoPlayMuted);
    store.putSync(KEY_FULLSCREEN_MUTED, settings.fullscreenMuted);
    store.putSync(KEY_VOLUME, settings.volumeRatio);
    store.putSync(KEY_FULLSCREEN_VOLUME, settings.fullscreenVolumeRatio);
    store.putSync(KEY_GESTURES, settings.fullscreenGestures);
    store.flush();
  }
}
