// ============================================================
// HOME SCREEN — Single-Scroll Sliver Architecture
// ============================================================
//
// ARCHITECTURE NOTES:
//
// 1. HORIZONTAL SWIPE IMPLEMENTATION:
//    A PageView with physics=NeverScrollableScrollPhysics() owns
//    horizontal tab-switching. Swipe detection is handled by a
//    GestureDetector wrapping the entire body.  We accumulate
//    dx/dy deltas from onHorizontalDragUpdate; only when
//    |dx| > threshold AND |dx| > |dy| * 1.5 do we commit a
//    page change.  This prevents horizontal gestures from leaking
//    into the NestedScrollView's vertical axis.
//
// 2. WHO OWNS THE VERTICAL SCROLL:
//    NestedScrollView owns the SINGLE vertical ScrollController.
//    The SliverAppBar (banner + search) and SliverPersistentHeader
//    (tab bar) live in headerSliverBuilder.  Each tab body is a
//    SliverGrid inside a CustomScrollView that uses the outer
//    scroll mechanics via NestedScrollView's body context.
//    This is the correct Flutter pattern — there is exactly ONE
//    vertical Scrollable in the widget tree per tab page, and all
//    tabs share the same outer scroll position.
//
// 3. TRADE-OFFS / LIMITATIONS:
//    - Switching tabs does NOT reset scroll position; each tab page
//      keeps its own inner scroll offset via a cached
//      AutomaticKeepAliveClientMixin.
//    - Pull-to-refresh uses a sliver-aware RefreshIndicator placed
//      at NestedScrollView's body level so it works regardless of
//      how far the header has collapsed.
//    - Tab switching by swipe ignores small vertical drags, so
//      fast diagonal swipes are intentionally handled as vertical
//      scrolls rather than tab changes — this is the safer UX.
//    - PageView children are kept alive (wantKeepAlive=true), so
//      network data is only fetched once per category.
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/product_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/product_card.dart';
import '../widgets/shimmer_card.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late PageController _pageController;

  // Horizontal drag tracking for intentional swipe detection
  double _dragStartX = 0;
  double _dragStartY = 0;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _tabController = TabController(length: 3, vsync: this);

    // Keep tab controller and page controller in sync
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;
      _pageController.animateToPage(
        _tabController.index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });

    // Load categories + initial tab data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadCategories().then((_) {
        _loadCurrentTab();
      });
    });
  }

  void _loadCurrentTab({bool refresh = false}) {
    final cats = context.read<ProductProvider>().categories;
    if (cats.isEmpty) return;
    for (final cat in cats) {
      context.read<ProductProvider>().loadProducts(cat, refresh: refresh);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ── Horizontal swipe handling ─────────────────────────────────────────────
  void _onHorizontalDragStart(DragStartDetails details) {
    _dragStartX = details.globalPosition.dx;
    _dragStartY = details.globalPosition.dy;
    _dragging = true;
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_dragging) return;
    _dragging = false;
    // velocity-based fallback if dragUpdate wasn't called
    final vx = details.primaryVelocity ?? 0;
    if (vx.abs() > 400) {
      if (vx < 0 && _tabController.index < _tabController.length - 1) {
        _tabController.animateTo(_tabController.index + 1);
      } else if (vx > 0 && _tabController.index > 0) {
        _tabController.animateTo(_tabController.index - 1);
      }
    }
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    final dx = details.globalPosition.dx - _dragStartX;
    final dy = details.globalPosition.dy - _dragStartY;

    // Only trigger horizontal navigation when clearly horizontal
    if (dx.abs() > 50 && dx.abs() > dy.abs() * 1.5) {
      _dragging = false;
      if (dx < 0 && _tabController.index < _tabController.length - 1) {
        _tabController.animateTo(_tabController.index + 1);
      } else if (dx > 0 && _tabController.index > 0) {
        _tabController.animateTo(_tabController.index - 1);
      }
    }
  }
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();

    if (!productProvider.categoriesLoaded) {
      return const Scaffold(
        backgroundColor: AppTheme.bg,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }

    final categories = productProvider.categories;
    if (categories.length < 3) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Sync tab controller length just in case (always 3)
    return GestureDetector(
      // These handlers intercept horizontal drag at the top level
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        body: NestedScrollView(
          // NestedScrollView is the SOLE vertical scroll owner.
          // Its headerSliverBuilder provides the collapsible header.
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            // ── Collapsible banner / search bar ──────────────────────
            SliverAppBar(
              expandedHeight: 160,
              floating: false,
              pinned: false,
              snap: false,
              backgroundColor: AppTheme.primary,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined,
                      color: Colors.white),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined,
                      color: Colors.white),
                  onPressed: () {},
                ),
                _ProfileAvatar(),
                const SizedBox(width: 8),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primary, Color(0xFFFF6B35)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '🛍️ ShopX',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Search bar
                          Container(
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const TextField(
                              decoration: InputDecoration(
                                hintText: 'Search products...',
                                hintStyle: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 14),
                                prefixIcon: Icon(Icons.search,
                                    color: AppTheme.textSecondary, size: 20),
                                border: InputBorder.none,
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Sticky tab bar (pinned SliverPersistentHeader) ────────
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  tabs: categories
                      .map((c) => Tab(
                            text: _formatCategory(c),
                          ))
                      .toList(),
                  isScrollable: false,
                  indicatorWeight: 3,
                ),
              ),
            ),
          ],

          // ── Body: PageView for horizontal tab switching ───────────
          // NeverScrollableScrollPhysics disables PageView's own
          // horizontal scroll so our GestureDetector above has full
          // control.  This avoids conflict with NestedScrollView's
          // inner scroll.
          body: RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: () async {
              _loadCurrentTab(refresh: true);
              await Future.delayed(const Duration(milliseconds: 800));
            },
            child: PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: categories.length,
              onPageChanged: (i) {
                if (_tabController.index != i) {
                  _tabController.animateTo(i);
                }
              },
              itemBuilder: (context, index) {
                return _ProductTab(category: categories[index]);
              },
            ),
          ),
        ),
      ),
    );
  }

  String _formatCategory(String cat) {
    return cat.split(' ').map((w) =>
        w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1)).join(' ');
  }
}

