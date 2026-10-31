// Firebase options for the-igbo-bible project.
// Regenerate with `flutterfire configure` after adding new platform apps.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDt8sSeT6UgEFNHqVOYER-JGjX1ZQ3WWS0',
    appId: '1:994305615388:web:2349ae15de9a7e875a21d9',
    messagingSenderId: '994305615388',
    projectId: 'the-igbo-bible',
    authDomain: 'the-igbo-bible.firebaseapp.com',
    storageBucket: 'the-igbo-bible.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCGCLh9n-eiN9PMVSU7RGkOD9ODzQCjPeM',
    appId: '1:994305615388:android:386d0f88e8a65dc85a21d9',
    messagingSenderId: '994305615388',
    projectId: 'the-igbo-bible',
    storageBucket: 'the-igbo-bible.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCGCLh9n-eiN9PMVSU7RGkOD9ODzQCjPeM',
    appId: '1:994305615388:ios:70483fe91c4bbff85a21d9',
    messagingSenderId: '994305615388',
    projectId: 'the-igbo-bible',
    storageBucket: 'the-igbo-bible.firebasestorage.app',
    iosBundleId: 'com.henryezeanyim.theigbobible',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCGCLh9n-eiN9PMVSU7RGkOD9ODzQCjPeM',
    appId: '1:994305615388:ios:70483fe91c4bbff85a21d9',
    messagingSenderId: '994305615388',
    projectId: 'the-igbo-bible',
    storageBucket: 'the-igbo-bible.firebasestorage.app',
    iosBundleId: 'com.henryezeanyim.theigbobible',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCGCLh9n-eiN9PMVSU7RGkOD9ODzQCjPeM',
    appId: '1:994305615388:web:placeholder',
    messagingSenderId: '994305615388',
    projectId: 'the-igbo-bible',
    authDomain: 'the-igbo-bible.firebaseapp.com',
    storageBucket: 'the-igbo-bible.firebasestorage.app',
  );
}
