import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';

class NetworkStatusProvider extends ChangeNotifier {
  bool _hasConnection = true;
  String? _bannerMessage;
  bool _wasDisconnected = false; // Track if we were previously disconnected
  bool get hasConnection => _hasConnection;
  String? get bannerMessage => _bannerMessage;

  NetworkStatusProvider() {
    _init();
  }

  void _init() {
    Connectivity().onConnectivityChanged.listen((result) async {
      if (result == ConnectivityResult.none) {
        _hasConnection = false;
        _wasDisconnected = true;
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
            _wasDisconnected = true;
            _bannerMessage = 'Network is very slow. Please try again later.';
            notifyListeners();
            return;
          }
        } catch (_) {
          _hasConnection = false;
          _wasDisconnected = true;
          _bannerMessage =
              'Unable to reach the internet. Please check your connection.';
          notifyListeners();
          return;
        }

        // Connection restored - only show message if we were previously disconnected
        if (_wasDisconnected) {
          _hasConnection = true;
          _wasDisconnected = false;
          // Small delay to allow the UI to detect the transition
          await Future.delayed(const Duration(milliseconds: 100));
          _bannerMessage = null;
          notifyListeners();
        } else {
          // Just update the connection status without showing a message
          _hasConnection = true;
          if (_bannerMessage != null) {
            _bannerMessage = null;
            notifyListeners();
          }
        }
      }
    });
  }

  void dismissBanner() {
    _bannerMessage = null;
    notifyListeners();
  }
}
