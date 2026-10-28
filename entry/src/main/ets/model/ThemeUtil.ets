import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { SessionStore } from './SessionStore';

export class ThemeUtil {
  static apply(context: common.UIAbilityContext, mode: string): boolean {
    let colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    if (mode == 'light') colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    if (mode == 'dark') colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    try {
      context.getApplicationContext().setColorMode(colorMode);
    } catch (e) {}
    return ThemeUtil.isDark(context, mode);
  }

  static isDark(context: common.UIAbilityContext, mode: string): boolean {
    if (mode == 'dark') return true;
    if (mode == 'light') return false;
    try {
      return (context.config.colorMode as number) == ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    } catch (e) {
      return false;
    }
  }
}
