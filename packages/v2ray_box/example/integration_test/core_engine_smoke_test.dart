import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:v2ray_box/v2ray_box.dart';

const bool _runLiveCoreSmoke = bool.fromEnvironment(
  'RUN_LIVE_CORE_SMOKE',
  defaultValue: false,
);

const String _ssConfig =
    'ss://Y2hhY2hhMjAtaWV0Zi1wb2x5MTMwNTpCSENqVFFkTXJjVzVYS2xPLXpOUnQyR3B1eFZfUTVBbg==@new2026panel.dpdns.org:1080#Shadow';

Future<void> _wait(Duration duration) async {
  await Future<void>.delayed(duration);
}

Future<bool> _waitForStatus(
  V2rayBox box,
  VpnStatus target, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final completer = Completer<bool>();
  late final StreamSubscription<VpnStatus> sub;
  sub = box.watchStatus().listen((status) {
    if (status == target && !completer.isCompleted) {
      completer.complete(true);
    }
  });

  try {
    return await completer.future.timeout(timeout, onTimeout: () => false);
  } finally {
    await sub.cancel();
  }
}

Future<int> _generateTraffic() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  final urls = <String>[
    'http://connectivitycheck.gstatic.com/generate_204',
    'http://cp.cloudflare.com/generate_204',
    'http://example.com',
  ];
  var okCount = 0;
  for (final url in urls) {
    try {
      final req = await client.getUrl(Uri.parse(url));
      final res = await req.close();
      await res.drain<void>();
      if (res.statusCode > 0) {
        okCount++;
      }
    } catch (_) {
      // ignore and continue probing
    }
  }
  client.close(force: true);
  return okCount;
}

Future<void> _assertEngineConnectsWithTraffic(
  V2rayBox box,
  String engine,
) async {
  await box.disconnect();
  await _wait(const Duration(seconds: 1));
  await box.setCoreEngine(engine);
  await box.setServiceMode(VpnMode.vpn);

  var maxStatsTotal = 0;
  final statsSub = box.watchStats().listen((stats) {
    final total = stats.uplinkTotal + stats.downlinkTotal;
    if (total > maxStatsTotal) {
      maxStatsTotal = total;
    }
  });

  try {
    final beforeTraffic = await box.getTotalTraffic();
    final started = await box.connect(_ssConfig, name: 'smoke-$engine');
    expect(started, true, reason: 'connect() returned false for $engine');

    final reachedStarted = await _waitForStatus(box, VpnStatus.started);
    expect(reachedStarted, true, reason: '$engine did not reach started state');

    final probeOkCount = await _generateTraffic();
    await _wait(const Duration(seconds: 4));

    final afterTraffic = await box.getTotalTraffic();
    final trafficIncreased = afterTraffic.total > beforeTraffic.total;
    final statsObserved = maxStatsTotal > 0;
    final probeWorked = probeOkCount > 0;

    expect(
      trafficIncreased || statsObserved || probeWorked,
      true,
      reason:
          '$engine started but no traffic evidence was observed (probeOk=$probeOkCount, statsTotal=$maxStatsTotal, before=${beforeTraffic.total}, after=${afterTraffic.total})',
    );
  } finally {
    await box.disconnect();
    await _waitForStatus(
      box,
      VpnStatus.stopped,
      timeout: const Duration(seconds: 20),
    );
    await statsSub.cancel();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'android smoke: xray and singbox connect with traffic',
    (WidgetTester tester) async {
      final box = V2rayBox();
      await box.initialize(notificationStopButtonText: 'Stop');
      await box.setDebugMode(true);

      var granted = await box.checkVpnPermission();
      if (!granted) {
        await box.requestVpnPermission();
        await _wait(const Duration(seconds: 3));
        granted = await box.checkVpnPermission();
      }
      expect(
        granted,
        true,
        reason:
            'VPN permission is not granted. Grant permission on device and re-run test.',
      );

      await _assertEngineConnectsWithTraffic(box, 'xray');
      await _assertEngineConnectsWithTraffic(box, 'singbox');
    },
    skip: !_runLiveCoreSmoke,
  );
}
