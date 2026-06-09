import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/main.dart';

void main() {
  testWidgets('app shell renders navigation', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SecureVpnApp(),
      ),
    );

    expect(find.text('Secure VPN Client'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Profiles'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.byKey(const ValueKey('connect_button')), findsOneWidget);
  });
}
