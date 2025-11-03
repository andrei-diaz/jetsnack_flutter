import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'theme/jetsnack_theme.dart';
import 'widgets/jetsnack_bottom_bar.dart';

void main() {
  // Avoid network fetch for fonts in offline/dev environments
  runApp(const ProviderScope(child: JetsnackApp()));
}

class JetsnackApp extends StatelessWidget {
  const JetsnackApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = _router;
    final baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: JetsnackColors.light.primary, brightness: Brightness.light),
      scaffoldBackgroundColor: JetsnackColors.light.background,
      appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      useMaterial3: true,
    );
    return MaterialApp.router(
      title: 'Jetsnack',
      theme: baseTheme,
      routerConfig: router,
      builder: (context, child) => JetsnackTheme(colors: JetsnackColors.light, child: child!),
    );
  }
}

// Models
class SnackItem {
  final int id;
  final String name;
  final String image; // asset path
  final int price;
  final String tagline;
  SnackItem({required this.id, required this.name, required this.image, required this.price, required this.tagline});
  factory SnackItem.fromJson(Map<String, dynamic> j) => SnackItem(
        id: j['id'] as int,
        name: j['name'] as String,
        image: j['image'] as String,
        price: j['price'] as int,
        tagline: (j['tagline'] ?? '') as String,
      );
}

// Repository (assets-based)
final snacksRepoProvider = Provider<SnacksRepository>((ref) => SnacksRepository());

class SnacksRepository {
  List<SnackItem>? _cache;
  Future<List<SnackItem>> getSnacks() async {
    if (_cache != null) return _cache!;
    try {
      final raw = await rootBundle.loadString('assets/mock/snacks.json');
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>().map(SnackItem.fromJson).toList();
      _cache = list;
      return list;
    } catch (e) {
      debugPrint('getSnacks error: $e');
      return const <SnackItem>[];
    }
  }

  Future<SnackItem?> getSnack(int id) async {
    final all = await getSnacks();
    return all.firstWhere((e) => e.id == id, orElse: () => all.first);
  }
}

// Cart state
class CartState {
  final Map<int, int> quantities; // snackId -> count
  const CartState(this.quantities);
  int get totalItems => quantities.values.fold(0, (a, b) => a + b);
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState({}));
  void add(int id) => state = CartState({...state.quantities, id: (state.quantities[id] ?? 0) + 1});
  void remove(int id) {
    final q = (state.quantities[id] ?? 0) - 1;
    final next = Map<int, int>.from(state.quantities);
    if (q <= 0) {
      next.remove(id);
    } else {
      next[id] = q;
    }
    state = CartState(next);
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) => CartNotifier());

// Router
final _shellKey = GlobalKey<NavigatorState>(debugLabel: 'shell');
final _router = GoRouter(
  routes: [
    ShellRoute(
      navigatorKey: _shellKey,
      builder: (context, state, child) => HomeScaffold(child: child),
      routes: [
        GoRoute(path: '/home/feed', builder: (c, s) => const FeedScreen(),),
        GoRoute(path: '/home/search', builder: (c, s) => const SearchScreen(),),
        GoRoute(path: '/home/cart', builder: (c, s) => const CartScreen(),),
        GoRoute(path: '/home/profile', builder: (c, s) => const ProfileScreen(),),
      ],
    ),
    GoRoute(path: '/snack/:id', builder: (c, s) => SnackDetailScreen(id: int.parse(s.pathParameters['id']!))),
    // Redirect root
    GoRoute(path: '/', redirect: (c, s) => '/home/feed'),
  ],
);

class HomeScaffold extends StatefulWidget {
  final Widget child;
  const HomeScaffold({super.key, required this.child});

