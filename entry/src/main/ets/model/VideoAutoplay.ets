import { PlaybackSettings } from './PlaybackSettings';

class VideoCandidate {
  id: string = '';
  pane: string = 'left';
  index: number = 0;
  ratio: number = 0;
  autoStart: (muted: boolean, volume: number) => void = () => {};
  resume: () => void = () => {};
  pause: () => void = () => {};
  playing: () => boolean = () => false;
}

export class VideoAutoplay {
  private static settings: PlaybackSettings = new PlaybackSettings();
  private static selectedId: string = '';
  private static fullscreen: boolean = false;
  private static scrolling: boolean = false;
  private static active: boolean = true;
  private static candidates: Map<string, VideoCandidate> = new Map();
  private static timer: number = -1;
  private static currentId: string = '';
  private static manualId: string = '';
  private static manualPausedId: string = '';
  private static fullscreenId: string = '';
  private static autoPlayed: Set<string> = new Set();

  static configure(settings: PlaybackSettings, selectedId: string, fullscreen: boolean): void {
    VideoAutoplay.settings = settings;
    VideoAutoplay.selectedId = selectedId;
    VideoAutoplay.fullscreen = fullscreen;
    if (fullscreen) VideoAutoplay.pauseCurrent();
    else if (!settings.autoPlay && VideoAutoplay.currentId != VideoAutoplay.manualId) VideoAutoplay.pauseCurrent();
    else VideoAutoplay.schedule();
  }

  static setSelected(selectedId: string): void {
    VideoAutoplay.selectedId = selectedId;
    VideoAutoplay.schedule();
  }

  static setFullscreen(fullscreen: boolean): void {
    VideoAutoplay.fullscreen = fullscreen;
    if (fullscreen) {
      VideoAutoplay.pauseCurrent();
      VideoAutoplay.manualId = '';
      VideoAutoplay.manualPausedId = '';
    } else {
      VideoAutoplay.schedule();
    }
  }

  static enterFullscreen(id: string): void {
    VideoAutoplay.fullscreenId = id;
    if (id.length > 0) VideoAutoplay.autoPlayed.add(id);
    VideoAutoplay.setFullscreen(true);
  }

  static exitFullscreen(): void {
    if (VideoAutoplay.fullscreenId.length > 0) {
      VideoAutoplay.autoPlayed.add(VideoAutoplay.fullscreenId);
    }
    VideoAutoplay.fullscreenId = '';
    VideoAutoplay.setFullscreen(false);
  }

  static onCompleted(id: string): void {
    VideoAutoplay.autoPlayed.add(id);
    if (VideoAutoplay.currentId == id) VideoAutoplay.currentId = '';
    if (VideoAutoplay.manualId == id) VideoAutoplay.manualId = '';
    VideoAutoplay.schedule();
  }

  static setActive(active: boolean): void {
    VideoAutoplay.active = active;
    if (!active) {
      VideoAutoplay.pauseCurrent();
      VideoAutoplay.cancelTimer();
    } else {
      VideoAutoplay.schedule();
    }
  }

  static onScrollStart(): void {
    VideoAutoplay.scrolling = true;
    VideoAutoplay.cancelTimer();
  }

  static onScrollStop(): void {
    VideoAutoplay.scrolling = false;
    VideoAutoplay.schedule();
  }

  static remove(id: string): void {
    const candidate = VideoAutoplay.candidates.get(id);
    if (candidate != undefined && candidate.playing()) candidate.pause();
    VideoAutoplay.candidates.delete(id);
    if (VideoAutoplay.currentId == id) VideoAutoplay.currentId = '';
    if (VideoAutoplay.manualId == id) VideoAutoplay.manualId = '';
  }

  static report(id: string, pane: string, index: number, ratio: number,
    autoStart: (muted: boolean, volume: number) => void,
    resume: () => void, pause: () => void, playing: () => boolean): void {
    let candidate = VideoAutoplay.candidates.get(id);
    if (candidate == undefined) {
      candidate = new VideoCandidate();
      VideoAutoplay.candidates.set(id, candidate);
    }
    candidate.id = id;
    candidate.pane = pane;
    candidate.index = index;
    candidate.ratio = ratio;
    candidate.autoStart = autoStart;
    candidate.resume = resume;
    candidate.pause = pause;
    candidate.playing = playing;

    if (ratio < 0.25) {
      // A manually started detail video keeps playing even when its widget is
      // scrolled out of view. This is intentional for the single-column page.
      if (candidate.pane == 'detail' && (VideoAutoplay.manualId == id || VideoAutoplay.currentId == id)) {
        return;
      }
      if (VideoAutoplay.currentId == id) {
        candidate.pause();
        VideoAutoplay.currentId = '';
      }
      if (VideoAutoplay.manualId == id) VideoAutoplay.manualId = '';
      if (VideoAutoplay.manualPausedId == id) VideoAutoplay.manualPausedId = '';
      VideoAutoplay.schedule();
      return;
    }
    if (ratio > 0.5 && pane == 'left' && !VideoAutoplay.fullscreen && !VideoAutoplay.scrolling) {
      VideoAutoplay.schedule();
    }
  }

