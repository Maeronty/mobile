// =============================================================================
// CHUẨN HOÁ NGUYÊN LIỆU (dữ liệu cào từ Món Ngon Mỗi Ngày)
// =============================================================================
//
// VẤN ĐỀ CỦA DỮ LIỆU GỐC (≈ 530/1.821 món Việt)
//   1. Dòng "nhóm" bị lưu như một nguyên liệu, định lượng 0:
//        "Gia vị: Xốt Takoyaki (mua tokyo shop), dầu ăn"
//        "DỤNG CỤ: khuôn làm Takoyaki, que xiên tre hoặc inox, cọ phết dầu"
//   2. Ghi chú bị dính vào đơn vị → chữ dài tràn bên phải dòng:
//        unit = "gói nhỏ xíu (mua ở shop hachi hachi/đồ Nhật)"
//        unit = "trái nhỏ, chọn vỏ xanh đậm"
//
// FLOW (`normalizeIngredients`) — chạy khi đọc JSON, UI chỉ việc hiển thị
//   1. Dòng định lượng 0 dạng "<Nhãn>: a, b, c" → tách thành từng nguyên liệu
//      a, b, c có `group` = Nhãn (viết hoa chữ đầu: "ĂN KÈM" → "Ăn kèm").
//      Chỉ tách ở dấu phẩy NGOÀI ngoặc: "Xốt (mua tokyo shop), dầu ăn" → 2 món.
//   2. Đơn vị có "(...)" → phần trong ngoặc chuyển sang `note`.
//   3. Đơn vị vẫn dài (> 12 ký tự) và có dấu phẩy → phần sau dấu phẩy đầu tiên
//      chuyển sang `note` ("trái nhỏ, chọn vỏ xanh đậm" → "trái nhỏ" + ghi chú).
//   4. Không bịa thêm gì: chỉ tách/chuyển chỗ chữ có sẵn, giữ nguyên thứ tự.
// =============================================================================

import 'recipe.dart';

/// Nhãn nhóm: ngắn, không chứa chữ số (tránh nhầm "Tỉ lệ 1:2").
final RegExp _groupLine = RegExp(r'^([^:\d]{2,40}?)\s*:\s*(.*)$');

const int _maxUnitLength = 12;

List<IngredientItem> normalizeIngredients(Iterable<IngredientItem> raw) {
  final result = <IngredientItem>[];
  for (final item in raw) {
    final match = item.amount <= 0
        ? _groupLine.firstMatch(item.name.trim())
        : null;
    if (match != null) {
      final group = _sentenceCase(match.group(1)!.trim());
      for (final part in _splitOutsideParens(match.group(2)!)) {
        result.add(
          IngredientItem(
            name: _capitalize(part),
            amount: 0,
            unit: '',
            group: group,
          ),
        );
      }
      continue;
    }
    result.add(_cleanUnit(item));
  }
  return result;
}

IngredientItem _cleanUnit(IngredientItem item) {
  var unit = item.unit.trim();
  final notes = <String>[
    if (item.note != null && item.note!.trim().isNotEmpty) item.note!.trim(),
  ];

  final paren = unit.indexOf('(');
  if (paren >= 0) {
    final inside = unit
        .substring(paren + 1)
        .replaceAll(RegExp(r'\)\s*$'), '')
        .trim();
    if (inside.isNotEmpty) notes.add(inside);
    unit = unit.substring(0, paren).trim();
  }

  final comma = unit.indexOf(',');
  if (unit.length > _maxUnitLength && comma > 0) {
    final rest = unit.substring(comma + 1).trim();
    if (rest.isNotEmpty) notes.add(rest);
    unit = unit.substring(0, comma).trim();
  }

  return IngredientItem(
    name: item.name,
    amount: item.amount,
    unit: unit,
    note: notes.isEmpty ? null : notes.join('; '),
    group: item.group,
  );
}

/// "a (x, y), b, c" → ["a (x, y)", "b", "c"].
List<String> _splitOutsideParens(String text) {
  final parts = <String>[];
  final buf = StringBuffer();
  var depth = 0;
  for (final ch in text.split('')) {
    if (ch == '(') depth++;
    if (ch == ')' && depth > 0) depth--;
    if (ch == ',' && depth == 0) {
      parts.add(buf.toString());
      buf.clear();
    } else {
      buf.write(ch);
    }
  }
  parts.add(buf.toString());
  return [
    for (final p in parts)
      if (p.trim().isNotEmpty) p.trim(),
  ];
}

/// "ĂN KÈM" → "Ăn kèm"; "Gia vị" giữ nguyên.
String _sentenceCase(String s) =>
    s == s.toUpperCase() ? _capitalize(s.toLowerCase()) : _capitalize(s);

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
