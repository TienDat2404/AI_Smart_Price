import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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
        // Backend C# record trả về PascalCase: Token, UserId, Name, Email, IsAdmin
        token:   (json['Token']   ?? json['token'])   as String,
        userId:  (json['UserId']  ?? json['userId'])  as String,
        name:    (json['Name']    ?? json['name'])    as String,
        email:   (json['Email']   ?? json['email'])   as String,
        isAdmin: (json['IsAdmin'] ?? json['isAdmin'] ?? false) as bool,
      );
}

/// Thống kê thu/chi từ GET /api/transactions/stats
class TransactionStats {
  final int totalTransactions;
  final double totalExpense;
  final double totalIncome;
  final double balance;
  final double monthExpense;
  final double monthIncome;
  final double monthBalance;

  const TransactionStats({
    required this.totalTransactions,
    required this.totalExpense,
    required this.totalIncome,
    required this.balance,
    this.monthExpense = 0,
    this.monthIncome  = 0,
    this.monthBalance = 0,
  });

  factory TransactionStats.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) =>
        v is String ? double.tryParse(v) ?? 0.0 : (v as num? ?? 0).toDouble();

    return TransactionStats(
      totalTransactions: (json['totalTransactions'] as num? ?? 0).toInt(),
      totalExpense:  toDouble(json['totalExpense']),
      totalIncome:   toDouble(json['totalIncome']),
      balance:       toDouble(json['balance']),
      monthExpense:  toDouble(json['monthExpense']),
      monthIncome:   toDouble(json['monthIncome']),
      monthBalance:  toDouble(json['monthBalance']),
    );
  }
}

/// Service giao tiếp với ASP.NET Core Backend API.
///
/// Cấu hình baseUrl theo môi trường:
/// - Windows Desktop   : http://127.0.0.1:5261/api
/// - Android Emulator  : http://10.0.2.2:5261/api
/// - iOS Simulator     : http://127.0.0.1:5261/api
/// - Thiết bị thật     : http://[IP_LAN]:5261/api
class ApiService {
  // ✅ 127.0.0.1 thay vì localhost để tránh DNS resolution issue trên Windows
  static const String _baseUrl = 'http://127.0.0.1:5261/api';

  static const Duration _timeout = Duration(seconds: 15);

  ApiService._();
  static final ApiService instance = ApiService._();

  // ── HTTP helpers ──────────────────────────────────────────────────────────

