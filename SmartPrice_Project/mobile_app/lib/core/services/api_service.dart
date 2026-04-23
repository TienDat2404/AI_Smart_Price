import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/transaction.dart';
import '../models/budget.dart';
import '../models/user.dart';

/// Lỗi trả về từ API — bao gồm HTTP status code và message.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Kết quả trả về từ POST /api/auth/login.
class LoginResponse {
  final String token;
  final String userId;
  final String name;
  final String email;
  final bool isAdmin;

  const LoginResponse({
    required this.token,
    required this.userId,
    required this.name,
    required this.email,
    required this.isAdmin,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
        token: json['token'] as String,
        userId: json['userId'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        isAdmin: json['isAdmin'] as bool? ?? false,
      );
}

/// Service giao tiếp với ASP.NET Core Backend API.
///
/// Cấu hình baseUrl:
/// - Emulator Android  : http://10.0.2.2:5000/api
/// - iOS Simulator     : http://localhost:5000/api
/// - Thiết bị thật     : http://<IP_máy_tính>:5000/api
class ApiService {
  static const String _baseUrl = 'http://10.0.2.2:5000/api';

  // Timeout mặc định cho mọi request
  static const Duration _timeout = Duration(seconds: 15);

  ApiService._();
  static final ApiService instance = ApiService._();

  // ── HTTP helpers ──────────────────────────────────────────────────────

  /// Header chung — thêm Authorization token khi có.
  Map<String, String> _headers({String? token}) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  /// Parse response và ném [ApiException] nếu status không thành công.
  dynamic _parseResponse(http.Response response) {
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body.isNotEmpty ? jsonDecode(body) : null;
    }
    // Cố gắng lấy message từ body JSON
    String message = 'Lỗi không xác định';
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      message = json['message'] as String? ??
          json['title'] as String? ??
          message;
    } catch (_) {
      message = body.isNotEmpty ? body : 'HTTP ${response.statusCode}';
    }
    throw ApiException(response.statusCode, message);
  }

  Future<dynamic> _get(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$_baseUrl$path')
        .replace(queryParameters: query);
    final response = await http.get(uri, headers: _headers()).timeout(_timeout);
    return _parseResponse(response);
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await http
        .post(uri, headers: _headers(), body: jsonEncode(body))
        .timeout(_timeout);
    return _parseResponse(response);
  }

  Future<dynamic> _patch(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await http
        .patch(uri, headers: _headers(), body: jsonEncode(body))
        .timeout(_timeout);
    return _parseResponse(response);
  }

  // ── Auth ──────────────────────────────────────────────────────────────

  /// POST /api/auth/login
  ///
  /// Gửi email + password, nhận JWT token và thông tin user.
  /// Ném [ApiException] với statusCode 401 nếu sai thông tin.
  Future<LoginResponse> login({
    required String email,
    required String password,
  }) async {
    final data = await _post('/auth/login', {
      'email': email.trim().toLowerCase(),
      'password': password,
    });
    return LoginResponse.fromJson(data as Map<String, dynamic>);
  }

  /// POST /api/auth/register
  Future<LoginResponse> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final data = await _post('/auth/register', {
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'password': password,
    });
    return LoginResponse.fromJson(data as Map<String, dynamic>);
  }

  // ── Transactions ──────────────────────────────────────────────────────

  /// GET /api/transactions?userId={userId}
  ///
  /// Trả về danh sách giao dịch của một user.
  Future<List<Transaction>> getTransactions(String userId) async {
    final data = await _get('/transactions', query: {'userId': userId});
    return (data as List)
        .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/transactions
  ///
  /// Lưu một giao dịch mới vào MongoDB.
  Future<Transaction> saveTransaction(Transaction transaction) async {
    final data = await _post('/transactions', transaction.toJson());
    return Transaction.fromJson(data as Map<String, dynamic>);
  }

  /// GET /api/transactions/{id}
  Future<Transaction> getTransactionById(String id) async {
    final data = await _get('/transactions/$id');
    return Transaction.fromJson(data as Map<String, dynamic>);
  }

  // ── Budgets ───────────────────────────────────────────────────────────

  /// GET /api/budgets?userId={userId}
  Future<List<Budget>> getBudgets(String userId) async {
    final data = await _get('/budgets', query: {'userId': userId});
    return (data as List)
        .map((e) => Budget.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/budgets
  Future<Budget> saveBudget(Budget budget) async {
    final data = await _post('/budgets', budget.toJson());
    return Budget.fromJson(data as Map<String, dynamic>);
  }

  // ── Users (Admin) ─────────────────────────────────────────────────────

  /// GET /api/users
  ///
  /// Lấy toàn bộ danh sách user — chỉ dành cho Admin.
  Future<List<User>> getAllUsers() async {
    final data = await _get('/users');
    return (data as List)
        .map((e) => User.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// PATCH /api/users/{userId}
  ///
  /// Khóa / mở khóa tài khoản user.
  Future<void> setUserActive(String userId, {required bool isActive}) async {
    await _patch('/users/$userId', {'isActive': isActive});
  }

  // ── Admin ─────────────────────────────────────────────────────────────

  /// GET /api/admin/transactions
  ///
  /// Lấy toàn bộ giao dịch của mọi user — chỉ dành cho Admin.
  Future<List<Transaction>> getAllTransactions({
    String? userId,
    DateTime? from,
    DateTime? to,
    double? minAmount,
    double? maxAmount,
  }) async {
    final query = <String, String>{
      if (userId != null) 'userId': userId,
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
      if (minAmount != null) 'minAmount': minAmount.toString(),
      if (maxAmount != null) 'maxAmount': maxAmount.toString(),
    };
    final data = await _get('/admin/transactions', query: query);
    return (data as List)
        .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/admin/stats
  ///
  /// Thống kê tổng quan cho Admin Overview.
  Future<Map<String, dynamic>> getAdminStats() async {
    final data = await _get('/admin/stats');
    return data as Map<String, dynamic>;
  }
}
