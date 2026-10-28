import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { EmojiGroupData, EMOJI_GROUPS } from './EmojiData';

const STORE = 'emoji_store_v2';
const KEY_RECENT = 'recent';

export class EmojiStore {
  private static getStore(context: common.UIAbilityContext): preferences.Preferences {
    return preferences.getPreferencesSync(context, { name: STORE });
  }

  static load(context: common.UIAbilityContext): EmojiGroupData[] {
    let recent: string[] = [];
    try {
      const store = EmojiStore.getStore(context);
      const raw = store.getSync(KEY_RECENT, '') as string;
      if (raw.length > 2) {
        const parsed = JSON.parse(raw) as string[];
        if (parsed.length > 0) recent = parsed;
      }
    } catch (e) {}
    const groups: EmojiGroupData[] = [];
    const recentGroup = new EmojiGroupData();
    recentGroup.name = '最近';
    recentGroup.icon = '🕘';
    recentGroup.emojis = recent;
    groups.push(recentGroup);
    for (const group of EMOJI_GROUPS) {
      groups.push(group);
    }
    return groups;
  }

  static addRecent(context: common.UIAbilityContext, emoji: string): void {
    try {
      const store = EmojiStore.getStore(context);
      const raw = store.getSync(KEY_RECENT, '') as string;
      let recent: string[] = [];
      if (raw.length > 2) recent = JSON.parse(raw) as string[];
      recent = recent.filter((e: string) => e != emoji);
      recent.unshift(emoji);
      if (recent.length > 24) recent = recent.slice(0, 24);
      store.putSync(KEY_RECENT, JSON.stringify(recent));
      store.flush();
    } catch (e) {}
  }
}
