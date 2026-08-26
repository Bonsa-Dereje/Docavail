import 'package:flutter_test/flutter_test.dart';

import 'package:docavail/screens/queue.dart';

void main() {
  testWidgets('queue renders dummy patient cards', (WidgetTester tester) async {
    await tester.pumpWidget(const QueueScreen());

    expect(find.text('James Whitfield'), findsOneWidget);
    expect(find.text('Amara Osei'), findsOneWidget);
    expect(find.text('All Patients'), findsOneWidget);
  });
}
