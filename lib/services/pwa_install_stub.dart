class PwaInstall {
  static bool get isWeb => false;
  static bool get isStandalone => false;
  static bool get isIosSafari => false;
  static bool get canPromptInstall => false;
  static bool get shouldShowBanner => false;

  static Future<bool> promptInstall() async => false;
}
