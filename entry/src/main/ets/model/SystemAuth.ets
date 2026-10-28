import { userAuth } from '@kit.UserAuthenticationKit';
import { common } from '@kit.AbilityKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';

export class SystemAuth {
  static async authenticate(context: common.UIAbilityContext, title: string): Promise<boolean> {
    try {
      const rand = cryptoFramework.createRandom();
      const challenge = rand.generateRandomSync(16).data;
      const authParam: userAuth.AuthParam = {
        challenge: challenge,
        authType: [userAuth.UserAuthType.PIN, userAuth.UserAuthType.FACE, userAuth.UserAuthType.FINGERPRINT],
        authTrustLevel: userAuth.AuthTrustLevel.ATL2
      };
      const widget: userAuth.WidgetParam = { title: title };
      const instance = userAuth.getUserAuthInstance(authParam, widget);
      return await new Promise<boolean>((resolve) => {
        const callback: userAuth.IAuthCallback = {
          onResult: (result: userAuth.UserAuthResult) => {
            resolve(result.result == userAuth.UserAuthResultCode.SUCCESS);
          }
        };
        instance.on('result', callback);
        instance.start();
      });
    } catch (e) {
      console.error(`XHSystemAuth failed: ${e}`);
      return false;
    }
  }
}
