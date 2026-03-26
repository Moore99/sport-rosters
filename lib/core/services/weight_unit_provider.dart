import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum WeightUnit { kg, lbs }

class WeightUnitNotifier extends StateNotifier<WeightUnit> {
  WeightUnitNotifier() : super(WeightUnit.kg) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('weight_unit') ?? 'kg';
    state = saved == 'lbs' ? WeightUnit.lbs : WeightUnit.kg;
  }

  Future<void> setUnit(WeightUnit unit) async {
    state = unit;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('weight_unit', unit.name);
  }
}

final weightUnitProvider =
    StateNotifierProvider<WeightUnitNotifier, WeightUnit>(
  (ref) => WeightUnitNotifier(),
);

// ── Conversion helpers ─────────────────────────────────────────────────────────

/// Convert a stored kg value to the display unit.
double toDisplayWeight(double kg, WeightUnit unit) =>
    unit == WeightUnit.lbs ? kg * 2.20462 : kg;

/// Convert a user-entered display value back to kg for storage.
double toStorageKg(double displayValue, WeightUnit unit) =>
    unit == WeightUnit.lbs ? displayValue / 2.20462 : displayValue;

/// Format a stored kg value for display, e.g. "72.5 kg" or "159.8 lbs".
String formatWeight(double kg, WeightUnit unit) {
  final val = toDisplayWeight(kg, unit);
  return '${val.toStringAsFixed(1)} ${unit.name}';
}