  @override
  State<HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends State<HomeScaffold> {
  int _indexFromLocation(String l) {
    if (l.startsWith('/home/search')) return 1;
    if (l.startsWith('/home/cart')) return 2;
    if (l.startsWith('/home/profile')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final current = _indexFromLocation(location);
    return Scaffold(
      appBar: AppBar(title: const Text('Jetsnack')),
      body: widget.child,
      bottomNavigationBar: JetsnackBottomBar(
        currentIndex: current,
        onTap: (i) {
          switch (i) {
            case 0:
              context.go('/home/feed');
              break;
            case 1:
              context.go('/home/search');
              break;
            case 2:
              context.go('/home/cart');
              break;
            case 3:
              context.go('/home/profile');
              break;
          }
        },
      ),
    );
  }
}

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});
  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final Set<String> _filters = {"Organic", "Gluten-free", "Dairy-free"};
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(snacksRepoProvider);
    return FutureBuilder(
      future: Future.wait([
        repo.getSnacks(),
        _loadCollections(),
      ]),
      builder: (context, snap) {
        if (snap.hasError) {
          debugPrint('Feed load error: \'${snap.error}\'');
          return Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Ocurrió un error cargando los datos. Reinicia o vuelve más tarde.')
          ));
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final snacks = snap.data![0] as List<SnackItem>;
        final collections = snap.data![1] as List<_Collection>;
        return ListView(
          padding: const EdgeInsets.only(bottom: 80),
          children: [
            _FeedHeader(filters: _filters, selected: _selected, onToggle: (f){
              setState((){ _selected.contains(f) ? _selected.remove(f) : _selected.add(f); });
            }),
            const SizedBox(height: 8),
            ...collections.map((c){
              final items = c.snackIds.map((id) => snacks.firstWhere((s) => s.id == id, orElse: () => snacks.first)).toList();
              return c.type == 'highlight'
                ? _SectionHighlight(title: c.name, items: items)
                : _SectionCircle(title: c.name, items: items);
            })
          ],
        );
      },
    );
  }
}

class _FeedHeader extends StatelessWidget {
  final Set<String> filters;
  final Set<String> selected;
  final void Function(String) onToggle;
  const _FeedHeader({required this.filters, required this.selected, required this.onToggle});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children:[
          const Icon(Icons.room_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text('Delivery to 1600 Amphitheater Way', style: Theme.of(context).textTheme.titleMedium)),
          const Icon(Icons.expand_more),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i){
              final f = filters.elementAt(i);
              final sel = selected.contains(f);
              return _FilterPill(label: f, selected: sel, onTap: ()=>onToggle(f));
            },
          ),
        )
      ]),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label; final bool selected; final VoidCallback onTap;
  const _FilterPill({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final colors = JetsnackTheme.of(context);
    final border = selected ? colors.primary : Colors.black12;
    final bg = selected ? colors.primary.withValues(alpha: 0.12) : Colors.white;
    final fg = selected ? colors.primary : Colors.black87;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border, width: 2),
          boxShadow: selected ? [BoxShadow(color: colors.primary.withValues(alpha: 0.25), blurRadius: 8, spreadRadius: 1)] : [const BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0,2))],
        ),
        child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _SectionHighlight extends ConsumerWidget {
  final String title;
  final List<SnackItem> items;
  const _SectionHighlight({required this.title, required this.items});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(title, style: Theme.of(context).textTheme.titleLarge!.copyWith(color: JetsnackColors.light.primary, fontWeight: FontWeight.w800)),
        ),
        SizedBox(
          height: 280,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => _SnackCard(s: items[i]),
          ),
        )
      ],
    );
  }
}

class _SectionCircle extends StatelessWidget {
  final String title;
  final List<SnackItem> items;
  const _SectionCircle({required this.title, required this.items});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(title, style: Theme.of(context).textTheme.titleLarge!.copyWith(color: JetsnackColors.light.primary, fontWeight: FontWeight.w800)),
        ),
        SizedBox(
          height: 150,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, i) => _CircleSnack(s: items[i]),
          ),
        )
      ],
    );
  }
}

