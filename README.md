ShopX — Daraz-Style Flutter App
A Flutter product listing app using the FakeStore API with a robust single-scroll architecture.
Run Instructions
bashflutter pub get
flutter run
Demo credentials: johnd / m38rmF$

Architecture Explanation
1. How Horizontal Swipe Was Implemented
A GestureDetector wraps the entire Scaffold body and intercepts onHorizontalDragStart/Update/End events. In onHorizontalDragUpdate, we compare |dx| vs |dy| — only when |dx| > 50px AND |dx| > |dy| * 1.5 do we commit a tab change via TabController.animateTo().
The PageView uses NeverScrollableScrollPhysics(), so its own swipe detection is fully disabled. This prevents two gesture recognizers from competing. The TabController drives the PageView via pageController.animateToPage() on tab change.
Result: Horizontal swipes change tabs predictably. Vertical scrolls are never accidentally interpreted as tab changes.
2. Who Owns the Vertical Scroll and Why
NestedScrollView is the single vertical scroll owner. It coordinates:

The collapsible SliverAppBar (banner + search bar)
The sticky SliverPersistentHeader containing the TabBar
The inner body CustomScrollView in each tab page

Each tab's CustomScrollView (containing a SliverGrid) uses NestedScrollView's inner scroll mechanics — it is not an independent scrollable. There is exactly one Scrollable in the vertical axis.
AutomaticKeepAliveClientMixin on each _ProductTabState keeps tab pages alive when switching, so scroll position is preserved without reset.
3. Trade-offs / Limitations
Trade-offDetailSwipe thresholdFast diagonal swipes lean vertical rather than horizontal — intentional for safetyFakeStore APIReturns same user (id=1) for any valid login — we always fetch user 1Tab scroll isolationEach tab's inner scroll is managed by NestedScrollView; adding deeply nested scrollables would break thisPull-to-refreshTriggers refresh for all tabs simultaneously for simplicityNo infinite scrollFakeStore returns all products at once; pagination not needed