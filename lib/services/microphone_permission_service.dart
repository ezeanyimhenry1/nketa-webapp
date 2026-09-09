import 'package:permission_handler/permission_handler.dart';

class MicrophonePermissionOutcome {
  const MicrophonePermissionOutcome({
    required this.granted,
    this.message,
    this.openSettings = false,
  });

  final bool granted;
  final String? message;
  final bool openSettings;
}

class MicrophonePermissionService {
  static Future<MicrophonePermissionOutcome> ensureGranted() async {
    var status = await Permission.microphone.status;

    if (status.isGranted) {
      return const MicrophonePermissionOutcome(granted: true);
    }

    if (status.isDenied || status.isLimited || status.isProvisional) {
      status = await Permission.microphone.request();
      if (status.isGranted) {
        return const MicrophonePermissionOutcome(granted: true);
      }
    }

    if (status.isPermanentlyDenied) {
      return const MicrophonePermissionOutcome(
        granted: false,
        openSettings: true,
        message:
            'Microphone access is blocked. Open Settings to allow Nketa to use the microphone.',
      );
    }

    if (status.isRestricted) {
      return const MicrophonePermissionOutcome(
        granted: false,
        message: 'Microphone access is restricted on this device.',
      );
    }

    return const MicrophonePermissionOutcome(
      granted: false,
      message: 'Microphone permission is required to use voice features.',
    );
  }

  static Future<void> openSettings() => openAppSettings();
}
