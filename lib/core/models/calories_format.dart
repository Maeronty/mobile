// =============================================================================
// ĐỊNH DẠNG CALO
// =============================================================================
//
// 0 = không rõ → null để UI ẨN hẳn (không hiện "— kcal").
// `estimated` = true khi server ước tính từ nguyên liệu cho CẢ MÓN (món Việt
// không có dữ liệu dinh dưỡng) → thêm "~".
//
//   formatCalories(170)                  → "170 kcal"
//   formatCalories(680, estimated: true) → "~680 kcal"
// =============================================================================

String? formatCalories(int calories, {bool estimated = false}) {
  if (calories <= 0) return null;
  return '${estimated ? '~' : ''}$calories kcal';
}
