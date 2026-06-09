import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v2ray_box/v2ray_box.dart';

import '../models/vpn_engine.dart';
import '../providers/vpn_providers.dart';
import '../utils/config_parser.dart';

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

  Future<void> _copyToClipboard(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final engine = ref.watch(engineProvider);
    final status = ref.watch(vpnStatusProvider).value ?? VpnStatus.stopped;
    final desktopProxy = !kIsWeb &&
        (Platform.isLinux || Platform.isWindows || Platform.isMacOS);
    final sessionCredentials = ref.watch(sessionCredentialsProvider);
    final httpPort = ConfigParser.defaultSocksPort + 1;

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
        if (status == VpnStatus.started &&
            desktopProxy &&
            sessionCredentials != null) ...[
          const SizedBox(height: 16),
          Text(
            'System proxy (this session)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'If the browser asks for proxy login, use these values. '
            'They are not your VPN server account — only for local proxy '
            '127.0.0.1:$httpPort.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Proxy username'),
            subtitle: Text(sessionCredentials.username),
            trailing: IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy username',
              onPressed: () => _copyToClipboard(
                'Username',
                sessionCredentials.username,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.key_outlined),
            title: const Text('Proxy password'),
            subtitle: Text('${sessionCredentials.password.length} characters'),
            trailing: IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy password',
              onPressed: () => _copyToClipboard(
                'Password',
                sessionCredentials.password,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
