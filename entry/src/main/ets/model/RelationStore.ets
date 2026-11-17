import { XApi } from '../api/XApi';
import { UserProfile } from './UserProfile';

const REFRESH_MS = 5 * 60 * 1000;

export class RelationStore {
  static viewerId: string = '';
  private static following: UserProfile[] = [];
  private static followers: UserProfile[] = [];
  private static updatedAt: number = 0;
  private static refreshing: boolean = false;

  static setViewer(id: string): void {
    if (id.length == 0) return;
    if (RelationStore.viewerId != id) {
      RelationStore.viewerId = id;
      RelationStore.following = [];
      RelationStore.followers = [];
      RelationStore.updatedAt = 0;
    }
  }

  static get(kind: string): UserProfile[] {
    return kind == 'followers' ? RelationStore.followers.slice() : RelationStore.following.slice();
  }

  static markFollow(handle: string, following: boolean, profile: UserProfile | null): void {
    const key = handle.toLowerCase();
    RelationStore.following = RelationStore.following.filter((u: UserProfile) => u.handle.toLowerCase() != key);
    if (following && profile != null) {
      RelationStore.following.unshift(profile);
    }
    RelationStore.updatedAt = 0;
    AppStorage.setOrCreate('relationsRevision', Date.now());
  }

  static async refreshIfStale(cookie: string, viewerId: string, force: boolean = false): Promise<void> {
    if (cookie.length == 0 || viewerId.length == 0) return;
    RelationStore.setViewer(viewerId);
    if (!force && RelationStore.updatedAt > 0 &&
      Date.now() - RelationStore.updatedAt < REFRESH_MS) return;
    await RelationStore.refresh(cookie, viewerId);
  }

  static async refresh(cookie: string, viewerId: string): Promise<void> {
    if (RelationStore.refreshing) return;
    RelationStore.refreshing = true;
    try {
      const pages = await Promise.all([
        XApi.userList(cookie, viewerId, 'following'),
        XApi.userList(cookie, viewerId, 'followers')
      ]);
      RelationStore.following = pages[0].users;
      RelationStore.followers = pages[1].users;
      RelationStore.updatedAt = Date.now();
      AppStorage.setOrCreate('relationsRevision', Date.now());
    } catch (e) {
    } finally {
      RelationStore.refreshing = false;
    }
  }
}
