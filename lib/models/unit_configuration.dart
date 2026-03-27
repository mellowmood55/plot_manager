class UnitConfiguration {
  final String id;
  final String organizationId;
  final String unitTypeName;
  final double defaultRent;
  final int minOccupants;
  final int maxOccupants;

  UnitConfiguration({
    required this.id,
    required this.organizationId,
    required this.unitTypeName,
    required this.defaultRent,
    required this.minOccupants,
    required this.maxOccupants,
  });

  static const Map<String, (int min, int max)> predefinedOccupancyRules = {
    'bedsitter': (1, 1),
    'bed-sitter': (1, 1),
    'studio': (1, 2),
    'one bedroom': (1, 3),
    '1 bedroom': (1, 3),
    'two bedroom': (1, 5),
    '2 bedroom': (1, 5),
  };

  static ({int min, int max}) resolveOccupancyRule(
    String unitTypeName,
    int minOccupants,
    int maxOccupants,
  ) {
    final key = unitTypeName.trim().toLowerCase();
    final predefinedRule = predefinedOccupancyRules[key];

    if (predefinedRule != null) {
      return (min: predefinedRule.$1, max: predefinedRule.$2);
    }

    final safeMin = minOccupants < 1 ? 1 : minOccupants;
    final safeMax = maxOccupants < safeMin ? safeMin : maxOccupants;

    return (min: safeMin, max: safeMax);
  }

  factory UnitConfiguration.fromJson(Map<String, dynamic> json) {
    final minRaw = json['min_occupants'] ?? 1;
    final maxRaw = json['max_occupants'] ?? 1;

    final parsedMin = minRaw is int ? minRaw : int.tryParse(minRaw.toString()) ?? 1;
    final parsedMax = maxRaw is int ? maxRaw : int.tryParse(maxRaw.toString()) ?? 1;
    final resolvedRule = resolveOccupancyRule(
      (json['unit_type_name'] ?? '').toString(),
      parsedMin,
      parsedMax,
    );

    return UnitConfiguration(
      id: json['id'].toString(),
      organizationId: json['organization_id'].toString(),
      unitTypeName: (json['unit_type_name'] ?? '').toString(),
      defaultRent: (json['default_rent'] is num) 
          ? (json['default_rent'] as num).toDouble()
          : double.tryParse(json['default_rent'].toString()) ?? 0.0,
      minOccupants: resolvedRule.min,
      maxOccupants: resolvedRule.max,
    );
  }

  Map<String, dynamic> toJson() {
    final resolvedRule = resolveOccupancyRule(
      unitTypeName,
      minOccupants,
      maxOccupants,
    );

    return {
      'organization_id': organizationId,
      'unit_type_name': unitTypeName,
      'default_rent': defaultRent,
      'min_occupants': resolvedRule.min,
      'max_occupants': resolvedRule.max,
    };
  }
}
