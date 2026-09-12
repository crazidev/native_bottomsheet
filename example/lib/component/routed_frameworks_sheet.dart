import 'package:dartnative/flutter_compat.dart';
import 'package:dartnative_bottom_sheet/dartnative_bottom_sheet.dart';

/// A Dart framework or package definition for the search list.
class DartFrameworkItem {
  const DartFrameworkItem({
    required this.name,
    required this.tagline,
    required this.description,
    required this.category,
    required this.badge,
    required this.iconData,
    required this.accentColor,
  });

  final String name;
  final String tagline;
  final String description;
  final String category;
  final String badge;
  final IconData iconData;
  final Color accentColor;
}

const List<DartFrameworkItem> _allFrameworks = [
  DartFrameworkItem(
    name: 'Serverpod',
    tagline: 'The missing backend for Flutter',
    description:
        'Complete server-side Dart framework with ORM, real-time websockets, authentication, and instant API code generation.',
    category: 'Backend & Cloud',
    badge: 'v2.4',
    iconData: CupertinoIcons.cloud_upload_fill,
    accentColor: Color(0xFF007AFF),
  ),
  DartFrameworkItem(
    name: 'FlutterFlow',
    tagline: 'Visual app builder for Flutter',
    description:
        'Low-code platform enabling developers and designers to build production-grade Flutter applications 10x faster.',
    category: 'Visual Builder',
    badge: 'v5.0',
    iconData: CupertinoIcons.sparkles,
    accentColor: Color(0xFF5856D6),
  ),
  DartFrameworkItem(
    name: 'Dart Native',
    tagline: 'Direct native UIKit & Android UI via FFI',
    description:
        'High-performance direct native UI runtime without Flutter or WebViews. Direct FFI binding to Yoga, UIKit, and Android Views.',
    category: 'Native UI & FFI',
    badge: 'v1.0',
    iconData: CupertinoIcons.layers_alt_fill,
    accentColor: Color(0xFF34C759),
  ),
  DartFrameworkItem(
    name: 'Flutter',
    tagline: 'Multi-platform UI from single codebase',
    description:
        'Google’s open source framework for crafting beautiful, natively compiled apps across iOS, Android, web, and desktop.',
    category: 'Multi-Platform',
    badge: 'v3.29',
    iconData: CupertinoIcons.device_phone_portrait,
    accentColor: Color(0xFF30B0C7),
  ),
  DartFrameworkItem(
    name: 'Jaspr',
    tagline: 'Modern full-stack web framework for Dart',
    description:
        'Server-side rendering (SSR), static site generation, and client-side hydration for building fast modern web apps in Dart.',
    category: 'Web & SSR',
    badge: 'v0.16',
    iconData: CupertinoIcons.globe,
    accentColor: Color(0xFFFF9500),
  ),
  DartFrameworkItem(
    name: 'Shelf',
    tagline: 'Web-server middleware ecosystem for Dart',
    description:
        'Modular, composable request/response middleware pipeline for constructing robust HTTP services and microservices.',
    category: 'HTTP & APIs',
    badge: 'v1.4',
    iconData: CupertinoIcons.arrow_right_arrow_left,
    accentColor: Color(0xFFAF52DE),
  ),
  DartFrameworkItem(
    name: 'Riverpod',
    tagline: 'Reactive caching & state management',
    description:
        'Compile-safe, testable state management and dependency injection with automatic disposal and asynchronous provider support.',
    category: 'State Management',
    badge: 'v2.6',
    iconData: CupertinoIcons.arrow_2_circlepath,
    accentColor: Color(0xFFFF2D55),
  ),
  DartFrameworkItem(
    name: 'Bloc',
    tagline: 'Predictable stream-based state pattern',
    description:
        'Enterprise-grade state management separating presentation from business logic using reactive Streams and Cubits.',
    category: 'State Management',
    badge: 'v8.1',
    iconData: CupertinoIcons.cube_box_fill,
    accentColor: Color(0xFF32ADE6),
  ),
  DartFrameworkItem(
    name: 'Dio',
    tagline: 'Powerful HTTP networking for Dart',
    description:
        'Feature-rich networking client supporting interceptors, global configuration, FormData, request cancellation, and file caching.',
    category: 'Networking',
    badge: 'v5.8',
    iconData: CupertinoIcons.arrow_down_circle_fill,
    accentColor: Color(0xFFFF6B35),
  ),
];

/// Full-height bottom sheet example featuring in-sheet navigation via router,
/// scaffold headers, action buttons, close controls, and a searchable framework list.
class RoutedFrameworksSheet extends StatefulWidget {
  const RoutedFrameworksSheet({super.key, required this.controller});

