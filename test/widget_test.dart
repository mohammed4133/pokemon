import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:team_project/main.dart';

Widget _buildPokemonTestApp(List<PokemonCardData> pokemon) {
  return ChangeNotifierProvider(
    create: (_) => PokemonExplorerState(),
    child: MaterialApp(
      home: PokemonExplorerPage(pokemonFuture: Future.value(pokemon)),
    ),
  );
}

Future<void> _pumpPastAnimations(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('favorites tab shows saved Pokemon', (tester) async {
    await tester.pumpWidget(
      _buildPokemonTestApp([
        const PokemonCardData(
          id: 1,
          name: 'bulbasaur',
          imageUrl: '',
          fallbackImageUrl: '',
          accentColor: Color(0xFFE6F5DD),
        ),
      ]),
    );

    await _pumpPastAnimations(tester);

    expect(find.text('Bulbasaur'), findsOneWidget);
    expect(find.text('No favorites yet'), findsNothing);

    await tester.tap(find.byTooltip('Add favorite'));
    await tester.pump();
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is Tab && widget.text == 'Favorites',
      ),
    );
    await _pumpPastAnimations(tester);

    expect(find.text('Bulbasaur'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsWidgets);
  });

  testWidgets('search filters Pokemon client-side', (tester) async {
    await tester.pumpWidget(
      _buildPokemonTestApp([
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
    );

    await _pumpPastAnimations(tester);

    expect(find.byType(PokemonCard), findsNWidgets(2));
    expect(find.byType(RefreshIndicator), findsWidgets);

    await tester.enterText(find.byType(TextField), 'char');
    await _pumpPastAnimations(tester);

    expect(find.text('Charmander'), findsOneWidget);
    expect(find.text('Bulbasaur'), findsNothing);
  });

  testWidgets('tapping a Pokemon card opens details page', (tester) async {
    await tester.pumpWidget(
      _buildPokemonTestApp([
        const PokemonCardData(
          id: 7,
          name: 'squirtle',
          imageUrl: '',
          fallbackImageUrl: '',
          accentColor: Color(0xFFE2F0FF),
        ),
      ]),
    );

    await _pumpPastAnimations(tester);
    await tester.tap(find.byType(PokemonCard));
    await _pumpPastAnimations(tester);

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
