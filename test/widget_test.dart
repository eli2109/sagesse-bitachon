import 'package:flutter_test/flutter_test.dart';
import 'package:sagesse_bitachon/main.dart';

void main() {
  testWidgets('App loads with title', (WidgetTester tester) async {
    await tester.pumpWidget(const SagesseBitachonApp());
    await tester.pump();

    expect(find.text('Sagesse du Bitachon'), findsOneWidget);
  });
}