import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const PokemonExplorerApp());
}

class PokemonExplorerApp extends StatelessWidget {
  const PokemonExplorerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pokemon Explorer',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D5B),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        textTheme: Theme.of(context).textTheme.apply(
          bodyColor: const Color(0xFF15211C),
          displayColor: const Color(0xFF15211C),
        ),
      ),
      home: const PokemonExplorerPage(),
    );
  }
}

class PokemonExplorerPage extends StatefulWidget {
  const PokemonExplorerPage({
    super.key,
    Future<List<PokemonCardData>>? pokemonFuture,
    Future<List<PokemonCardData>> Function()? pokemonLoader,
  }) : _pokemonFutureOverride = pokemonFuture,
       _pokemonLoader = pokemonLoader;

  final Future<List<PokemonCardData>>? _pokemonFutureOverride;
  final Future<List<PokemonCardData>> Function()? _pokemonLoader;

  @override
  State<PokemonExplorerPage> createState() => _PokemonExplorerPageState();
}

class _PokemonExplorerPageState extends State<PokemonExplorerPage> {
  late Future<List<PokemonCardData>> _pokemonFuture;
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _favoriteIds = <int>{};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _pokemonFuture = _loadPokemon();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<PokemonCardData>> _loadPokemon() {
    return widget._pokemonFutureOverride ??
        widget._pokemonLoader?.call() ??
        PokemonApi.fetchPokemon();
  }

  Future<void> _refreshPokemon() async {
    final future = _loadPokemon();
    setState(() {
      _pokemonFuture = future;
    });

    try {
      await future;
    } catch (_) {
      // The FutureBuilder renders the error state after refresh completes.
    }
  }

