import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'ElevatedButton with small fixedSize and large padding throws error',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.person),
                label: const Text('Edit Profile'),
                style: ElevatedButton.styleFrom(
                  fixedSize: const Size(
                    50,
                    50,
                  ), // Very small size, smaller than padding
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
