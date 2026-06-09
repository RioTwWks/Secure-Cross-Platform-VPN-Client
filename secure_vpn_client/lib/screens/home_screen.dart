import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v2ray_box/v2ray_box.dart';

import '../providers/vpn_providers.dart';
import '../widgets/connection_button.dart';
import '../widgets/status_indicator.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _connect() async {
    final profile = ref.read(selectedProfileProvider);
    if (profile == null) {
      setState(() => _error = 'Select or add a profile first');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(vpnServiceProvider).connect(profile);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _disconnect() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(vpnServiceProvider).disconnect();
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(vpnStatusProvider).value ?? VpnStatus.stopped;
    final stats = ref.watch(vpnStatsProvider).value;
    final engine = ref.watch(engineProvider);
    final selectedProfile = ref.watch(selectedProfileProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusIndicator(status: status),
                  const SizedBox(height: 12),
                  Text('Engine: ${engine.coreName}'),
                  const SizedBox(height: 8),
                  Text(
                    selectedProfile == null
                        ? 'No profile selected'
                        : 'Profile: ${selectedProfile.name}',
                  ),
                  if (stats != null) ...[
                    const SizedBox(height: 8),
                    Text('Upload: ${stats.formattedUplinkTotal}'),
                    Text('Download: ${stats.formattedDownlinkTotal}'),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ConnectionButton(
            status: status,
            busy: _busy,
            onConnect: _connect,
            onDisconnect: _disconnect,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