  void _updateSearch(String value) {
    setState(() {
      _searchQuery = value;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _updateSearch('');
  }

  void _toggleFavorite(PokemonCardData pokemon) {
    setState(() {
      if (_favoriteIds.contains(pokemon.id)) {
        _favoriteIds.remove(pokemon.id);
      } else {
        _favoriteIds.add(pokemon.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: FutureBuilder<List<PokemonCardData>>(
            future: _pokemonFuture,
            builder: (context, snapshot) {
              final pokemon = snapshot.data ?? <PokemonCardData>[];
              final favorites = pokemon
                  .where((item) => _favoriteIds.contains(item.id))
                  .toList(growable: false);
              final filteredPokemon = _filterPokemon(pokemon, _searchQuery);
              final filteredFavorites = _filterPokemon(favorites, _searchQuery);

              return NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverToBoxAdapter(
                      child: _Header(
                        totalCount: pokemon.length,
                        favoriteCount: favorites.length,
                        isLoading:
                            snapshot.connectionState ==
                                ConnectionState.waiting &&
                            pokemon.isEmpty,
                        searchController: _searchController,
                        searchQuery: _searchQuery,
                        onSearchChanged: _updateSearch,
                        onClearSearch: _clearSearch,
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _TabBarHeaderDelegate(
                        TabBar(
                          dividerHeight: 0,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                            color: const Color(0xFF15211C),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          labelColor: Colors.white,
                          unselectedLabelColor: const Color(0xFF62706A),
                          labelStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          tabs: const [
                            Tab(text: 'All Pokemon'),
                            Tab(text: 'Favorites'),
                          ],
                        ),
                      ),
                    ),
                  ];
                },
                body: _PokemonBody(
                  snapshot: snapshot,
                  pokemon: filteredPokemon,
                  favorites: filteredFavorites,
                  favoriteIds: _favoriteIds,
                  onToggleFavorite: _toggleFavorite,
                  onRefresh: _refreshPokemon,
                  hasSearchQuery: _searchQuery.trim().isNotEmpty,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<PokemonCardData> _filterPokemon(
    List<PokemonCardData> pokemon,
    String query,
  ) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return pokemon;
    }

    final numberQuery = normalizedQuery.replaceAll('#', '');
    return pokemon
        .where((item) {
          return item.name.toLowerCase().contains(normalizedQuery) ||
              item.displayName.toLowerCase().contains(normalizedQuery) ||
              item.id.toString().contains(numberQuery);
        })
        .toList(growable: false);
  }
}

class _PokemonBody extends StatelessWidget {
  const _PokemonBody({
    required this.snapshot,
    required this.pokemon,
    required this.favorites,
    required this.favoriteIds,
    required this.onToggleFavorite,
    required this.onRefresh,
    required this.hasSearchQuery,
  });

  final AsyncSnapshot<List<PokemonCardData>> snapshot;
  final List<PokemonCardData> pokemon;
  final List<PokemonCardData> favorites;
  final Set<int> favoriteIds;
  final ValueChanged<PokemonCardData> onToggleFavorite;
  final Future<void> Function() onRefresh;
  final bool hasSearchQuery;

  @override
  Widget build(BuildContext context) {
    if (snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData) {
      return const _LoadingState();
    }

    if (snapshot.hasError) {
      return _ErrorState(message: snapshot.error.toString());
    }

    return TabBarView(
      children: [
        _PokemonGrid(
          pokemon: pokemon,
          favoriteIds: favoriteIds,
          onToggleFavorite: onToggleFavorite,
          onRefresh: onRefresh,
          emptyState: _EmptyState(
            icon: Icons.travel_explore_rounded,
            title: hasSearchQuery ? 'No matches found' : 'No Pokemon found',
            subtitle: hasSearchQuery
                ? 'Try another Pokemon name or number.'
                : 'Try again once the public API is available.',
          ),
        ),
        _PokemonGrid(
          pokemon: favorites,
          favoriteIds: favoriteIds,
          onToggleFavorite: onToggleFavorite,
          onRefresh: onRefresh,
          emptyState: _EmptyState(
            icon: Icons.favorite_border_rounded,
            title: hasSearchQuery ? 'No favorite matches' : 'No favorites yet',
            subtitle: hasSearchQuery
                ? 'Clear search or try a different saved Pokemon.'
                : 'Tap the heart on any Pokemon to save it here.',
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.totalCount,
    required this.favoriteCount,
    required this.isLoading,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onClearSearch,
  });

  final int totalCount;
  final int favoriteCount;
  final bool isLoading;
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFDEF7E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.catching_pokemon_rounded,
                  color: Color(0xFF2E7D5B),
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pokemon Explorer',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Live data from the free PokeAPI',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF62706A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE3E8E5)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F15211C),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Loaded',
                    value: isLoading ? '--' : '$totalCount',
                    icon: Icons.public_rounded,
                  ),
                ),
                Container(width: 1, height: 42, color: const Color(0xFFE3E8E5)),
                Expanded(
                  child: _StatTile(
                    label: 'Favorites',
                    value: '$favoriteCount',
                    icon: favoriteCount == 0
                        ? Icons.favorite_border_rounded
                        : Icons.favorite_rounded,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SearchField(
            controller: searchController,
            query: searchQuery,
            onChanged: onSearchChanged,
            onClear: onClearSearch,
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: const Color(0xFF2E7D5B), size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: const Color(0xFF62706A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search Pokemon',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: query.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE3E8E5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2E7D5B), width: 1.5),
        ),
      ),
    );
  }
}

class _PokemonGrid extends StatelessWidget {
  const _PokemonGrid({
    required this.pokemon,
    required this.favoriteIds,
    required this.onToggleFavorite,
    required this.onRefresh,
    required this.emptyState,
  });

  final List<PokemonCardData> pokemon;
  final Set<int> favoriteIds;
  final ValueChanged<PokemonCardData> onToggleFavorite;
  final Future<void> Function() onRefresh;
  final Widget emptyState;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: const Color(0xFF2E7D5B),
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (pokemon.isEmpty) {
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverFillRemaining(hasScrollBody: false, child: emptyState),
              ],
            );
          }

          final crossAxisCount = constraints.maxWidth >= 900
              ? 4
              : constraints.maxWidth >= 620
              ? 3
              : 2;

          return GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.84,
            ),
            itemCount: pokemon.length,
            itemBuilder: (context, index) {
              final item = pokemon[index];
              return PokemonCard(
                pokemon: item,
                isFavorite: favoriteIds.contains(item.id),
                onFavoritePressed: () => onToggleFavorite(item),
              );
            },
          );
        },
      ),
    );
  }
}

