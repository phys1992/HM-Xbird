import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const STORE_NAME = 'x_session';
const KEY_DRAFT = 'compose_draft';

export class ComposeDraft {
  text: string = '';
  mediaUris: string[] = [];
  replyToId: string = '';
  quoteId: string = '';
}

export class DraftStore {
  private static store: preferences.Preferences | null = null;
  private static pending: ComposeDraft | null = null;

  private static getStore(context: common.UIAbilityContext): preferences.Preferences {
    if (DraftStore.store == null) {
      DraftStore.store = preferences.getPreferencesSync(context, { name: STORE_NAME });
    }
    return DraftStore.store;
  }

  static save(context: common.UIAbilityContext, draft: ComposeDraft): void {
    DraftStore.pending = draft;
  }

  static flush(context: common.UIAbilityContext): void {
    if (DraftStore.pending == null) return;
    const store = DraftStore.getStore(context);
    store.putSync(KEY_DRAFT, JSON.stringify(DraftStore.pending));
    store.flush();
  }

  static load(context: common.UIAbilityContext): ComposeDraft | null {
    if (DraftStore.pending != null) return DraftStore.pending;
    const raw = DraftStore.getStore(context).getSync(KEY_DRAFT, '') as string;
    if (raw.length == 0) return null;
    try {
      const obj = JSON.parse(raw) as ComposeDraft;
      const draft = new ComposeDraft();
      draft.text = typeof obj.text == 'string' ? obj.text : '';
      draft.mediaUris = Array.isArray(obj.mediaUris) ? (obj.mediaUris as string[]).slice(0, 4) : [];
      draft.replyToId = typeof obj.replyToId == 'string' ? obj.replyToId : '';
      draft.quoteId = typeof obj.quoteId == 'string' ? obj.quoteId : '';
      return draft;
    } catch (e) {
      return null;
    }
  }

  static clear(context: common.UIAbilityContext): void {
    DraftStore.pending = null;
    const store = DraftStore.getStore(context);
    store.deleteSync(KEY_DRAFT);
    store.flush();
  }
}
