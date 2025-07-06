import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';

class NetworkStatusProvider extends ChangeNotifier {
  bool _hasConnection = true;
  String? _bannerMessage;
  bool get hasConnection => _hasConnection;
  String? get bannerMessage => _bannerMessage;

  NetworkStatusProvider() {
    _init();
  }

  void _init() {
    Connectivity().onConnectivityChanged.listen((result) async {
      if (result == ConnectivityResult.none) {
        _hasConnection = false;
        _bannerMessage = 'No internet connection. Please check your network.';
        notifyListeners();
      } else {
        // Try a simple speed check (ping google.com)
        try {
          final stopwatch = Stopwatch()..start();
          final lookup = await InternetAddress.lookup(
            'google.com',
          ).timeout(Duration(seconds: 5));
          stopwatch.stop();
          if (lookup.isEmpty || stopwatch.elapsedMilliseconds > 2500) {
            _hasConnection = false;
            _bannerMessage = 'Network is very slow. Please try again later.';
            notifyListeners();
            return;
          }
        } catch (_) {
          _hasConnection = false;
          _bannerMessage =
              'Unable to reach the internet. Please check your connection.';
          notifyListeners();
          return;
        }
        // Connection restored
        if (!_hasConnection || _bannerMessage != null) {
          _hasConnection = true;
          _bannerMessage = null;
          notifyListeners();
        }
      }
    });
  }

  void dismissBanner() {
    _bannerMessage = null;
    notifyListeners();
  }
}