  Map<String, String> _headers({String? token}) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  dynamic _parseResponse(http.Response response) {
    final body = utf8.decode(response.bodyBytes);
    // Debug log — xóa khi release
    debugPrint('[API] ${response.request?.method} ${response.request?.url} → ${response.statusCode}');
    if (body.isNotEmpty) debugPrint('[API] Response body: $body');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body.isNotEmpty ? jsonDecode(body) : null;
    }
    String message = 'Lỗi không xác định';
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      message = json['message'] as String? ?? json['title'] as String? ?? message;
    } catch (_) {
      message = body.isNotEmpty ? body : 'HTTP ${response.statusCode}';
    }
    throw ApiException(response.statusCode, message);
  }

  Future<dynamic> _get(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
    debugPrint('[API] GET $uri');
    try {
      final response = await http.get(uri, headers: _headers()).timeout(_timeout);
      return _parseResponse(response);
    } catch (e) {
      debugPrint('[API] GET ERROR: $e');
      rethrow;
    }
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$_baseUrl$path');
    debugPrint('[API] POST $uri body: ${jsonEncode(body)}');
    try {
      final response = await http
          .post(uri, headers: _headers(), body: jsonEncode(body))
          .timeout(_timeout);
      return _parseResponse(response);
    } catch (e) {
      debugPrint('[API] POST ERROR: ${e.runtimeType}: $e');
      rethrow;
    }
  }

  Future<dynamic> _patch(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$_baseUrl$path');
    debugPrint('[API] PATCH $uri');
    try {
      final response = await http
          .patch(uri, headers: _headers(), body: jsonEncode(body))
          .timeout(_timeout);
      return _parseResponse(response);
    } catch (e) {
      debugPrint('[API] PATCH ERROR: $e');
      rethrow;
    }
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  /// POST /api/users/login
  Future<LoginResponse> login({
    required String email,
    required String password,
  }) async {
    final data = await _post('/users/login', {
      'email': email.trim().toLowerCase(),
      'password': password,
    });
    return LoginResponse.fromJson(data as Map<String, dynamic>);
  }

  /// POST /api/users/register
  Future<LoginResponse> register({
    required String name,
    required String email,
    required String password,
  }) async {
    await _post('/users/register', {
      'fullName': name.trim(),   // backend nhận FullName
      'email': email.trim().toLowerCase(),
      'password': password,
    });
    // register trả về UserDto, không phải LoginResponse
    // → tự động login sau khi đăng ký
    return await login(email: email, password: password);
  }

  // ── Transactions ──────────────────────────────────────────────────────────

  /// GET /api/transactions?userId={userId}
  Future<List<Transaction>> getTransactions(String userId) async {
    final data = await _get('/transactions', query: {'userId': userId});
    return (data as List)
        .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/transactions/stats?userId={userId}
  Future<TransactionStats> getTransactionStats(String userId) async {
    final data = await _get('/transactions/stats', query: {'userId': userId});
    return TransactionStats.fromJson(data as Map<String, dynamic>);
  }

  /// GET /api/transactions/recent?userId={userId}&limit={limit}
  Future<List<Transaction>> getRecentTransactions(String userId, {int limit = 5}) async {
    final data = await _get('/transactions/recent', query: {
      'userId': userId,
      'limit': limit.toString(),
    });
    return (data as List)
        .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/transactions — trả về { transaction, newBalance, totalIncome, totalExpense }
  Future<Map<String, dynamic>> saveTransactionWithBalance(Transaction transaction) async {
    final data = await _post('/transactions', transaction.toJson());
    return data as Map<String, dynamic>;
  }

  /// POST /api/transactions (backward compat)
  Future<Transaction> saveTransaction(Transaction transaction) async {
    final data = await _post('/transactions', transaction.toJson());
    final map  = data as Map<String, dynamic>;
    // Response có thể là { transaction: {...}, newBalance: ... } hoặc Transaction trực tiếp
    final txData = map.containsKey('transaction') ? map['transaction'] : map;
    return Transaction.fromJson(txData as Map<String, dynamic>);
  }

  /// GET /api/transactions/{id}
  Future<Transaction> getTransactionById(String id) async {
    final data = await _get('/transactions/$id');
    return Transaction.fromJson(data as Map<String, dynamic>);
  }

  // ── Budgets ───────────────────────────────────────────────────────────────

  Future<List<Budget>> getBudgets(String userId) async {
    final data = await _get('/budgets', query: {'userId': userId});
    return (data as List)
        .map((e) => Budget.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Budget> saveBudget(Budget budget) async {
    final data = await _post('/budgets', budget.toJson());
    return Budget.fromJson(data as Map<String, dynamic>);
  }

  // ── Users (Admin) ─────────────────────────────────────────────────────────

  Future<List<User>> getAllUsers() async {
    final data = await _get('/users');
    return (data as List)
        .map((e) => User.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> setUserActive(String userId, {required bool isActive}) async {
    await _patch('/users/$userId', {'isActive': isActive});
  }

  // ── Wallet Balance ────────────────────────────────────────────────────────

  /// GET /api/wallet/balance?userId={userId}
  /// Trả về số dư thực tế tính từ toàn bộ lịch sử giao dịch.
  Future<double> getWalletBalance(String userId) async {
    try {
      final data = await _get('/wallet/balance', query: {'userId': userId});
      final map  = data as Map<String, dynamic>;
      return (map['balance'] as num? ?? 0).toDouble();
    } catch (_) {
      // Fallback: tính từ mockWallets nếu API chưa chạy
      return 0;
    }
  }

  /// POST /api/wallet/deposit — nạp tiền vào ví
  Future<void> deposit({
    required String userId,
    required double amount,
    String? note,
  }) async {
    await _post('/wallet/deposit', {
      'userId': userId,
      'amount': amount,
      if (note != null) 'note': note,
    });
  }

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

  Future<Map<String, dynamic>> getAdminStats() async {
    final data = await _get('/admin/stats');
    return data as Map<String, dynamic>;
  }

  // ── Bank Accounts (SePay) ────────────────────────────────────────────────

  /// GET /api/wallet/bank-balance?userId={userId}
  /// Trả về số dư thực từ BankAccounts (SePay webhook).
  /// Nếu chưa liên kết → hasBankLink = false.
  Future<Map<String, dynamic>> getBankBalance(String userId) async {
    final data = await _get('/wallet/bank-balance', query: {'userId': userId});
    return data as Map<String, dynamic>;
  }

  /// PATCH /api/bank-accounts/{id}/set-initial-balance
  /// Cập nhật số dư ban đầu của tài khoản ngân hàng (dùng trong EditWalletScreen).
  Future<void> setInitialBankBalance({
    required String accountId,
    required double balance,
  }) async {
    await _patch('/bank-accounts/$accountId/set-initial-balance', {'balance': balance});
  }

  /// GET /api/bank-accounts?userId={userId}
  Future<List<Map<String, dynamic>>> getBankAccounts(String userId) async {
    final data = await _get('/bank-accounts', query: {'userId': userId});
    return (data as List).cast<Map<String, dynamic>>();
  }

  /// GET /api/bank-accounts/supported-banks
  Future<List<Map<String, dynamic>>> getSupportedBanks() async {
    final data = await _get('/bank-accounts/supported-banks');
    return (data as List).cast<Map<String, dynamic>>();
  }

  /// POST /api/bank-accounts/link
  Future<Map<String, dynamic>> linkBankAccount({
    required String userId,
    required String bankName,
    required String accountNumber,
    required String accountHolder,
    required String sePayToken,
  }) async {
    final data = await _post('/bank-accounts/link', {
      'userId':        userId,
      'bankName':      bankName,
      'accountNumber': accountNumber,
      'accountHolder': accountHolder,
      'sePayToken':    sePayToken,
    });
    return data as Map<String, dynamic>;
  }

  /// DELETE /api/bank-accounts/{id}
  Future<void> unlinkBankAccount(String accountId) async {
    final uri = Uri.parse('$_baseUrl/bank-accounts/$accountId');
    debugPrint('[API] DELETE $uri');
    final response = await http.delete(uri, headers: _headers()).timeout(_timeout);
    _parseResponse(response);
  }

  // ── Savings Goals ─────────────────────────────────────────────────────────

  /// GET /api/savings-goals?userId={userId}
  Future<List<Map<String, dynamic>>> getSavingsGoals(String userId) async {
    final data = await _get('/savings-goals', query: {'userId': userId});
    return (data as List).cast<Map<String, dynamic>>();
  }

  /// POST /api/savings-goals
  Future<Map<String, dynamic>> createSavingsGoal({
    required String userId,
    required String title,
    required double targetAmount,
    required String deadline,
    required String categoryIcon,
    required String color,
    String? aiInsight,
  }) async {
    final data = await _post('/savings-goals', {
      'userId':       userId,
      'title':        title,
      'targetAmount': targetAmount,
      'deadline':     deadline,
      'categoryIcon': categoryIcon,
      'color':        color,
      if (aiInsight != null) 'aiInsight': aiInsight,
    });
    return data as Map<String, dynamic>;
  }

  /// PATCH /api/savings-goals/{id}/add
  Future<Map<String, dynamic>> addToSavingsGoal({
    required String goalId,
    required double amount,
  }) async {
    final data = await _patch('/savings-goals/$goalId/add', {'amount': amount});
    return data as Map<String, dynamic>;
  }

  /// PATCH /api/savings-goals/{id}/withdraw
  Future<Map<String, dynamic>> withdrawFromSavingsGoal({
    required String goalId,
    required double amount,
  }) async {
    final data = await _patch('/savings-goals/$goalId/withdraw', {'amount': amount});
    return data as Map<String, dynamic>;
  }

  /// DELETE /api/savings-goals/{id}
  Future<void> deleteSavingsGoal(String goalId) async {
    final uri = Uri.parse('$_baseUrl/savings-goals/$goalId');
    final response = await http.delete(uri, headers: _headers()).timeout(_timeout);
    _parseResponse(response);
  }

  // ── Analytics ─────────────────────────────────────────────────────────────

  /// GET /api/analytics/category-summary?userId={userId}
  Future<Map<String, dynamic>> getCategorySummary(String userId) async {
    final data = await _get('/analytics/category-summary', query: {'userId': userId});
    return data as Map<String, dynamic>;
  }

  /// GET /api/analytics/ai-advice?userId={userId}
  Future<Map<String, dynamic>> getAiAdvice(String userId) async {
    final data = await _get('/analytics/ai-advice', query: {'userId': userId});
    return data as Map<String, dynamic>;
  }

  // ── Invoice / OCR ─────────────────────────────────────────────────────────

  /// POST /api/invoice/scan
  ///
  /// Gửi ảnh hóa đơn dưới dạng multipart/form-data (field: "image").
  /// Timeout 30s để chờ AI Engine xử lý.
  ///
  /// Throws:
  /// - [ApiException(422)] nếu không nhận diện được hóa đơn
  /// - [ApiException(4xx/5xx)] cho các lỗi server khác
  /// - [Exception] nếu mất kết nối / timeout
  Future<Map<String, dynamic>> scanInvoice(String imagePath) async {
    final uri = Uri.parse('$_baseUrl/invoice/scan');

    // Timeout dài hơn cho OCR — lần đầu EasyOCR tải model có thể mất 2-3 phút
    const ocrTimeout = Duration(seconds: 180);

    final request = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'application/json'
      ..files.add(await http.MultipartFile.fromPath('image', imagePath));

    // Log URL thực tế để debug 404
    debugPrint('=== [SCAN] Dang goi API tai: $uri ===');
    debugPrint('[API] POST multipart $uri');
    debugPrint('[API] Image: $imagePath');

    try {
      final streamed = await request.send().timeout(ocrTimeout);
      final response = await http.Response.fromStream(streamed);

      debugPrint('[API] Invoice scan → ${response.statusCode}');
      debugPrint('[API] Body: ${response.body}');

      final bodyBytes = response.bodyBytes;
      final bodyStr   = utf8.decode(bodyBytes);

      // ── 200 OK ────────────────────────────────────────────────────────────
      if (response.statusCode == 200) {
        final json = jsonDecode(bodyStr) as Map<String, dynamic>;
        // Normalize keys — backend trả PascalCase, hỗ trợ cả camelCase
        return {
          'storeName':   json['StoreName']   ?? json['storeName']   ?? 'Khong ro',
          'totalAmount': (json['TotalAmount'] ?? json['totalAmount'] ?? 0).toDouble(),
          'date':        json['Date']        ?? json['date']        ?? '',
          'category':    json['Category']    ?? json['category']    ?? 'Khac',
          'invoiceId':   json['InvoiceId']   ?? json['invoiceId']   ?? '',
          'confidence':  (json['Confidence'] ?? json['confidence']  ?? 0).toDouble(),
          'fileName':    json['FileName']    ?? json['fileName']    ?? '',
          // Status từ Python: "success" | "low_confidence" | "failed"
          'status':      json['Status']      ?? json['status']      ?? 'success',
          'suggestions': (json['Suggestions'] ?? json['suggestions'] ?? []) as List,
          'raw_text':    json['RawText']     ?? json['rawText']     ?? json['raw_text'] ?? '',
        };
      }

      // ── 422 Unprocessable — không nhận diện được ──────────────────────────
      if (response.statusCode == 422) {
        throw const ApiException(422,
            'Khong the nhan dien hoa don nay, vui long thu lai hoac nhap tay.');
      }

      // ── Các lỗi khác ──────────────────────────────────────────────────────
      String msg = 'Loi server (${response.statusCode})';
      try {
        final body = jsonDecode(bodyStr) as Map<String, dynamic>;
        msg = body['message'] as String? ?? body['title'] as String? ?? msg;
      } catch (_) {}
      throw ApiException(response.statusCode, msg);

    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(408, 'Qua thoi gian cho. AI Engine co the dang qua tai, vui long thu lai.');
    } catch (e) {
      debugPrint('[API] scanInvoice ERROR: ${e.runtimeType}: $e');
      if (e is ApiException) rethrow;
      throw Exception('Khong the ket noi den server. Kiem tra lai mang va thu lai.');
    }
  }
}