class PokemonCard extends StatelessWidget {
  const PokemonCard({
    super.key,
    required this.pokemon,
    required this.isFavorite,
    required this.onFavoritePressed,
  });

  final PokemonCardData pokemon;
  final bool isFavorite;
  final VoidCallback onFavoritePressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE3E8E5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D15211C),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Positioned.fill(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: pokemon.accentColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _PokemonArtwork(imageUrl: pokemon.imageUrl),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#${pokemon.id.toString().padLeft(3, '0')}',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: const Color(0xFF2E7D5B),
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pokemon.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Tooltip(
                message: isFavorite ? 'Remove favorite' : 'Add favorite',
                child: IconButton.filledTonal(
                  onPressed: onFavoritePressed,
                  style: IconButton.styleFrom(
                    fixedSize: const Size.square(40),
                    backgroundColor: Colors.white,
                    foregroundColor: isFavorite
                        ? const Color(0xFFE03A5D)
                        : const Color(0xFF62706A),
                  ),
                  icon: Icon(
                    isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PokemonArtwork extends StatelessWidget {
  const _PokemonArtwork({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return const Center(
        child: Icon(
          Icons.catching_pokemon_rounded,
          color: Color(0xFF62706A),
          size: 42,
        ),
      );
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }

        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      },
      errorBuilder: (context, error, stackTrace) {
        return const Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: Color(0xFF62706A),
            size: 36,
          ),
        );
      },
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Fetching Pokemon...'),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: Color(0xFFE03A5D),
              size: 44,
            ),
            const SizedBox(height: 12),
            Text(
              'Could not load Pokemon',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF62706A)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF2E7D5B), size: 44),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF62706A)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  _TabBarHeaderDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => 64;

  @override
  double get maxExtent => 64;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: const Color(0xFFF5F7FA),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: Container(
          height: 48,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFE9EFEC),
            borderRadius: BorderRadius.circular(8),
          ),
          child: tabBar,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarHeaderDelegate oldDelegate) {
    return oldDelegate.tabBar != tabBar;
  }
}

class PokemonCardData {
  const PokemonCardData({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.accentColor,
  });

  final int id;
  final String name;
  final String imageUrl;
  final Color accentColor;

  String get displayName {
    return name
        .split('-')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }
}

class PokemonApi {
  static const String _endpoint = 'https://pokeapi.co/api/v2/pokemon?limit=24';

  static Future<List<PokemonCardData>> fetchPokemon() async {
    final byteData = await NetworkAssetBundle(Uri.parse(_endpoint)).load('');
    final decoded =
        jsonDecode(utf8.decode(byteData.buffer.asUint8List()))
            as Map<String, Object?>;
    final results = decoded['results'] as List<dynamic>;

    return results
        .map((item) {
          final data = item as Map<String, Object?>;
          final url = data['url'] as String;
          final id = _idFromUrl(url);

          return PokemonCardData(
            id: id,
            name: data['name'] as String,
            imageUrl:
                'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$id.png',
            accentColor: _accentFor(id),
          );
        })
        .toList(growable: false);
  }

  static int _idFromUrl(String url) {
    final segments = Uri.parse(url).pathSegments;
    return int.parse(segments[segments.length - 2]);
  }

  static Color _accentFor(int id) {
    const colors = [
      Color(0xFFE6F5DD),
      Color(0xFFFFEDD8),
      Color(0xFFE2F0FF),
      Color(0xFFFFE4EC),
      Color(0xFFEFE9FF),
      Color(0xFFFFF4C7),
    ];

    return colors[id % colors.length];
  }
}
