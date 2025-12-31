import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  static const String workerUrl =
      'https://caltrac-gemini-api.ismaelhernandez5355.workers.dev';

  /// Analyze food with image (image required)
  static Future<NutritionAnalysis> analyzeFood(
    String base64Image, {
    String mimeType = 'image/jpeg',
    String? additionalContext,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(workerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'image': base64Image,
          'mimeType': mimeType,
          if (additionalContext != null) 'context': additionalContext,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return NutritionAnalysis.fromJson(data);
      } else {
        throw Exception('Failed to analyze image: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error analyzing food: $e');
    }
  }

  /// Analyze food with text only (no image)
  static Future<NutritionAnalysis> analyzeFoodTextOnly(
    String description,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(workerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'textOnly': true, 'context': description}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return NutritionAnalysis.fromJson(data);
      } else {
        throw Exception('Failed to analyze: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error analyzing food: $e');
    }
  }
}

class NutritionAnalysis {
  final String? foodName;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final String? servingSize;
  final String? confidence;
  final String? notes;
  final String? error;

  NutritionAnalysis({
    this.foodName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.servingSize,
    this.confidence,
    this.notes,
    this.error,
  });

  factory NutritionAnalysis.fromJson(Map<String, dynamic> json) {
    return NutritionAnalysis(
      foodName: json['food_name'] as String?,
      calories: (json['calories'] as num?)?.toInt() ?? 0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0,
      servingSize: json['serving_size'] as String?,
      confidence: json['confidence'] as String?,
      notes: json['notes'] as String?,
      error: json['error'] as String?,
    );
  }

  bool get hasError => error != null;

  Map<String, dynamic> toJson() => {
    'food_name': foodName,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'serving_size': servingSize,
    'confidence': confidence,
    'notes': notes,
  };
}