  static hasCandidate(id: string): boolean {
    return VideoAutoplay.candidates.get(id) != undefined;
  }

  static manualPlay(id: string): void {
    const candidate = VideoAutoplay.candidates.get(id);
    if (candidate == undefined || candidate.ratio < 0.25) return;
    VideoAutoplay.pauseCurrentExcept(id);
    VideoAutoplay.manualPausedId = '';
    VideoAutoplay.autoPlayed.add(id);
    VideoAutoplay.manualId = id;
    VideoAutoplay.currentId = id;
    candidate.resume();
  }

  static manualPause(id: string): void {
    const candidate = VideoAutoplay.candidates.get(id);
    if (candidate == undefined) return;
    candidate.pause();
    VideoAutoplay.manualPausedId = id;
    if (VideoAutoplay.manualId == id) VideoAutoplay.manualId = '';
    if (VideoAutoplay.currentId == id) VideoAutoplay.currentId = '';
    VideoAutoplay.schedule();
  }

  private static pauseCurrentExcept(id: string): void {
    if (VideoAutoplay.currentId.length == 0 || VideoAutoplay.currentId == id) return;
    const current = VideoAutoplay.candidates.get(VideoAutoplay.currentId);
    if (current != undefined) current.pause();
  }

  private static pauseCurrent(): void {
    if (VideoAutoplay.currentId.length > 0) {
      const current = VideoAutoplay.candidates.get(VideoAutoplay.currentId);
      if (current != undefined && current.playing()) current.pause();
    }
    VideoAutoplay.currentId = '';
  }

  private static cancelTimer(): void {
    if (VideoAutoplay.timer >= 0) {
      clearTimeout(VideoAutoplay.timer);
      VideoAutoplay.timer = -1;
    }
  }

  private static schedule(): void {
    if (!VideoAutoplay.settings.autoPlay || VideoAutoplay.fullscreen || !VideoAutoplay.active) return;
    VideoAutoplay.cancelTimer();
    let any = false;
    VideoAutoplay.candidates.forEach((candidate: VideoCandidate) => {
      if (candidate.pane == 'left' && candidate.ratio > 0.5) any = true;
    });
    if (!any) return;
    VideoAutoplay.timer = setTimeout(() => {
      VideoAutoplay.timer = -1;
      VideoAutoplay.evaluate();
    }, 400);
  }

  private static evaluate(): void {
    if (!VideoAutoplay.settings.autoPlay || VideoAutoplay.fullscreen || !VideoAutoplay.active) return;
    // A manually started video keeps priority until it is less than 1/4 visible.
    if (VideoAutoplay.manualId.length > 0) {
      const manual = VideoAutoplay.candidates.get(VideoAutoplay.manualId);
      if (manual != undefined && manual.ratio >= 0.25) {
        if (VideoAutoplay.currentId != manual.id) {
          VideoAutoplay.pauseCurrent();
          VideoAutoplay.currentId = manual.id;
        }
        return;
      }
      VideoAutoplay.manualId = '';
    }
    // Keep the current video while it stays in the hysteresis band.
    if (VideoAutoplay.currentId.length > 0) {
      const current = VideoAutoplay.candidates.get(VideoAutoplay.currentId);
      if (current != undefined && current.ratio >= 0.25) return;
    }
    const list: VideoCandidate[] = [];
    VideoAutoplay.candidates.forEach((candidate: VideoCandidate) => {
      if (candidate.pane == 'left' && candidate.ratio > 0.5 &&
        candidate.id != VideoAutoplay.manualPausedId &&
        !VideoAutoplay.autoPlayed.has(candidate.id)) list.push(candidate);
    });
    if (list.length == 0) return;
    list.sort((a: VideoCandidate, b: VideoCandidate): number => {
      const ap = a.id == VideoAutoplay.selectedId ? 0 : 1;
      const bp = b.id == VideoAutoplay.selectedId ? 0 : 1;
      if (ap != bp) return ap - bp;
      if (a.ratio != b.ratio) return b.ratio - a.ratio;
      return a.index - b.index;
    });
    const chosen = list[0];
    if (chosen.id == VideoAutoplay.currentId) return;
    VideoAutoplay.pauseCurrent();
    VideoAutoplay.autoPlayed.add(chosen.id);
    VideoAutoplay.currentId = chosen.id;
    chosen.autoStart(VideoAutoplay.settings.autoPlayMuted, VideoAutoplay.settings.volumeRatio);
  }
}