class _CircleSnack extends StatelessWidget {
  final SnackItem s;
  const _CircleSnack({required this.s});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/snack/${s.id}'),
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(radius: 44, backgroundImage: AssetImage(s.image)),
            const SizedBox(height: 8),
            Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _SnackCard extends ConsumerWidget {
  final SnackItem s;
  const _SnackCard({required this.s});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = JetsnackTheme.of(context);
    return InkWell(
      onTap: () => context.go('/snack/${s.id}'),
      child: Container(
        width: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.white10,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Gradient top
          Container(
            height: 80,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              gradient: LinearGradient(colors: [colors.primary.withValues(alpha: 0.6), const Color(0xFF8ED2FF).withValues(alpha: 0.6)]),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -40),
            child: Align(
              alignment: Alignment.topCenter,
              child: CircleAvatar(radius: 46, backgroundImage: AssetImage(s.image)),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(s.tagline, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('\$${(s.price / 100).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                IconButton(
                  icon: const Icon(Icons.add_shopping_cart),
                  onPressed: () => ref.read(cartProvider.notifier).add(s.id),
                  visualDensity: VisualDensity.compact,
                ),
              ])
            ]),
          )
        ]),
      ),
    );
  }
}

class _Collection {
  final int id;
  final String name;
  final String type;
  final List<int> snackIds;
  const _Collection(this.id, this.name, this.type, this.snackIds);
}

Future<List<_Collection>> _loadCollections() async {
  final raw = await rootBundle.loadString('assets/mock/collections.json');
  final data = jsonDecode(raw) as Map<String, dynamic>;
  final list = (data['collections'] as List).cast<Map<String, dynamic>>();
return list
      .map((e) => _Collection(
            e['id'] as int,
            e['name'] as String,
            (e['type'] ?? 'normal') as String,
            (e['snackIds'] as List).map((x) => x as int).toList(),
          ))
      .toList();
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(snacksRepoProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search snacks'),
            onChanged: (v) => setState(() => q = v.trim()),
          ),
        ),
        Expanded(
          child: FutureBuilder(
            future: repo.getSnacks(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                debugPrint('Search load error: \'${snapshot.error}\'');
                return const Center(child: Text('Error cargando resultados'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final snacks = snapshot.data!.where((s) => q.isEmpty || s.name.toLowerCase().contains(q.toLowerCase())).toList();
              if (snacks.isEmpty) return const Center(child: Text('No results'));
              return ListView(
                children: snacks
                    .map((s) => ListTile(
leading: CircleAvatar(backgroundImage: AssetImage(s.image)),
                          title: Text(s.name),
                          onTap: () => context.go('/snack/${s.id}'),
                        ))
                    .toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(snacksRepoProvider);
    final cart = ref.watch(cartProvider);
    return FutureBuilder(
      future: repo.getSnacks(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = snapshot.data!;
        final items = cart.quantities.entries.toList();
        if (items.isEmpty) return const Center(child: Text('Cart is empty'));
        return ListView(
          children: items.map((e) {
            final s = all.firstWhere((x) => x.id == e.key);
            return ListTile(
leading: CircleAvatar(backgroundImage: AssetImage(s.image)),
              title: Text(s.name),
              subtitle: Text('Qty: ${e.value}  •  \$${(s.price * e.value / 100).toStringAsFixed(2)}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.remove), onPressed: () => ref.read(cartProvider.notifier).remove(s.id)),
                IconButton(icon: const Icon(Icons.add), onPressed: () => ref.read(cartProvider.notifier).add(s.id)),
              ]),
            );
          }).toList(),
        );
      },
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('Profile'));
}

class SnackDetailScreen extends ConsumerWidget {
  final int id;
  const SnackDetailScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(snacksRepoProvider);
    return FutureBuilder(
      future: repo.getSnack(id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final s = snapshot.data!;
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 260,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(s.name),
                  background: Stack(
                    fit: StackFit.expand,
children: [
                      Image.asset(s.image, fit: BoxFit.cover),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black54],
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.tagline, style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 16),
                      Text('Price: \$${(s.price / 100).toStringAsFixed(2)}'),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => ref.read(cartProvider.notifier).add(s.id),
                        icon: const Icon(Icons.add_shopping_cart),
                        label: const Text('Add to cart'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
