import 'dart:js' as js;
import 'dart:js_util' as js_util;

class PwaInstall {
  static bool get isWeb => true;

  static bool get isStandalone {
    try {
      return js.context.callMethod('nketaIsStandalone') == true;
    } catch (_) {
      return false;
    }
  }

  static bool get isIosSafari {
    try {
      return js.context.callMethod('nketaIsIos') == true;
    } catch (_) {
      return false;
    }
  }

  static bool get canPromptInstall {
    try {
      return js.context.callMethod('nketaCanInstall') == true;
    } catch (_) {
      return false;
    }
  }

  static bool get shouldShowBanner =>
      !isStandalone && (canPromptInstall || isIosSafari);

  static Future<bool> promptInstall() async {
    try {
      final result = js.context.callMethod('nketaInstall');
      if (result == null) return false;
      final resolved = await js_util.promiseToFuture(result);
      return resolved == true;
    } catch (_) {
      return false;
    }
  }
}
