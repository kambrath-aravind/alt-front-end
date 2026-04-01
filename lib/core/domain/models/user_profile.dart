enum DietRestriction {
  bloodSugarFocus, // Prioritize low added sugar, low refined carb.
  peanutAllergy, // Must not contain peanuts or tree nuts.
  glutenFree, // Must not contain gluten.
  heartHealth, // Focus on low sodium and healthy fats.
}

extension DietRestrictionExtension on DietRestriction {
  String get displayName {
    switch (this) {
      case DietRestriction.bloodSugarFocus:
        return 'Blood Sugar Focus (Diabetes)';
      case DietRestriction.peanutAllergy:
        return 'Peanut Allergy';
      case DietRestriction.glutenFree:
        return 'Gluten Free';
      case DietRestriction.heartHealth:
        return 'Heart Health';
    }
  }
}

class UserProfile {
  final String id;
  final List<DietRestriction> dietaryPreferences;
  final double searchRadiusMiles;
  final String defaultZipCode;
  final bool hasCompletedOnboarding;

  UserProfile({
    required this.id,
    this.dietaryPreferences = const [],
    this.searchRadiusMiles = 5.0,
    this.defaultZipCode = '',
    this.hasCompletedOnboarding = false,
  });

  UserProfile copyWith({
    String? id,
    List<DietRestriction>? dietaryPreferences,
    double? searchRadiusMiles,
    String? defaultZipCode,
    bool? hasCompletedOnboarding,
  }) {
    return UserProfile(
      id: id ?? this.id,
      dietaryPreferences: dietaryPreferences ?? this.dietaryPreferences,
      searchRadiusMiles: searchRadiusMiles ?? this.searchRadiusMiles,
      defaultZipCode: defaultZipCode ?? this.defaultZipCode,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dietaryPreferences': dietaryPreferences.map((e) => e.name).toList(),
      'searchRadiusMiles': searchRadiusMiles,
      'defaultZipCode': defaultZipCode,
      'hasCompletedOnboarding': hasCompletedOnboarding,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] ?? '',
      dietaryPreferences: (map['dietaryPreferences'] as List<dynamic>?)
              ?.map((e) => DietRestriction.values.firstWhere((d) => d.name == e,
                  orElse: () => DietRestriction.bloodSugarFocus))
              .toList() ??
          [],
      searchRadiusMiles: (map['searchRadiusMiles'] ?? 5.0).toDouble(),
      defaultZipCode: map['defaultZipCode'] ?? '',
      hasCompletedOnboarding: map['hasCompletedOnboarding'] ?? false,
    );
  }
}
