import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vpn_client/screens/home_screen.dart';

void main() {
  testWidgets('home screen shows disconnected state', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );

    expect(find.text('Disconnected'), findsOneWidget);
    expect(find.byKey(const ValueKey('connect_button')), findsOneWidget);
  });
}
