export class FollowStatusStore {
  private static states: Record<string, boolean> = {};

  static set(states: Record<string, boolean>): void {
    if (states == null) return;
    for (const key of Object.keys(states)) {
      FollowStatusStore.states[key.toLowerCase()] = states[key];
    }
    AppStorage.setOrCreate('followStateTick', Date.now());
  }

  static get(handle: string): boolean | undefined {
    return FollowStatusStore.states[handle.toLowerCase()];
  }
}
