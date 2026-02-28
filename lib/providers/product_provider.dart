import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../services/api_service.dart';

enum LoadState { idle, loading, loaded, error }

class TabProducts {
  List<Product> products;
  LoadState state;
  String? error;

  TabProducts({
    this.products = const [],
    this.state = LoadState.idle,
    this.error,
  });
}

/// Owns all product data for every tab.
/// Each tab key maps to a [TabProducts] instance.
class ProductProvider extends ChangeNotifier {
  final Map<String, TabProducts> _tabData = {};
  List<String> _categories = [];
  bool _categoriesLoaded = false;

  List<String> get categories => _categories;
  bool get categoriesLoaded => _categoriesLoaded;

  TabProducts dataForTab(String key) =>
      _tabData[key] ?? TabProducts(state: LoadState.idle);

  Future<void> loadCategories() async {
    if (_categoriesLoaded) return;
    try {
      final cats = await ApiService.getCategories();
      // Use first 3 categories as our 3 tabs
      _categories = cats.take(3).toList();
      _categoriesLoaded = true;
      notifyListeners();
    } catch (e) {
      _categories = ["electronics", "jewelery", "men's clothing"];
      _categoriesLoaded = true;
      notifyListeners();
    }
  }

  Future<void> loadProducts(String category, {bool refresh = false}) async {
    final current = _tabData[category];
    if (!refresh && current != null && current.state == LoadState.loaded) return;

    _tabData[category] = TabProducts(state: LoadState.loading);
    notifyListeners();

    try {
      final products = category == 'all'
          ? await ApiService.getAllProducts()
          : await ApiService.getProductsByCategory(category);
      _tabData[category] = TabProducts(products: products, state: LoadState.loaded);
    } catch (e) {
      _tabData[category] = TabProducts(state: LoadState.error, error: e.toString());
    }
    notifyListeners();
  }
}