  final DNSheetController controller;

  @override
  State<RoutedFrameworksSheet> createState() => _RoutedFrameworksSheetState();
}

class _RoutedFrameworksSheetState extends State<RoutedFrameworksSheet> {
  int _currentPage = 0;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addPushListener(_onPush);
    widget.controller.addPopListener(_onPop);
  }

  @override
  void dispose() {
    widget.controller.removePushListener(_onPush);
    widget.controller.removePopListener(_onPop);
    super.dispose();
  }

  void _onPush(Object page) {
    if (mounted) {
      setState(() {
        _currentPage = 1;
      });
    }
  }

  void _onPop() {
    if (mounted) {
      setState(() {
        _currentPage = 0;
      });
    }
  }

  void _navigateToSearch() {
    widget.controller.push('frameworks_search');
  }

  void _navigateBack() {
    widget.controller.pop();
  }

  List<DartFrameworkItem> get _filteredFrameworks {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _allFrameworks;
    return _allFrameworks.where((item) {
      return item.name.toLowerCase().contains(query) ||
          item.tagline.toLowerCase().contains(query) ||
          item.category.toLowerCase().contains(query) ||
          item.description.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentPage == 0) {
      return _buildOverviewPage(context);
    } else {
      return _buildSearchPage(context);
    }
  }

  // ── Page 1: Overview & Entry Point ─────────────────────────────────────────
  Widget _buildOverviewPage(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141416),
      brightness: Brightness.dark,
      appBar: AppBar(
        title: const Text(
          'DartNative Bottomsheet',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.xmark, color: Colors.white70),
          onPressed: () => widget.controller.dismiss(),
        ),
        actions: [],
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Hero icon capsule
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withOpacity(0.12),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: const Color(0xFF007AFF).withOpacity(0.35),
                  width: 1.5,
                ),
              ),
              child: const Center(
                child: Icon(
                  CupertinoIcons.cube_box_fill,
                  color: Color(0xFF007AFF),
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Headline
            const Text(
              'Explore Dart Frameworks',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),

            // Subtitle
            const Text(
              'Discover full-stack backends, native UI engines, state managers, and visual builders in the modern Dart ecosystem.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 15,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 36),

            // Centered Router Navigation Button
            FilledButton(
              onPressed: _navigateToSearch,
              child: Text(
                'Browse Dart Frameworks',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Subtle footnote
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.checkmark_seal_fill,
                  color: Color(0xFF34C759),
                  size: 14,
                ),
                SizedBox(width: 6),
                Text(
                  'Hello world :/',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Page 2: Search Bar & Framework List ────────────────────────────────────
  Widget _buildSearchPage(BuildContext context) {
    final frameworks = _filteredFrameworks;

    return Scaffold(
      backgroundColor: const Color(0xFF141416),
      brightness: Brightness.dark,
      appBar: AppBar(
        title: const Text(
          'Dart Frameworks',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        // toolbarHeight: Platform.isIOS ? 0 : null,
        searchBar: SearchBar(
          hintText: 'Search Dart frameworks',
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.chevron_left, color: Colors.white),
          onPressed: _navigateBack,
        ),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.xmark, color: Colors.white70),
            onPressed: () => widget.controller.dismiss(),
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFF141416),
        child: Column(
          children: [
            SizedBox(height: 10),
            // Result count indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _searchQuery.isEmpty
                        ? 'Popular Packages & Frameworks'
                        : 'Results for "$_searchQuery"',
                    style: const TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${frameworks.length} items',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Frameworks List or Empty State
            Expanded(
              child: frameworks.isEmpty
                  ? _buildEmptyState()
                  : FastList(
                      itemCount: frameworks.length,
                      showScrollBar: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      itemBuilder: (context, index) {
                        return _buildFrameworkCard(frameworks[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrameworkCard(DartFrameworkItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2C2C2E), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Framework Icon
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: item.accentColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(item.iconData, color: item.accentColor, size: 20),
                ),
              ),
              const SizedBox(width: 12),

              // Title and category
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.category,
                      style: TextStyle(
                        color: item.accentColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // Version Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.badge,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Description
          Text(
            item.description,
            style: const TextStyle(
              color: Color(0xFFB0B0B5),
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.search, color: Colors.white24, size: 52),
            const SizedBox(height: 16),
            Text(
              'No frameworks found for "$_searchQuery"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try searching for "Serverpod", "Flutterflow", "Dart Native", or "Flutter".',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
