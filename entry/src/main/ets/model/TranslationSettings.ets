import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { i18n } from '@kit.LocalizationKit';
import { I18n } from './I18n';

const STORE_NAME = 'translation_settings';
const SUPPORTED: string[] = ['ar', 'zh-cn', 'en', 'fr', 'ru', 'es'];

export class TranslationSettings {
  enabled: boolean = true;
  targetLang: string = '';
  exceptionLang: string = '';
}

export class TranslationSettingsStore {
  private static cached: TranslationSettings | null = null;

  private static store(context: common.UIAbilityContext): preferences.Preferences {
    return preferences.getPreferencesSync(context, { name: STORE_NAME });
  }

  private static normalize(code: string): string {
    if (SUPPORTED.indexOf(code) >= 0) return code;
    if (code == 'zh' || code == 'zh-hans' || code == 'zh-cn') return 'zh-cn';
    if (code == 'ja' || code == 'ko' || code == 'none' || code == 'system' || code.length == 0) return '';
    return '';
  }

  static systemTarget(): string {
    try {
      const lang = i18n.System.getSystemLanguage().toLowerCase();
      if (lang.startsWith('ar')) return 'ar';
      if (lang.startsWith('zh')) return 'zh-cn';
      if (lang.startsWith('fr')) return 'fr';
      if (lang.startsWith('ru')) return 'ru';
      if (lang.startsWith('es')) return 'es';
      if (lang.startsWith('en')) return 'en';
    } catch (e) {}
    return 'en';
  }

  static load(context: common.UIAbilityContext): TranslationSettings {
    if (TranslationSettingsStore.cached != null) return TranslationSettingsStore.cached!;
    const result = new TranslationSettings();
    try {
      const store = TranslationSettingsStore.store(context);
      const configured = store.getSync('configured', false);
      const enabled = store.getSync('enabled', true);
      const target = store.getSync('target', '');
      const exception = store.getSync('exception', '');
      result.enabled = typeof enabled == 'boolean' ? enabled as boolean : true;
      if (configured !== true) {
        result.targetLang = TranslationSettingsStore.systemTarget();
        result.exceptionLang = I18n.isEnglish() ? 'en' : 'zh-cn';
        store.putSync('configured', true);
        store.putSync('target', result.targetLang);
        store.putSync('exception', result.exceptionLang);
        store.flush();
      } else {
        const targetCode = TranslationSettingsStore.normalize(
          typeof target == 'string' ? target as string : '');
        result.targetLang = targetCode.length > 0 ? targetCode : TranslationSettingsStore.systemTarget();
        const exceptionCode = TranslationSettingsStore.normalize(
          typeof exception == 'string' ? exception as string : '');
        result.exceptionLang = exceptionCode.length > 0 ? exceptionCode :
          (I18n.isEnglish() ? 'en' : 'zh-cn');
      }
    } catch (e) {
      result.targetLang = TranslationSettingsStore.systemTarget();
      result.exceptionLang = I18n.isEnglish() ? 'en' : 'zh-cn';
    }
    TranslationSettingsStore.cached = result;
    return result;
  }

  static save(context: common.UIAbilityContext, settings: TranslationSettings): void {
    TranslationSettingsStore.cached = settings;
    try {
      const store = TranslationSettingsStore.store(context);
      store.putSync('configured', true);
      store.putSync('enabled', settings.enabled);
      store.putSync('target', settings.targetLang);
      store.putSync('exception', settings.exceptionLang);
      store.flush();
    } catch (e) {}
  }
}
