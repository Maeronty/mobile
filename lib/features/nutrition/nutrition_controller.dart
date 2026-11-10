// =============================================================================
// FEATURE: CỐ VẤN DINH DƯỠNG & LẬP THỰC ĐƠN 7 NGÀY (Nutrition Advisor)
// =============================================================================
//
// VAI TRÒ
//   Lưu lựa chọn của người dùng (đối tượng, mục tiêu sức khoẻ, ngày đang xem)
//   và gọi trực tiếp Google Gemini REST API để tạo thực đơn 7 ngày cùng lời khuyên.
//
// FLOW
//   1. Khởi tạo → mặc định "Gia đình (4 người)" + "Cân bằng", nạp thực đơn ban đầu.
//   2. Người dùng chọn chip đối tượng / mục tiêu → `selectTargetGroup` /
//      `selectHealthGoal`.
//   3. Bấm "Tạo lại thực đơn thông minh" → `generatePlan()`:
//        a. isLoading = true, errorMessage = null.
//        b. Gửi HTTP POST trực tiếp tới Gemini REST API (generateContent).
//        c. Phân tích kết quả JSON trả về thành MealPlan 7 ngày, DailyPlan, MealItem.
//        d. Quay về ngày đầu tiên, isLoading = false, trả về true.
//        e. Nếu có lỗi mạng / API / format: isLoading = false, lưu errorMessage,
//           trả về false.
//   4. Chạm chip ngày → `selectDay(index)` → `activeDayPlan` đổi theo.
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/data/recipe_repository.dart';
import '../../core/models/meal_plan.dart';

/// Một lựa chọn hiển thị dạng chip (đối tượng hoặc mục tiêu).
class NutritionOption {
  /// Giá trị lưu & truyền vào bộ tạo thực đơn.
  final String id;

  /// Nhãn chính hiển thị.
  final String label;

  /// Nhãn phụ (số người / mô tả ngắn).
  final String sub;

  const NutritionOption(this.id, this.label, this.sub);
}

class NutritionController extends ChangeNotifier {
  static const Duration fakeGenerateDelay = Duration(milliseconds: 600);

  static const List<NutritionOption> targetGroups = [
    NutritionOption('Cá nhân', 'Cá nhân', '1 người'),
    NutritionOption('Cặp đôi', 'Cặp đôi', '2 người'),
    NutritionOption('Gia đình (4 người)', 'Gia đình', '4 người'),
    NutritionOption('Đại gia đình', 'Đại gia đình', '6+ người'),
  ];

  static const List<NutritionOption> healthGoals = [
    NutritionOption('Cân bằng', 'Cân bằng', 'Tiết kiệm & Đủ chất'),
    NutritionOption('Giảm cân', 'Giảm mỡ', 'Kiểm soát calo'),
    NutritionOption('Tăng cơ', 'Tăng cơ', 'Giàu protein'),
    NutritionOption('Eat Clean', 'Eat Clean', 'Thanh lọc cơ thể'),
  ];

  final http.Client _client;
  final List<String> _apiKeys;
  final String _model;
  final String _baseUrl;
  final bool _ownsClient;
  final Map<String, DateTime> _keyCooldowns = {};

