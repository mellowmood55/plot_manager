import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class UtilityRateService {
  UtilityRateService._();

  static final UtilityRateService instance = UtilityRateService._();

  static const String defaultRateKey = 'utility_rate_per_unit';
  static const String rateByUnitTypeKey = 'utility_rate_per_unit_type';

  Future<double> getDefaultRate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(defaultRateKey) ?? 0;
  }

  Future<void> setDefaultRate(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(defaultRateKey, value);
  }

  Future<Map<String, double>> getRateMap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(rateByUnitTypeKey);
    if (raw == null || raw.trim().isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return {};
      }

      final result = <String, double>{};
      for (final entry in decoded.entries) {
        final key = _normalize(entry.key);
        if (key.isEmpty) {
          continue;
        }

        final value = entry.value;
        final rate = value is num ? value.toDouble() : double.tryParse(value.toString());
        if (rate != null && rate >= 0) {
          result[key] = rate;
        }
      }

      return result;
    } catch (_) {
      return {};
    }
  }

  Future<void> setRateForUnitType(String unitType, double rate) async {
    final normalized = _normalize(unitType);
    if (normalized.isEmpty) {
      return;
    }

    final map = await getRateMap();
    map[normalized] = rate;
    await _persistRateMap(map);
  }

  Future<void> removeRateForUnitType(String unitType) async {
    final normalized = _normalize(unitType);
    if (normalized.isEmpty) {
      return;
    }

    final map = await getRateMap();
    map.remove(normalized);
    await _persistRateMap(map);
  }

  Future<double> getRateForUnitType(String? unitType) async {
    final normalized = _normalize(unitType);
    if (normalized.isNotEmpty) {
      final map = await getRateMap();
      final mapped = map[normalized];
      if (mapped != null) {
        return mapped;
      }
    }

    return getDefaultRate();
  }

  String _normalize(String? value) {
    return (value ?? '').trim().toLowerCase();
  }

  Future<void> _persistRateMap(Map<String, double> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(rateByUnitTypeKey, jsonEncode(map));
  }
}