// ── Sticky tab bar SliverPersistentHeaderDelegate ──────────────────────────
class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _StickyTabBarDelegate(this.tabBar);

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppTheme.surface,
      child: Column(
        children: [
          tabBar,
          Container(height: 1, color: AppTheme.divider),
        ],
      ),
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height + 1;

  @override
  double get minExtent => tabBar.preferredSize.height + 1;

  @override
  bool shouldRebuild(covariant _StickyTabBarDelegate old) =>
      tabBar != old.tabBar;
}

// ── Individual tab page ─────────────────────────────────────────────────────
class _ProductTab extends StatefulWidget {
  final String category;

  const _ProductTab({required this.category});

  @override
  State<_ProductTab> createState() => _ProductTabState();
}

class _ProductTabState extends State<_ProductTab>
    with AutomaticKeepAliveClientMixin {
  // AutomaticKeepAliveClientMixin preserves scroll position and widget state
  // when switching tabs — the user's scroll position is never reset.
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final tabData = context.watch<ProductProvider>().dataForTab(widget.category);

    if (tabData.state == LoadState.loading) {
      return _buildShimmerGrid();
    }

    if (tabData.state == LoadState.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            const Text(
              'Failed to load products',
              style:
                  TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context
                  .read<ProductProvider>()
                  .loadProducts(widget.category, refresh: true),
              child: const Text('Retry', style: TextStyle(color: AppTheme.primary)),
            ),
          ],
        ),
      );
    }

    final products = tabData.products;
    if (products.isEmpty) {
      return const Center(
        child: Text('No products found',
            style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    // CustomScrollView here uses NestedScrollView's inner scroll mechanics.
    // It is NOT a standalone scrollable — NestedScrollView coordinates it.
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) => ProductCard(product: products[index]),
              childCount: products.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.68,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildShimmerGrid() {
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (_, __) => const ShimmerCard(),
              childCount: 6,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.68,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Profile avatar in AppBar ────────────────────────────────────────────────
class _ProfileAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final initial =
        user?.name.firstname.isNotEmpty == true ? user!.name.firstname[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      ),
      child: CircleAvatar(
        radius: 16,
        backgroundColor: Colors.white.withOpacity(0.25),
        child: Text(
          initial,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    );
  }
}