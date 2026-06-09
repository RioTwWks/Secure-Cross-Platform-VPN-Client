import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:v2ray_box/v2ray_box.dart';

import '../models/profile.dart';
import '../models/vpn_engine.dart';
import '../services/vpn_service.dart';

const _profilesKey = 'vpn_profiles';
const _engineKey = 'vpn_engine';

final vpnServiceProvider = Provider<VpnService>((ref) {
  final service = VpnService();
  ref.onDispose(() {
    service.disconnect();
  });
  return service;
});

final vpnStatusProvider = StreamProvider<VpnStatus>((ref) {
  final service = ref.watch(vpnServiceProvider);
  return service.v2rayBox.watchStatus();
});

final vpnStatsProvider = StreamProvider<VpnStats>((ref) {
  final service = ref.watch(vpnServiceProvider);
  return service.v2rayBox.watchStats();
});

final engineProvider =
    StateNotifierProvider<EngineNotifier, VpnEngine>((ref) {
  return EngineNotifier(ref.watch(vpnServiceProvider));
});

final profilesProvider =
    StateNotifierProvider<ProfilesNotifier, List<Profile>>((ref) {
  return ProfilesNotifier();
});

final selectedProfileProvider = StateProvider<Profile?>((ref) => null);

class EngineNotifier extends StateNotifier<VpnEngine> {
  EngineNotifier(this._vpnService) : super(VpnEngine.xray) {
    _load();
  }

  final VpnService _vpnService;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_engineKey);
    if (saved != null) {
      state = VpnEngine.fromCoreName(saved);
      await _vpnService.setEngine(state, disconnectIfNeeded: false);
    }
  }

  Future<void> setEngine(VpnEngine engine) async {
    await _vpnService.setEngine(engine);
    state = engine;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_engineKey, engine.coreName);
  }
}

class ProfilesNotifier extends StateNotifier<List<Profile>> {
  ProfilesNotifier() : super(const []) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profilesKey);
    if (raw == null) {
      return;
    }
    final list = (jsonDecode(raw) as List<dynamic>)
        .map((item) => Profile.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    state = list;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(state.map((profile) => profile.toJson()).toList());
    await prefs.setString(_profilesKey, encoded);
  }

  Future<void> addProfile({
    required String name,
    required String configLink,
    ProfileType type = ProfileType.link,
  }) async {
    final profile = Profile(
      id: const Uuid().v4(),
      name: name,
      configLink: configLink,
      type: type,
    );
    state = [...state, profile];
    await _persist();
  }

  Future<void> removeProfile(String id) async {
    state = state.where((profile) => profile.id != id).toList();
    await _persist();
  }
}
