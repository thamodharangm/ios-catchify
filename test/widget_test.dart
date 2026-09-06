import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catchify/widgets/section_header.dart';
import 'package:catchify/widgets/no_artwork_cube.dart';

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
}

