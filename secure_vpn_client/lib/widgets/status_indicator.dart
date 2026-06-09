import 'package:flutter/material.dart';
import 'package:v2ray_box/v2ray_box.dart';

class StatusIndicator extends StatelessWidget {
  const StatusIndicator({
    super.key,
    required this.status,
  });

  final VpnStatus status;

  Color get _color {
    switch (status) {
      case VpnStatus.started:
        return Colors.green;
      case VpnStatus.starting:
      case VpnStatus.stopping:
        return Colors.orange;
      case VpnStatus.stopped:
        return Colors.red;
    }
  }

  String get _label {
    switch (status) {
      case VpnStatus.started:
        return 'Connected';
      case VpnStatus.starting:
        return 'Connecting';
      case VpnStatus.stopping:
        return 'Disconnecting';
      case VpnStatus.stopped:
        return 'Disconnected';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: _color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(_label),
      ],
    );
  }
}
