import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v2ray_box/v2ray_box.dart';

import '../models/vpn_engine.dart';
import '../providers/vpn_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _coreVersion = '';

  @override
  void initState() {
    super.initState();
    _loadCoreInfo();
  }

  Future<void> _loadCoreInfo() async {
    final info = await ref.read(vpnServiceProvider).v2rayBox.getCoreInfo();
    if (!mounted) {
      return;
    }
    setState(() {
      _coreVersion = '${info['engine'] ?? 'unknown'} ${info['version'] ?? ''}'
          .trim();
    });
  }

  Future<void> _onEngineChanged(VpnEngine? engine) async {
    if (engine == null) {
      return;
    }
    await ref.read(engineProvider.notifier).setEngine(engine);
    await _loadCoreInfo();
  }

  @override
  Widget build(BuildContext context) {
    final engine = ref.watch(engineProvider);
    final status = ref.watch(vpnStatusProvider).value ?? VpnStatus.stopped;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Core engine',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        SegmentedButton<VpnEngine>(
          key: const ValueKey('engine_selector'),
          segments: const [
            ButtonSegment(
              value: VpnEngine.xray,
              label: Text('Xray'),
            ),
            ButtonSegment(
              value: VpnEngine.singbox,
              label: Text('sing-box'),
            ),
          ],
          selected: {engine},
          onSelectionChanged: status == VpnStatus.started
              ? null
              : (selection) => _onEngineChanged(selection.first),
        ),
        if (status == VpnStatus.started) ...[
          const SizedBox(height: 8),
          const Text('Disconnect VPN before switching engine'),
        ],
        const SizedBox(height: 16),
        Text('Core info: $_coreVersion'),
        const SizedBox(height: 16),
        Text(
          'Security',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const ListTile(
          leading: Icon(Icons.lock_outline),
          title: Text('Dynamic SOCKS5 credentials'),
          subtitle: Text('New username/password every session'),
        ),
        const ListTile(
          leading: Icon(Icons.home_outlined),
          title: Text('Local bind'),
          subtitle: Text('127.0.0.1 only, password required'),
        ),
      ],
    );
  }
}
