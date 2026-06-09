import 'package:flutter/material.dart';
import 'package:v2ray_box/v2ray_box.dart';

class ConnectionButton extends StatelessWidget {
  const ConnectionButton({
    super.key,
    required this.status,
    required this.onConnect,
    required this.onDisconnect,
    this.busy = false,
  });

  final VpnStatus status;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final bool busy;

  bool get _isConnected => status == VpnStatus.started;
  bool get _isTransition =>
      status == VpnStatus.starting || status == VpnStatus.stopping;

  @override
  Widget build(BuildContext context) {
    final disabled = busy || _isTransition;

    return FilledButton.icon(
      key: ValueKey(_isConnected ? 'disconnect_button' : 'connect_button'),
      onPressed: disabled
          ? null
          : _isConnected
              ? onDisconnect
              : onConnect,
      icon: Icon(_isConnected ? Icons.stop : Icons.vpn_key),
      label: Text(
        _isTransition
            ? 'Please wait...'
            : _isConnected
                ? 'Disconnect'
                : 'Connect',
      ),
    );
  }
}
