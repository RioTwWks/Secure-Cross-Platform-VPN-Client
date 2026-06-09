import 'package:flutter_test/flutter_test.dart';
import 'package:v2ray_box_example/main.dart';

void main() {
  testWidgets('App bootstraps without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const V2RayBoxApp());
    expect(find.byType(V2RayBoxApp), findsOneWidget);
  });
}
