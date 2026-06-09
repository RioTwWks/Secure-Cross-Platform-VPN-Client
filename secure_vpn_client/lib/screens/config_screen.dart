import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v2ray_box/v2ray_box.dart';

import '../models/profile.dart';
import '../providers/vpn_providers.dart';

class ConfigScreen extends ConsumerStatefulWidget {
  const ConfigScreen({super.key});

  @override
  ConsumerState<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends ConsumerState<ConfigScreen> {
  final _nameController = TextEditingController();
  final _linkController = TextEditingController();
  ProfileType _type = ProfileType.link;

  @override
  void dispose() {
    _nameController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _addProfile() async {
    final name = _nameController.text.trim();
    final link = _linkController.text.trim();
    if (name.isEmpty || link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and config link are required')),
      );
      return;
    }

    if (_type == ProfileType.link && !V2rayBox().isValidConfigLink(link)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid VPN config link')),
      );
      return;
    }

    await ref.read(profilesProvider.notifier).addProfile(
          name: name,
          configLink: link,
          type: _type,
        );

    _nameController.clear();
    _linkController.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile added')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(profilesProvider);
    final selectedProfile = ref.watch(selectedProfileProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          key: const ValueKey('profile_name_field'),
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Profile name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('profile_link_field'),
          controller: _linkController,
          decoration: InputDecoration(
            labelText: _type == ProfileType.link
                ? 'Config link (vless://, vmess://, ...)'
                : 'Subscription URL',
            border: const OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        SegmentedButton<ProfileType>(
          segments: const [
            ButtonSegment(
              value: ProfileType.link,
              label: Text('Link'),
            ),
            ButtonSegment(
              value: ProfileType.subscription,
              label: Text('Subscription'),
            ),
          ],
          selected: {_type},
          onSelectionChanged: (selection) {
            setState(() => _type = selection.first);
          },
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const ValueKey('add_profile_button'),
          onPressed: _addProfile,
          child: const Text('Add profile'),
        ),
        const SizedBox(height: 24),
        Text(
          'Profiles',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (profiles.isEmpty)
          const Text('No profiles yet')
        else
          ...profiles.map(
            (profile) => Card(
              child: ListTile(
                title: Text(profile.name),
                subtitle: Text(
                  profile.type == ProfileType.link
                      ? 'Direct link'
                      : 'Subscription',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      selectedProfile?.id == profile.id
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        ref
                            .read(profilesProvider.notifier)
                            .removeProfile(profile.id);
                        if (selectedProfile?.id == profile.id) {
                          ref.read(selectedProfileProvider.notifier).state =
                              null;
                        }
                      },
                    ),
                  ],
                ),
                onTap: () {
                  ref.read(selectedProfileProvider.notifier).state = profile;
                },
              ),
            ),
          ),
      ],
    );
  }
}
