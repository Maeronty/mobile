// Test chuẩn hoá nguyên liệu cào từ Món Ngon Mỗi Ngày — dữ liệu lấy đúng từ
// món "Bánh Bạch Tuộc Takoyaki" (id 1000015) và vài món lỗi tương tự.

import 'package:flutter_test/flutter_test.dart';
import 'package:tomato_food_tip/core/models/ingredient_normalizer.dart';
import 'package:tomato_food_tip/core/models/recipe.dart';

IngredientItem ing(String name, double amount, String unit) => IngredientItem(name: name, amount: amount, unit: unit);

void main() {
  test('Takoyaki: dòng nhóm tách thành nguyên liệu có group, đơn vị dài tách ghi chú', () {
    final result = normalizeIngredients([
      ing('Bạch tuộc', 150, 'g'),
      ing('Cá ngừ khô bào', 1, 'gói nhỏ xíu (mua ở shop hachi hachi/đồ Nhật)'),
      ing('DỤNG CỤ: khuôn làm Takoyaki (shop bán đồ làm bánh), que xiên tre hoặc inox, cọ phết dầu', 0, ''),
      ing('ĂN KÈM: Bột rong biển', 0, ''),
      ing('Gia vị: Xốt Takoyaki (mua tokyo shop), dầu ăn', 0, ''),
    ]);

    expect(result.map((i) => i.name), [
      'Bạch tuộc',
      'Cá ngừ khô bào',
      'Khuôn làm Takoyaki (shop bán đồ làm bánh)',
      'Que xiên tre hoặc inox',
      'Cọ phết dầu',
      'Bột rong biển',
      'Xốt Takoyaki (mua tokyo shop)',
      'Dầu ăn',
    ]);
    expect(result.map((i) => i.group), [null, null, 'Dụng cụ', 'Dụng cụ', 'Dụng cụ', 'Ăn kèm', 'Gia vị', 'Gia vị']);

    expect(result[1].unit, 'gói nhỏ xíu');
    expect(result[1].note, 'mua ở shop hachi hachi/đồ Nhật');
    expect(result[0].unit, 'g');
    expect(result[0].note, isNull);
  });

  test('đơn vị dài có dấu phẩy → phần sau dấu phẩy thành ghi chú', () {
    final r = normalizeIngredients([ing('Bầu sao', 1, 'trái nhỏ, chọn vỏ xanh đậm')]).single;
    expect(r.unit, 'trái nhỏ');
    expect(r.note, 'chọn vỏ xanh đậm');
  });

  test('đơn vị ngắn có dấu phẩy và nguyên liệu có định lượng giữ nguyên', () {
    final r = normalizeIngredients([ing('Muối', 1, 'g, ít'), ing('Tỉ lệ: 1 phần', 2, 'chén')]);
    expect(r[0].unit, 'g, ít');
    expect(r[1].name, 'Tỉ lệ: 1 phần');
    expect(r[1].group, isNull);
  });
}
