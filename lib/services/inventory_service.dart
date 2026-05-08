import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MedicineInventory {
  final int medicineId;
  final int totalQuantity;
  int remainingCount;
  DateTime? expiryDate;

  MedicineInventory({
    required this.medicineId,
    required this.totalQuantity,
    required this.remainingCount,
    this.expiryDate,
  });

  bool get isLow => remainingCount <= (totalQuantity * 0.2).ceil();
  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    if (isExpired) return false;
    return expiryDate!.difference(DateTime.now()).inDays <= 7;
  }

  bool get isExpired {
    if (expiryDate == null) return false;
    return expiryDate!.isBefore(DateTime.now());
  }

  Map<String, dynamic> toJson() => {
        'medicineId': medicineId,
        'totalQuantity': totalQuantity,
        'remainingCount': remainingCount,
        'expiryDate': expiryDate?.toIso8601String(),
      };

  factory MedicineInventory.fromJson(Map<String, dynamic> json) {
    return MedicineInventory(
      medicineId: json['medicineId'] as int,
      totalQuantity: json['totalQuantity'] as int,
      remainingCount: json['remainingCount'] as int,
      expiryDate: json['expiryDate'] != null
          ? DateTime.tryParse(json['expiryDate'] as String)
          : null,
    );
  }
}

class InventoryService {
  InventoryService._internal();

  static final InventoryService _instance = InventoryService._internal();

  factory InventoryService() => _instance;

  static const _prefKey = 'medicine_inventory';

  Future<Map<int, MedicineInventory>> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw == null) return {};

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final result = <int, MedicineInventory>{};
      for (final item in list) {
        final inv = MedicineInventory.fromJson(item as Map<String, dynamic>);
        result[inv.medicineId] = inv;
      }
      return result;
    } catch (e) {
      debugPrint('库存数据解析失败: $e');
      return {};
    }
  }

  Future<void> _saveAll(Map<int, MedicineInventory> data) async {
    final prefs = await SharedPreferences.getInstance();
    final list = data.values.map((e) => e.toJson()).toList();
    await prefs.setString(_prefKey, jsonEncode(list));
  }

  Future<MedicineInventory?> get(int medicineId) async {
    final all = await _loadAll();
    return all[medicineId];
  }

  Future<void> save(MedicineInventory inventory) async {
    final all = await _loadAll();
    all[inventory.medicineId] = inventory;
    await _saveAll(all);
  }

  Future<void> delete(int medicineId) async {
    final all = await _loadAll();
    all.remove(medicineId);
    await _saveAll(all);
  }

  Future<void> decrementCount(int medicineId) async {
    final all = await _loadAll();
    final inv = all[medicineId];
    if (inv != null && inv.remainingCount > 0) {
      inv.remainingCount--;
      await _saveAll(all);
    }
  }

  Future<List<MedicineInventory>> getExpiringSoon() async {
    final all = await _loadAll();
    return all.values.where((inv) => inv.isExpiringSoon).toList();
  }

  Future<List<MedicineInventory>> getLowStock() async {
    final all = await _loadAll();
    return all.values.where((inv) => inv.isLow).toList();
  }
}
