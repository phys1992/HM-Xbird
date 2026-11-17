import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { i18n } from '@kit.LocalizationKit';
import { I18n } from './I18n';

const STORE_NAME = 'x_session';
const KEY_LANGUAGE = 'language_mode';

export class LanguageSettingsStore {
  private static store: preferences.Preferences | null = null;

  private static getStore(context: common.UIAbilityContext): preferences.Preferences {
    if (LanguageSettingsStore.store == null) {
      LanguageSettingsStore.store = preferences.getPreferencesSync(context, { name: STORE_NAME });
    }
    return LanguageSettingsStore.store;
  }

  static load(context: common.UIAbilityContext): string {
    const value = LanguageSettingsStore.getStore(context).getSync(KEY_LANGUAGE, 'system');
    if (value == 'zh' || value == 'en' || value == 'system') return value as string;
    return 'system';
  }

  static save(context: common.UIAbilityContext, mode: string): void {
    const store = LanguageSettingsStore.getStore(context);
    store.putSync(KEY_LANGUAGE, mode);
    store.flush();
  }

  static resolve(mode: string): string {
    if (mode == 'zh') return 'zh';
    if (mode == 'en') return 'en';
    try {
      const language = i18n.System.getSystemLanguage().toLowerCase();
      return language.startsWith('zh') ? 'zh' : 'en';
    } catch (e) {
      return 'en';
    }
  }

  static apply(mode: string): void {
    const locale = mode == 'zh' ? 'zh-Hans' : (mode == 'en' ? 'en-US' : 'default');
    try {
      i18n.System.setAppPreferredLanguage(locale);
    } catch (e) {}
    I18n.setLanguage(LanguageSettingsStore.resolve(mode));
  }
}
