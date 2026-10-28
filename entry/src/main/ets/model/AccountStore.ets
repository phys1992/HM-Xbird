import { asset } from '@kit.AssetStoreKit';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';

const STORE = 'saved_accounts';
const KEY = 'accounts';

export class SavedAccount {
  id: string = '';
  handle: string = '';
  name: string = '';
  avatarUrl: string = '';
}

export class AccountStore {
  private static meta(context: common.UIAbilityContext): preferences.Preferences {
    return preferences.getPreferencesSync(context, { name: STORE });
  }

  static load(context: common.UIAbilityContext): SavedAccount[] {
    try {
      const raw = AccountStore.meta(context).getSync(KEY, '') as string;
      if (raw.length > 2) {
        const parsed = JSON.parse(raw) as SavedAccount[];
        if (Array.isArray(parsed)) return parsed;
      }
    } catch (e) {}
    return [];
  }

  private static async putSecret(alias: string, cookie: string): Promise<void> {
    const encoder = new util.TextEncoder();
    const attrs: asset.AssetMap = new Map();
    attrs.set(asset.Tag.ALIAS, encoder.encodeInto(alias));
    attrs.set(asset.Tag.SECRET, encoder.encodeInto(cookie));
    attrs.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED);
    try {
      await asset.add(attrs);
    } catch (e) {
      const query: asset.AssetMap = new Map();
      query.set(asset.Tag.ALIAS, encoder.encodeInto(alias));
      try { await asset.remove(query); } catch (e2) {}
      await asset.add(attrs);
    }
  }

  static async save(context: common.UIAbilityContext, account: SavedAccount, cookie: string): Promise<boolean> {
    try {
      await AccountStore.putSecret(`x_account_${account.id}`, cookie);
      const list = AccountStore.load(context).filter((a: SavedAccount) => a.id != account.id);
      list.unshift(account);
      const kept = list.slice(0, 5);
      AccountStore.meta(context).putSync(KEY, JSON.stringify(kept));
      AccountStore.meta(context).flush();
      for (const old of list.slice(5)) {
        await AccountStore.remove(context, old);
      }
      return true;
    } catch (e) {
      console.error(`XHAccount save failed: ${e}`);
      return false;
    }
  }

  static async cookie(account: SavedAccount): Promise<string> {
    const encoder = new util.TextEncoder();
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, encoder.encodeInto(`x_account_${account.id}`));
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
    const results = await asset.query(query);
    console.info(`XHAccount query ${account.handle} count=${results.length}`);
    if (results.length == 0) return '';
    const secret = results[0].get(asset.Tag.SECRET);
    if (secret == undefined) return '';
    return new util.TextDecoder().decodeToString(secret as Uint8Array);
  }

  static async remove(context: common.UIAbilityContext, account: SavedAccount): Promise<void> {
    try {
      const query: asset.AssetMap = new Map();
      query.set(asset.Tag.ALIAS, new util.TextEncoder().encodeInto(`x_account_${account.id}`));
      await asset.remove(query);
    } catch (e) {}
    const list = AccountStore.load(context).filter((a: SavedAccount) => a.id != account.id);
    AccountStore.meta(context).putSync(KEY, JSON.stringify(list));
    AccountStore.meta(context).flush();
  }
}
