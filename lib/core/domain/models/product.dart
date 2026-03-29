class Product {
  // Tags to ignore in search and similarity calculations
  static const _invalidTags = {
    'unknown',
    'other',
    '',
    'en:other',
    'undefined',
    'en:undefined'
  };

  final String id;
  final String name;
  final String brand;
  final String? imageUrl;
  final String? nutriScore;
  final int? novaGroup;
  final List<String> ingredients;
  final List<String> ingredientsTags;
  final List<String> categoryTags;
  final List<String> ciqualTags;
  final String? comparedToCategory;
  final Map<String, double> nutriments;

  /// Returns ciqual tags with invalid values filtered out.
  List<String> get validCiqualTags =>
      ciqualTags.where((t) => !_invalidTags.contains(t.toLowerCase())).toList();

  /// Returns true if this product has incomplete category data in the database.
  /// Products with undefined/unknown categories can't produce relevant recommendations.
  bool get hasIncompleteData {
    final hasInvalidComparedTo = comparedToCategory == null ||
        _invalidTags.contains(comparedToCategory!.toLowerCase());
    final hasNoCiqualTags = validCiqualTags.isEmpty;
    return hasInvalidComparedTo && hasNoCiqualTags;
  }

  const Product({
    required this.id,
    required this.name,
    required this.brand,
    this.imageUrl,
    this.nutriScore,
    this.novaGroup,
    required this.ingredients,
    this.ingredientsTags = const [],
    required this.categoryTags,
    this.ciqualTags = const [],
    this.comparedToCategory,
    this.nutriments = const {},
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['code'] ?? '',
      name: map['product_name'] ?? 'Unknown Product',
      brand: map['brands'] ?? 'Unknown Brand',
      imageUrl: map['image_url'],
      nutriScore: map['nutriscore_grade'],
      novaGroup: map['nova_group'],
      ingredients: _parseIngredients(map['ingredients_text']),
      ingredientsTags: _parseListField(map['ingredients_tags']),
      categoryTags: _parseListField(map['categories_tags']),
      ciqualTags: _parseListField(map['ciqual_food_name_tags']),
      comparedToCategory: map['compared_to_category'],
      nutriments: _parseNutriments(map['nutriments']),
    );
  }

  /// Returns prioritized search terms for finding alternatives.
  /// Falls back through: categoryTags → comparedToCategory → ciqualTags
  List<String> get searchTerms {
    final terms = <String>[];

    // 1. Try category tags (if not just "other")
    final leafCategory = _findLeafCategory(categoryTags);
    if (leafCategory != null && !leafCategory.contains('other')) {
      terms.add(leafCategory);
    }

    // 2. Add compared_to_category
    if (comparedToCategory != null && comparedToCategory!.isNotEmpty) {
      if (!terms.contains(comparedToCategory)) {
        terms.add(comparedToCategory!);
      }
    }

    // 3. Add valid ciqual tags (convert to search-friendly format)
    for (final tag in validCiqualTags) {
      final searchTerm = tag.replaceAll('-', ' ');
      if (!terms.any((t) => t.contains(searchTerm) || searchTerm.contains(t))) {
        terms.add(searchTerm);
      }
    }

    // 4. Last resort: even "other" category
    if (terms.isEmpty && leafCategory != null) {
      terms.add(leafCategory);
    }

    return terms;
  }

  static String? _findLeafCategory(List<String> categoryTags) {
    if (categoryTags.isEmpty) return null;
    return categoryTags.lastWhere(
      (tag) => tag.startsWith('en:'),
      orElse: () => categoryTags.last,
    );
  }

  static List<String> _parseIngredients(dynamic ingredientsText) {
    if (ingredientsText is! String) return [];
    return ingredientsText.split(', ');
  }

  static List<String> _parseListField(dynamic list) {
    if (list is! List) return [];
    return list.map((e) => e.toString()).toList();
  }

  static Map<String, double> _parseNutriments(dynamic nutrimentsMap) {
    if (nutrimentsMap is! Map) return {};

    final result = <String, double>{};
    const keys = [
      'sugars_100g',
      'salt_100g',
      'saturated-fat_100g',
      'fat_100g',
      'cholesterol_100g',
      'fiber_100g',
      'proteins_100g'
    ];

    for (final key in keys) {
      final value = nutrimentsMap[key];
      if (value != null) {
        if (value is num) {
          result[key] = value.toDouble();
        } else if (value is String) {
          final parsed = double.tryParse(value);
          if (parsed != null) result[key] = parsed;
        }
      }
    }
    return result;
  }
}
