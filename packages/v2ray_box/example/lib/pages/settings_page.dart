import 'package:flutter/material.dart';
import 'package:v2ray_box/v2ray_box.dart';

class SettingsPage extends StatefulWidget {
  final V2rayBox v2rayBox;
  const SettingsPage({super.key, required this.v2rayBox});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  VpnMode _mode = VpnMode.vpn;
  PerAppProxyMode _perAppMode = PerAppProxyMode.off;
  bool _debugMode = false;
  String _pingTestUrl = 'https://www.gstatic.com/generate_204';
  Map<String, dynamic> _coreInfo = {};
  String _coreEngine = 'xray';
  bool _switchingEngine = false;
  List<AppInfo> _apps = [];
  List<AppInfo> _filteredApps = [];
  Set<String> _selectedApps = {};
  bool _loadingSettings = true;
  bool _loadingApps = true;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    _mode = await widget.v2rayBox.getServiceMode();
    _perAppMode = await widget.v2rayBox.getPerAppProxyMode();
    _debugMode = await widget.v2rayBox.getDebugMode();
    _pingTestUrl = await widget.v2rayBox.getPingTestUrl();
    try {
      _coreEngine = await widget.v2rayBox.getCoreEngine();
      _coreInfo = await widget.v2rayBox.getCoreInfo();
    } catch (_) {}

    if (_perAppMode != PerAppProxyMode.off) {
      final list = await widget.v2rayBox.getPerAppProxyList(_perAppMode);
      _selectedApps = list.toSet();
    }

