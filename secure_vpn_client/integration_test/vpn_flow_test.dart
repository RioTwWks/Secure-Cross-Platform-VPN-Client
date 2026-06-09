import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:secure_vpn_client/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('profile form and settings are reachable', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SecureVpnApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profiles'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile_name_field')), findsOneWidget);
    expect(find.byKey(const ValueKey('add_profile_button')), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('engine_selector')), findsOneWidget);
  });
}
