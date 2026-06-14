import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:team_project/main.dart';

void main() {
  testWidgets('favorites tab shows saved Pokemon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PokemonExplorerPage(
          pokemonFuture: Future.value([
            const PokemonCardData(
              id: 1,
              name: 'bulbasaur',
              imageUrl: '',
              fallbackImageUrl: '',
              accentColor: Color(0xFFE6F5DD),
            ),
          ]),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Bulbasaur'), findsOneWidget);
    expect(find.text('No favorites yet'), findsNothing);

    await tester.tap(find.byTooltip('Add favorite'));
    await tester.pump();
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is Tab && widget.text == 'Favorites',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bulbasaur'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsWidgets);
  });

  testWidgets('search filters Pokemon client-side', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PokemonExplorerPage(
          pokemonFuture: Future.value([
            const PokemonCardData(
              id: 1,
              name: 'bulbasaur',
              imageUrl: '',
              fallbackImageUrl: '',
              accentColor: Color(0xFFE6F5DD),
            ),
            const PokemonCardData(
              id: 4,
              name: 'charmander',
              imageUrl: '',
              fallbackImageUrl: '',
              accentColor: Color(0xFFFFEDD8),
            ),
          ]),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(PokemonCard), findsNWidgets(2));
    expect(find.byType(RefreshIndicator), findsWidgets);

    await tester.enterText(find.byType(TextField), 'char');
    await tester.pumpAndSettle();

    expect(find.text('Charmander'), findsOneWidget);
    expect(find.text('Bulbasaur'), findsNothing);
  });

  testWidgets('tapping a Pokemon card opens details page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PokemonExplorerPage(
          pokemonFuture: Future.value([
            const PokemonCardData(
              id: 7,
              name: 'squirtle',
              imageUrl: '',
              fallbackImageUrl: '',
              accentColor: Color(0xFFE2F0FF),
            ),
          ]),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byType(PokemonCard));
    await tester.pumpAndSettle();

    expect(find.byType(PokemonDetailsPage), findsOneWidget);
    expect(find.text('#007'), findsOneWidget);
    expect(find.text('Official artwork'), findsOneWidget);
    expect(find.text('Fallback sprite'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('More info'),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('More info'), findsOneWidget);
  });
}