  NutritionController({
    http.Client? client,
    String? apiKey,
    List<String>? apiKeys,
    String? model,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _apiKeys = _resolveApiKeys(apiKey: apiKey, apiKeys: apiKeys),
        _model = _resolveModel(model),
        _baseUrl = baseUrl ??
            const String.fromEnvironment('GEMINI_BASE_URL',
                defaultValue:
                    'https://generativelanguage.googleapis.com/v1beta'),
        _ownsClient = client == null {
    _currentPlan = _buildInitialPlan();
  }

  static List<String> _resolveApiKeys({String? apiKey, List<String>? apiKeys}) {
    final Iterable<String> raw;
    if (apiKeys != null) {
      raw = apiKeys;
    } else if (apiKey != null) {
      raw = apiKey.split(',');
    } else {
      const envKeys = String.fromEnvironment('GEMINI_API_KEYS');
      const envKey = String.fromEnvironment('GEMINI_API_KEY');
      raw = [
        ...envKeys.split(','),
        ...envKey.split(','),
      ];
    }
    return raw.map((k) => k.trim()).where((k) => k.isNotEmpty).toSet().toList();
  }

  static String _resolveModel(String? model) {
    final trimmed = model?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    const envModel = String.fromEnvironment('GEMINI_MODEL');
    return envModel.trim().isNotEmpty ? envModel.trim() : 'gemini-3.8-flash';
  }

  String _selectedTargetGroup = 'Gia đình (4 người)';
  String _selectedHealthGoal = 'Cân bằng';
  int _selectedDayIndex = 0;
  bool _isLoading = false;
  bool _disposed = false;
  String? _errorMessage;
  late MealPlan _currentPlan;

  String get selectedTargetGroup => _selectedTargetGroup;
  String get selectedHealthGoal => _selectedHealthGoal;
  int get selectedDayIndex => _selectedDayIndex;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  MealPlan get currentPlan => _currentPlan;
  List<DailyPlan> get dailyPlans => _currentPlan.dailyPlans;

  /// Kế hoạch của ngày đang chọn (dùng modulo để không vượt quá số ngày).
  DailyPlan get activeDayPlan =>
      dailyPlans[_selectedDayIndex % dailyPlans.length];

  void selectTargetGroup(String id) {
    _selectedTargetGroup = id;
    notifyListeners();
  }

  void selectHealthGoal(String id) {
    _selectedHealthGoal = id;
    notifyListeners();
  }

  void selectDay(int index) {
    _selectedDayIndex = index;
    notifyListeners();
  }

  /// Gọi Gemini REST API để sinh thực đơn và lời khuyên dinh dưỡng thực tế.
  Future<bool> generatePlan() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_apiKeys.isEmpty) {
        throw const HttpException(
            'Chưa cấu hình GEMINI_API_KEY. Vui lòng cung cấp khóa API.');
      }

      final plan = await _fetchMealPlanFromGemini();
      if (_disposed) return false;

      _currentPlan = plan;
      _selectedDayIndex = 0;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      if (_disposed) return false;
      _isLoading = false;
      _errorMessage = _resolveErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<MealPlan> _fetchMealPlanFromGemini() async {
    final prompt = _buildPrompt(_selectedTargetGroup, _selectedHealthGoal);
    final url = Uri.parse('$_baseUrl/models/$_model:generateContent');
    final payload = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
      }
    });

    final response = await _postWithKeyRotation(url, payload);

    if (response.statusCode != 200) {
      _handleHttpError(response.statusCode, response.body);
    }

    final Map<String, dynamic> body =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final candidates = body['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw const FormatException('Gemini không trả về kết quả nào.');
    }

    final parts = candidates[0]['content']?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw const FormatException('Nội dung phản hồi từ Gemini trống.');
    }

    final rawJsonText = parts
        .where((p) => p is Map && p['thought'] != true)
        .map((p) => (p as Map)['text'] as String? ?? '')
        .join()
        .trim();

    return _parseMealPlan(rawJsonText);
  }

  Future<http.Response> _postWithKeyRotation(Uri url, String payload) async {
    http.Response? last429Response;
    final now = DateTime.now();

    for (final key in _apiKeys) {
      final cooldownUntil = _keyCooldowns[key];
      if (cooldownUntil != null && cooldownUntil.isAfter(now)) {
        continue;
      }

      final response = await _client
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': key,
            },
            body: payload,
          )
          .timeout(const Duration(seconds: 90));

      if (response.statusCode != 429) {
        return response;
      }

      _keyCooldowns[key] =
          DateTime.now().add(_retryDelayFromHeaders(response.headers));
      last429Response = response;
    }

    if (last429Response != null) {
      return last429Response;
    }

    throw const HttpException(
        'Các khóa Gemini đều đang bị giới hạn (429). Vui lòng thử lại sau.');
  }

  Duration _retryDelayFromHeaders(Map<String, String> headers) {
    final retryAfter = headers['retry-after']?.trim();
    if (retryAfter != null && retryAfter.isNotEmpty) {
      final seconds = int.tryParse(retryAfter);
      if (seconds != null && seconds > 0) {
        return Duration(seconds: seconds);
      }
      try {
        final diff = HttpDate.parse(retryAfter).difference(DateTime.now());
        if (!diff.isNegative && diff.inSeconds > 0) return diff;
      } catch (_) {}
    }
    return const Duration(seconds: 60);
  }

  MealPlan _parseMealPlan(String rawJson) {
    String clean = rawJson;
    if (clean.startsWith('```json')) clean = clean.substring(7);
    if (clean.startsWith('```')) clean = clean.substring(3);
    if (clean.endsWith('```')) clean = clean.substring(0, clean.length - 3);
    clean = clean.trim();

    final data = jsonDecode(clean) as Map<String, dynamic>;
    const defaultDays = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ nhật'
    ];
    final rawDays = (data['dailyPlans'] as List?) ?? [];

    final days = List.generate(rawDays.length, (dayIdx) {
      final dayMap = rawDays[dayIdx] as Map<String, dynamic>;
      final rawMeals = (dayMap['meals'] as List?) ?? [];
      final meals = List.generate(rawMeals.length, (mealIdx) {
        final mealMap = rawMeals[mealIdx] as Map<String, dynamic>;
        final dishName =
            (mealMap['dishName'] as String?)?.trim() ?? 'Món ngon mỗi ngày';
        final image = (mealMap['imageAsset'] as String?)?.isNotEmpty == true
            ? mealMap['imageAsset'] as String
            : _resolveImage(dishName);

        return MealItem(
          mealType: (mealMap['mealType'] as String?) ??
              ['Bữa sáng', 'Bữa trưa', 'Bữa tối'][mealIdx % 3],
          dishName: dishName,
          imageAsset: image,
          calories: (mealMap['calories'] as num?)?.round() ?? 450,
          proteinGrams: (mealMap['proteinGrams'] as num?)?.toDouble() ?? 20.0,
          carbsGrams: (mealMap['carbsGrams'] as num?)?.toDouble() ?? 50.0,
          fatGrams: (mealMap['fatGrams'] as num?)?.toDouble() ?? 12.0,
          tip: (mealMap['tip'] as String?) ?? 'Thưởng thức khi còn nóng.',
        );
      });

      final totalCals = (dayMap['totalCalories'] as num?)?.round() ??
          meals.fold<int>(0, (sum, m) => sum + m.calories);

      return DailyPlan(
        dayNumber: (dayMap['dayNumber'] as num?)?.toInt() ?? (dayIdx + 1),
        dayName: (dayMap['dayName'] as String?) ??
            defaultDays[dayIdx % defaultDays.length],
        meals: meals,
        totalCalories: totalCals,
        nutritionSummary: (dayMap['nutritionSummary'] as String?) ??
            'Cung cấp năng lượng hài hoà cho cả ngày.',
      );
    });

    if (days.isEmpty) {
      throw const FormatException('Không tìm thấy kế hoạch ngày hợp lệ trong dữ liệu.');
    }

    return MealPlan(
      targetGroup: (data['targetGroup'] as String?) ?? _selectedTargetGroup,
      healthGoal: (data['healthGoal'] as String?) ?? _selectedHealthGoal,
      totalDays: days.length,
      dailyPlans: days,
      advisorAdvice: (data['advisorAdvice'] as String?) ??
          'Duy trì chế độ ăn uống lành mạnh và uống đủ nước mỗi ngày.',
    );
  }

  String _resolveImage(String dishName) {
    final catalog = RecipeRepository.instance.all;
    if (catalog.isEmpty) return '';
    final lower = dishName.toLowerCase();
    for (final recipe in catalog) {
      if (lower.contains(recipe.title.toLowerCase()) ||
          recipe.title.toLowerCase().contains(lower)) {
        return recipe.imageAsset;
      }
    }
    final index = (dishName.hashCode & 0x7fffffff) % catalog.length;
    return catalog[index].imageAsset;
  }

  String _buildPrompt(String targetGroup, String healthGoal) {
    return '''
Bạn là chuyên gia cố vấn dinh dưỡng ẩm thực Việt Nam cho ứng dụng Bếp Việt AI.
Hãy thiết kế thực đơn chi tiết 7 ngày (từ Thứ Hai đến Chủ nhật) và đưa ra lời khuyên dinh dưỡng thực tế, khoa học.

Thông tin người dùng:
- Nhóm đối tượng: $targetGroup
- Mục tiêu sức khỏe: $healthGoal

Yêu cầu thực đơn:
1. Đủ 7 ngày (Thứ Hai, Thứ Ba, Thứ Tư, Thứ Năm, Thứ Sáu, Thứ Bảy, Chủ nhật).
2. Mỗi ngày có ít nhất 3 bữa: "Bữa sáng", "Bữa trưa", "Bữa tối".
3. Món ăn phong phú, ưu tiên ẩm thực Việt Nam hoặc món quen thuộc, tính toán calo và đạm/carb/béo hợp lý cho nhóm đối tượng.
4. Lời khuyên dinh dưỡng (advisorAdvice) chi tiết, thực tế theo mục tiêu sức khỏe đã chọn.
5. Mỗi bữa ăn kèm mẹo (tip) chế biến hoặc lưu ý sức khỏe ngắn gọn.

Bắt buộc trả về đúng định dạng JSON:
{
  "targetGroup": "$targetGroup",
  "healthGoal": "$healthGoal",
  "advisorAdvice": "Lời khuyên dinh dưỡng thực tế chi tiết...",
  "dailyPlans": [
    {
      "dayNumber": 1,
      "dayName": "Thứ Hai",
      "totalCalories": 1800,
      "nutritionSummary": "Tóm tắt dinh dưỡng...",
      "meals": [
        {
          "mealType": "Bữa sáng",
          "dishName": "Tên món ăn",
          "calories": 450,
          "proteinGrams": 25.0,
          "carbsGrams": 50.0,
          "fatGrams": 12.0,
          "tip": "Mẹo ăn uống hoặc chế biến"
        }
      ]
    }
  ]
}
''';
  }

  void _handleHttpError(int statusCode, String body) {
    String? detail;
    try {
      final err = jsonDecode(body);
      detail = err['error']?['message'] as String?;
    } catch (_) {}

    if (statusCode == 429) {
      throw HttpException(
          detail != null
              ? 'Lỗi 429: $detail'
              : 'Gemini API vượt quá giới hạn lượt gọi hoặc hết hạn mức (429).');
    } else if (statusCode == 401 || statusCode == 403) {
      throw HttpException(
          detail != null
              ? 'Lỗi $statusCode: $detail'
              : 'Khóa API Gemini không hợp lệ hoặc không có quyền truy cập ($statusCode).');
    } else if (statusCode >= 500) {
      throw HttpException(
          detail != null
              ? 'Lỗi $statusCode: $detail'
              : 'Máy chủ Gemini đang gặp sự cố ($statusCode). Vui lòng thử lại sau.');
    }
    throw HttpException(
        detail != null
            ? 'Lỗi $statusCode: $detail'
            : 'Yêu cầu tới Gemini thất bại với mã lỗi HTTP $statusCode.');
  }

  String _resolveErrorMessage(dynamic error) {
    if (error is SocketException || error is http.ClientException) {
      return 'Không thể kết nối đến Gemini. Vui lòng kiểm tra kết nối mạng.';
    }
    if (error is TimeoutException) {
      return 'Yêu cầu tạo thực đơn từ Gemini đã hết thời gian chờ. Vui lòng thử lại.';
    }
    if (error is HttpException) {
      return error.message;
    }
    if (error is FormatException) {
      return error.message;
    }
    return 'Đã xảy ra lỗi khi tạo thực đơn từ Gemini. Vui lòng thử lại sau.';
  }

  MealPlan _buildInitialPlan() {
    final recipes = [...RecipeRepository.instance.all];
    if (_selectedHealthGoal == 'Giảm cân') {
      recipes.sort((a, b) => a.calories.compareTo(b.calories));
    } else if (_selectedHealthGoal == 'Tăng cơ') {
      recipes.sort(
          (a, b) => b.nutrition.proteinGrams.compareTo(a.nutrition.proteinGrams));
    }
    const weekdays = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ nhật'
    ];
    final days = List.generate(7, (day) {
      final meals = List.generate(3, (index) {
        final r =
            recipes.isEmpty ? null : recipes[(day * 3 + index) % recipes.length];
        return MealItem(
          mealType: ['Bữa sáng', 'Bữa trưa', 'Bữa tối'][index],
          dishName: r?.title ?? 'Món ngon mỗi ngày',
          imageAsset: r?.imageAsset ?? '',
          calories: r?.calories ?? 450,
          proteinGrams: r?.nutrition.proteinGrams ?? 20.0,
          carbsGrams: r?.nutrition.carbsGrams ?? 50.0,
          fatGrams: r?.nutrition.fatGrams ?? 12.0,
          tip: r?.description ?? 'Món ăn giàu dinh dưỡng.',
        );
      });
      return DailyPlan(
        dayNumber: day + 1,
        dayName: weekdays[day],
        meals: meals,
        totalCalories: meals.fold<int>(0, (sum, m) => sum + m.calories),
        nutritionSummary: 'Dinh dưỡng ước tính cho một khẩu phần mỗi món.',
      );
    });
    return MealPlan(
      targetGroup: _selectedTargetGroup,
      healthGoal: _selectedHealthGoal,
      totalDays: days.length,
      dailyPlans: days,
      advisorAdvice: 'Thực đơn tham khảo từ Spoonacular.',
    );
  }

  @override
  void dispose() {
    _disposed = true;
    if (_ownsClient) {
      _client.close();
    }
    super.dispose();
  }
}
