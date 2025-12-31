import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://qzolldddhkeeqvpfbywd.supabase.co';
  static const String supabaseAnonKey =
      'sb_secret_hOU0SP3LgLsfhpS_p2SCqQ_T52xR8g8';

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  static User? get currentUser => client.auth.currentUser;

  static String? get userId => currentUser?.id;

  static bool get isLoggedIn => currentUser != null;

  static Stream<AuthState> get authStateChanges =>
      client.auth.onAuthStateChange;

  // Sign up with email and password (no email verification)
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: null,
    );
    // Auto sign-in after signup (bypass email verification)
    if (response.user != null) {
      return await signIn(email: email, password: password);
    }
    return response;
  }

  // Sign in with email and password
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Sign out
  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  // Reset password
  static Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(email);
  }

  // ============ NUTRITION LOGGING ============

  // Log a food entry
  static Future<void> logFood({
    required String foodName,
    required int calories,
    required double protein,
    required double carbs,
    required double fat,
    String? imageUrl,
    String? notes,
  }) async {
    await client.from('food_logs').insert({
      'user_id': userId,
      'food_name': foodName,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'image_url': imageUrl,
      'notes': notes,
      'logged_at': DateTime.now().toIso8601String(),
    });
  }

  // Get today's food logs
  static Future<List<Map<String, dynamic>>> getTodayLogs() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final response = await client
        .from('food_logs')
        .select()
        .eq('user_id', userId!)
        .gte('logged_at', startOfDay.toIso8601String())
        .lt('logged_at', endOfDay.toIso8601String())
        .order('logged_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // Get logs for a specific date range
  static Future<List<Map<String, dynamic>>> getLogs({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await client
        .from('food_logs')
        .select()
        .eq('user_id', userId!)
        .gte('logged_at', startDate.toIso8601String())
        .lte('logged_at', endDate.toIso8601String())
        .order('logged_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // Get daily totals
  static Future<Map<String, dynamic>> getTodayTotals() async {
    final logs = await getTodayLogs();

    int totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;

    for (final log in logs) {
      totalCalories += (log['calories'] as int?) ?? 0;
      totalProtein += (log['protein'] as num?)?.toDouble() ?? 0;
      totalCarbs += (log['carbs'] as num?)?.toDouble() ?? 0;
      totalFat += (log['fat'] as num?)?.toDouble() ?? 0;
    }

    return {
      'calories': totalCalories,
      'protein': totalProtein,
      'carbs': totalCarbs,
      'fat': totalFat,
      'entries': logs.length,
    };
  }

  // Delete a food log
  static Future<void> deleteLog(String logId) async {
    await client.from('food_logs').delete().eq('id', logId);
  }

  // ============ USER PROFILE ============

  // Get or create user profile
  static Future<Map<String, dynamic>> getUserProfile() async {
    final response = await client
        .from('user_profiles')
        .select()
        .eq('user_id', userId!)
        .maybeSingle();

    if (response == null) {
      // Create default profile
      final newProfile = {
        'user_id': userId,
        'daily_calorie_goal': 2000,
        'daily_protein_goal': 150,
        'daily_carbs_goal': 250,
        'daily_fat_goal': 65,
      };
      await client.from('user_profiles').insert(newProfile);
      return newProfile;
    }

    return response;
  }

  // Update user profile
  static Future<void> updateUserProfile({
    int? calorieGoal,
    double? proteinGoal,
    double? carbsGoal,
    double? fatGoal,
  }) async {
    final updates = <String, dynamic>{};
    if (calorieGoal != null) updates['daily_calorie_goal'] = calorieGoal;
    if (proteinGoal != null) updates['daily_protein_goal'] = proteinGoal;
    if (carbsGoal != null) updates['daily_carbs_goal'] = carbsGoal;
    if (fatGoal != null) updates['daily_fat_goal'] = fatGoal;

    if (updates.isNotEmpty) {
      await client
          .from('user_profiles')
          .update(updates)
          .eq('user_id', userId!);
    }
  }

  // ============ WEIGHT TRACKING ============

  // Log weight entry
  static Future<void> logWeight({
    required double weightLbs,
    String? notes,
    DateTime? date,
  }) async {
    await client.from('weight_logs').insert({
      'user_id': userId,
      'weight_lbs': weightLbs,
      'notes': notes,
      'logged_at': (date ?? DateTime.now()).toIso8601String(),
    });
  }

  // Get weight logs with optional date filter
  static Future<List<Map<String, dynamic>>> getWeightLogs({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var query = client
        .from('weight_logs')
        .select()
        .eq('user_id', userId!);

    if (startDate != null) {
      query = query.gte('logged_at', startDate.toIso8601String());
    }
    if (endDate != null) {
      query = query.lte('logged_at', endDate.toIso8601String());
    }

    final response = await query.order('logged_at', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  // Get latest weight entry
  static Future<Map<String, dynamic>?> getLatestWeight() async {
    final response = await client
        .from('weight_logs')
        .select()
        .eq('user_id', userId!)
        .order('logged_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return response;
  }

  // Delete a weight log
  static Future<void> deleteWeightLog(String logId) async {
    await client.from('weight_logs').delete().eq('id', logId);
  }

  // Update a weight log
  static Future<void> updateWeightLog(String logId, double weightLbs) async {
    await client
        .from('weight_logs')
        .update({'weight_lbs': weightLbs})
        .eq('id', logId);
  }
}
