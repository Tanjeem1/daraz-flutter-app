import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../models/user.dart';

class ApiService {
  static const _base = 'https://corsproxy.io/?https://fakestoreapi.com';

  // ---------- AUTH ----------
static Future<String> login(String username, String password) async {
  final res = await http.post(
    Uri.parse('$_base/auth/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'username': username, 'password': password}),
  );
  if (res.statusCode == 200 || res.statusCode == 201) {
    final data = jsonDecode(res.body);
    return data['token'] as String;
  }
  throw Exception('Login failed: ${res.body}');
}
  // ---------- USER ----------
  static Future<AppUser> getUser(int id) async {
    final res = await http.get(Uri.parse('$_base/users/$id'));
    if (res.statusCode == 200) {
      return AppUser.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to fetch user');
  }

  // ---------- PRODUCTS ----------
  static Future<List<Product>> getAllProducts() async {
    final res = await http.get(Uri.parse('$_base/products'));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => Product.fromJson(e)).toList();
    }
    throw Exception('Failed to fetch products');
  }

  static Future<List<Product>> getProductsByCategory(String category) async {
    final res = await http.get(
      Uri.parse('$_base/products/category/${Uri.encodeComponent(category)}'),
    );
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => Product.fromJson(e)).toList();
    }
    throw Exception('Failed to fetch products for $category');
  }

  static Future<List<String>> getCategories() async {
    final res = await http.get(Uri.parse('$_base/products/categories'));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => e.toString()).toList();
    }
    throw Exception('Failed to fetch categories');
  }
}