import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:the_igbo_bible/services/network_status_provider.dart';

class GlobalNetworkBanner extends StatefulWidget {
  final Widget child;
  const GlobalNetworkBanner({required this.child, super.key});

  @override
  State<GlobalNetworkBanner> createState() => _GlobalNetworkBannerState();
}

class _GlobalNetworkBannerState extends State<GlobalNetworkBanner> {
  bool _showRestored = false;
  String? _lastBannerMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final networkStatus = Provider.of<NetworkStatusProvider>(context);
    if (_lastBannerMessage != null &&
        _lastBannerMessage!.isNotEmpty &&
        networkStatus.bannerMessage == null) {
      // Connection restored
      setState(() => _showRestored = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showRestored = false);
      });
    }
    _lastBannerMessage = networkStatus.bannerMessage;
  }

  @override
  Widget build(BuildContext context) {
    final networkStatus = Provider.of<NetworkStatusProvider>(context);
    final showWarning = networkStatus.bannerMessage != null;
    final overlayText =
        _showRestored ? 'Connection Restored' : networkStatus.bannerMessage;
    final overlayColor = _showRestored ? Colors.green[400] : Colors.amber[700];
    final icon =
        _showRestored ? Icons.check_circle : Icons.warning_amber_rounded;
    return Stack(
      children: [
        widget.child,
        if (showWarning || _showRestored)
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: AnimatedOpacity(
              opacity: (showWarning || _showRestored) ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(12),
                color: overlayColor,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(icon, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          overlayText ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (!(_showRestored))
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => networkStatus.dismissBanner(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
