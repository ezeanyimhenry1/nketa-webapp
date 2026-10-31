import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

class NetworkStatusProvider extends ChangeNotifier {
  bool _hasConnection = true;
  String? _bannerMessage;
  bool _wasDisconnected = false;
  bool get hasConnection => _hasConnection;
  String? get bannerMessage => _bannerMessage;

  NetworkStatusProvider() {
    _init();
  }

  void _init() {
    Connectivity().onConnectivityChanged.listen((result) async {
      await _handleResult(result);
    });
    Connectivity().checkConnectivity().then(_handleResult);
  }

  Future<void> _handleResult(ConnectivityResult result) async {
    if (result == ConnectivityResult.none) {
      _hasConnection = false;
      _wasDisconnected = true;
      _bannerMessage = 'No internet connection. Please check your network.';
      notifyListeners();
      return;
    }

    try {
      final stopwatch = Stopwatch()..start();
      final response = await http
          .get(Uri.parse('https://www.google.com/generate_204'))
          .timeout(const Duration(seconds: 5));
      stopwatch.stop();

      final ok = response.statusCode == 204 || response.statusCode == 200;
      if (!ok || stopwatch.elapsedMilliseconds > 2500) {
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

    if (_wasDisconnected) {
      _hasConnection = true;
      _wasDisconnected = false;
      await Future.delayed(const Duration(milliseconds: 100));
      _bannerMessage = null;
      notifyListeners();
    } else {
      _hasConnection = true;
      if (_bannerMessage != null) {
        _bannerMessage = null;
        notifyListeners();
      }
    }
  }

  void dismissBanner() {
    _bannerMessage = null;
    notifyListeners();
  }
}
