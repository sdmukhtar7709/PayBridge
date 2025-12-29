// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:currency_converter/main.dart';
import 'package:currency_converter/widgets/custom_textfield.dart';

void main() {
  testWidgets('renders login and navigates to registration',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Login'), findsOneWidget);
    expect(find.byType(CustomTextField), findsNWidgets(2));
    expect(find.text("Don't have an account? Register"), findsOneWidget);

    await tester.tap(find.text("Don't have an account? Register"));
    await tester.pumpAndSettle();

    expect(find.text('Register'), findsOneWidget);
    expect(find.byType(CustomTextField), findsNWidgets(4));
  });
}
