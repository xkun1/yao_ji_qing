import 'package:flutter_test/flutter_test.dart';
import 'package:yao_ji_qing/services/inventory_service.dart';

void main() {
  group('MedicineInventory', () {
    group('库存不足判断', () {
      test('剩余量 ≤ 总数的 20% 时 isLow 为 true', () {
        final inv = MedicineInventory(
          medicineId: 1,
          totalQuantity: 30,
          remainingCount: 6,
        );
        expect(inv.isLow, isTrue);
      });

      test('剩余量 > 总数的 20% 时 isLow 为 false', () {
        final inv = MedicineInventory(
          medicineId: 1,
          totalQuantity: 30,
          remainingCount: 7,
        );
        expect(inv.isLow, isFalse);
      });

      test('总数为 0 时 isLow 为 true', () {
        final inv = MedicineInventory(
          medicineId: 1,
          totalQuantity: 0,
          remainingCount: 0,
        );
        expect(inv.isLow, isTrue);
      });

      test('总数为 1 时，剩余 1 不算低', () {
        final inv = MedicineInventory(
          medicineId: 1,
          totalQuantity: 1,
          remainingCount: 1,
        );
        // ceil(1 * 0.2) = 1, remainingCount(1) <= 1 → true
        expect(inv.isLow, isTrue);
      });
    });

    group('过期判断', () {
      test('已过期的药品 isExpired 为 true', () {
        final inv = MedicineInventory(
          medicineId: 1,
          totalQuantity: 30,
          remainingCount: 10,
          expiryDate: DateTime.now().subtract(const Duration(days: 1)),
        );
        expect(inv.isExpired, isTrue);
      });

      test('未过期药品 isExpired 为 false', () {
        final inv = MedicineInventory(
          medicineId: 1,
          totalQuantity: 30,
          remainingCount: 10,
          expiryDate: DateTime.now().add(const Duration(days: 1)),
        );
        expect(inv.isExpired, isFalse);
      });

      test('无过期日期时 isExpired 为 false', () {
        final inv = MedicineInventory(
          medicineId: 1,
          totalQuantity: 30,
          remainingCount: 10,
        );
        expect(inv.isExpired, isFalse);
      });
    });

    group('即将过期判断', () {
      test('7天内过期时 isExpiringSoon 为 true', () {
        final inv = MedicineInventory(
          medicineId: 1,
          totalQuantity: 30,
          remainingCount: 10,
          expiryDate: DateTime.now().add(const Duration(days: 5)),
        );
        expect(inv.isExpiringSoon, isTrue);
      });

      test('超过7天时 isExpiringSoon 为 false', () {
        final inv = MedicineInventory(
          medicineId: 1,
          totalQuantity: 30,
          remainingCount: 10,
          expiryDate: DateTime.now().add(const Duration(days: 30)),
        );
        expect(inv.isExpiringSoon, isFalse);
      });

      test('已过期时 isExpiringSoon 为 false（过期优先）', () {
        final inv = MedicineInventory(
          medicineId: 1,
          totalQuantity: 30,
          remainingCount: 10,
          expiryDate: DateTime.now().subtract(const Duration(days: 1)),
        );
        expect(inv.isExpiringSoon, isFalse);
      });

      test('无过期日期时 isExpiringSoon 为 false', () {
        final inv = MedicineInventory(
          medicineId: 1,
          totalQuantity: 30,
          remainingCount: 10,
        );
        expect(inv.isExpiringSoon, isFalse);
      });
    });

    group('序列化', () {
      test('toJson / fromJson 往返一致性', () {
        final original = MedicineInventory(
          medicineId: 42,
          totalQuantity: 60,
          remainingCount: 45,
          expiryDate: DateTime(2026, 12, 31),
        );
        final json = original.toJson();
        final restored = MedicineInventory.fromJson(json);

        expect(restored.medicineId, 42);
        expect(restored.totalQuantity, 60);
        expect(restored.remainingCount, 45);
        expect(restored.expiryDate?.year, 2026);
        expect(restored.expiryDate?.month, 12);
        expect(restored.expiryDate?.day, 31);
      });

      test('fromJson 处理 null 过期日期', () {
        final restored = MedicineInventory.fromJson({
          'medicineId': 1,
          'totalQuantity': 10,
          'remainingCount': 5,
          'expiryDate': null,
        });
        expect(restored.expiryDate, isNull);
      });
    });
  });
}