    if (mounted) setState(() => _loadingSettings = false);
    _loadApps();
  }

  Future<void> _loadApps() async {
    try {
      final apps = await widget.v2rayBox.getInstalledApps();
      if (mounted)
        setState(() {
          _apps = apps;
          _filteredApps = apps;
          _loadingApps = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loadingApps = false);
    }
  }

  Future<void> _saveSelectedApps() async {
    if (_perAppMode != PerAppProxyMode.off) {
      await widget.v2rayBox.setPerAppProxyList(
        _selectedApps.toList(),
        _perAppMode,
      );
    }
  }

  void _filterApps(String q) {
    setState(() {
      _searchQuery = q;
      if (q.isEmpty) {
        _filteredApps = _apps;
      } else {
        final lq = q.toLowerCase();
        _filteredApps = _apps
            .where(
              (a) =>
                  a.name.toLowerCase().contains(lq) ||
                  a.packageName.toLowerCase().contains(lq),
            )
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingSettings) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Settings',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // Core Info
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(child: _buildCoreInfoCard()),
          ),

          // VPN Mode
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: _buildSection('Connection Mode', [
                _buildRadioTile(
                  'VPN',
                  'Route all traffic through VPN tunnel',
                  VpnMode.vpn,
                ),
                _buildRadioTile(
                  'Proxy',
                  'Use as local proxy only',
                  VpnMode.proxy,
                ),
              ]),
            ),
          ),

          // Advanced
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: _buildSection('Advanced', [
                SwitchListTile(
                  title: const Text('Debug Mode'),
                  subtitle: Text(
                    'Verbose logging for troubleshooting',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  value: _debugMode,
                  onChanged: (v) async {
                    await widget.v2rayBox.setDebugMode(v);
                    setState(() => _debugMode = v);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Ping Test URL'),
                  subtitle: Text(
                    _pingTestUrl,
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.edit, size: 18),
                  onTap: _showPingUrlDialog,
                ),
              ]),
            ),
          ),

          // Per-App Proxy
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: _buildSection('Per-App Proxy', [
                _buildPerAppTile(
                  'Off',
                  'All apps use VPN',
                  PerAppProxyMode.off,
                ),
                _buildPerAppTile(
                  'Exclude',
                  'Selected apps bypass VPN',
                  PerAppProxyMode.exclude,
                ),
              ]),
            ),
          ),

          if (_perAppMode != PerAppProxyMode.off) ...[
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Select Apps',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (!_loadingApps)
                          Text(
                            '${_filteredApps.length} apps',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchCtrl,
                      onChanged: _filterApps,
                      decoration: InputDecoration(
                        hintText: 'Search apps...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  _filterApps('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFF1A1A2E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            if (_loadingApps)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_filteredApps.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 48, color: Colors.grey[600]),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty
                            ? 'No apps found'
                            : 'No apps matching "$_searchQuery"',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _buildAppTile(_filteredApps[i]),
                    childCount: _filteredApps.length,
                  ),
                ),
              ),
          ],

          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }

  void _showPingUrlDialog() {
    final ctrl = TextEditingController(text: _pingTestUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ping Test URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                hintText: 'https://www.gstatic.com/generate_204',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('gstatic', style: TextStyle(fontSize: 12)),
                  onPressed: () =>
                      ctrl.text = 'https://www.gstatic.com/generate_204',
                ),
                ActionChip(
                  label: const Text(
                    'Cloudflare',
                    style: TextStyle(fontSize: 12),
                  ),
                  onPressed: () => ctrl.text = 'http://cp.cloudflare.com',
                ),
                ActionChip(
                  label: const Text('Google', style: TextStyle(fontSize: 12)),
                  onPressed: () =>
                      ctrl.text = 'http://www.google.com/generate_204',
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final url = ctrl.text.trim();
              if (url.isNotEmpty) {
                await widget.v2rayBox.setPingTestUrl(url);
                setState(() => _pingTestUrl = url);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _switchEngine(String engine) async {
    if (_switchingEngine || engine == _coreEngine) return;
    setState(() => _switchingEngine = true);

    try {
      await widget.v2rayBox.disconnect();
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (_) {}

    await widget.v2rayBox.setCoreEngine(engine);
    _coreEngine = engine;

    try {
      _coreInfo = await widget.v2rayBox.getCoreInfo();
    } catch (_) {}

    if (mounted) {
      setState(() => _switchingEngine = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Switched to ${engine == 'singbox' ? 'sing-box' : 'Xray-core'}',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF2D2D44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Widget _buildCoreInfoCard() {
    final isXray = _coreEngine == 'xray';
    final engineName = isXray ? 'Xray-core' : 'sing-box';
    final engineColor = isXray
        ? const Color(0xFF6C5CE7)
        : const Color(0xFFE84393);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: engineColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.memory, color: engineColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Core Engine',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        engineName,
                        style: TextStyle(color: Colors.grey[400], fontSize: 13),
                      ),
                      if (_coreInfo['version_source'] != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'source: ${_coreInfo['version_source']}',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_coreInfo['version'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2ED573).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'v${_coreInfo['version']}',
                      style: const TextStyle(
                        color: Color(0xFF2ED573),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildEngineButton(
                    'Xray-core',
                    'xray',
                    const Color(0xFF6C5CE7),
                    isXray,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildEngineButton(
                    'sing-box',
                    'singbox',
                    const Color(0xFFE84393),
                    !isXray,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngineButton(
    String label,
    String engine,
    Color color,
    bool selected,
  ) {
    return GestureDetector(
      onTap: _switchingEngine ? null : () => _switchEngine(engine),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : Colors.grey[700]!,
            width: selected ? 2 : 1,
          ),
        ),
        child: Center(
          child: _switchingEngine && engine == _coreEngine
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    color: selected ? color : Colors.grey[400],
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Card(child: Column(children: children)),
      ],
    );
  }

  Widget _buildRadioTile(String title, String subtitle, VpnMode value) {
    return RadioListTile<VpnMode>(
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey[400], fontSize: 12),
      ),
      value: value,
      groupValue: _mode,
      onChanged: (v) async {
        if (v != null) {
          await widget.v2rayBox.setServiceMode(v);
          setState(() => _mode = v);
        }
      },
    );
  }

  Widget _buildPerAppTile(
    String title,
    String subtitle,
    PerAppProxyMode value,
  ) {
    return RadioListTile<PerAppProxyMode>(
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey[400], fontSize: 12),
      ),
      value: value,
      groupValue: _perAppMode,
      onChanged: (v) async {
        if (v != null) {
          await widget.v2rayBox.setPerAppProxyMode(v);
          if (v != PerAppProxyMode.off) {
            final list = await widget.v2rayBox.getPerAppProxyList(v);
            setState(() {
              _perAppMode = v;
              _selectedApps = list.toSet();
            });
          } else {
            setState(() {
              _perAppMode = v;
              _selectedApps.clear();
            });
          }
        }
      },
    );
  }

  Widget _buildAppTile(AppInfo app) {
    final selected = _selectedApps.contains(app.packageName);
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: CheckboxListTile(
        title: Text(
          app.name,
          style: const TextStyle(fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          app.packageName,
          style: TextStyle(color: Colors.grey[500], fontSize: 11),
          overflow: TextOverflow.ellipsis,
        ),
        secondary: Icon(
          app.isSystemApp ? Icons.android : Icons.apps,
          color: app.isSystemApp ? Colors.grey[600] : Colors.blue[400],
          size: 20,
        ),
        value: selected,
        onChanged: (v) async {
          setState(() {
            if (v == true) {
              _selectedApps.add(app.packageName);
            } else {
              _selectedApps.remove(app.packageName);
            }
          });
          await _saveSelectedApps();
        },
        controlAffinity: ListTileControlAffinity.leading,
        dense: true,
      ),
    );
  }
}
