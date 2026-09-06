import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catchify/widgets/section_header.dart';
import 'package:catchify/widgets/no_artwork_cube.dart';
import 'package:catchify/widgets/custom_search_bar.dart';

void main() {
  testWidgets('SectionHeader renders title correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SectionHeader(title: 'Recommended For You'),
        ),
      ),
    );

    expect(find.text('Recommended For You'), findsOneWidget);
  });

  testWidgets('NullArtworkWidget renders placeholder title', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NullArtworkWidget(title: 'My Playlist'),
        ),
      ),
    );

    expect(find.text('My Playlist'), findsOneWidget);
  });

  testWidgets('CustomSearchBar renders and dismiss button clears input without duplicate spinner', (WidgetTester tester) async {
    final controller = TextEditingController(text: 'Anirudh');
    final focusNode = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomSearchBar(
            controller: controller,
            focusNode: focusNode,
            labelText: 'Search...',
            onSubmitted: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Anirudh'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // Tap dismiss button
    final clearButton = find.byType(IconButton);
    expect(clearButton, findsOneWidget);
    await tester.tap(clearButton);
    await tester.pump();

    expect(controller.text, isEmpty);
  });
}

