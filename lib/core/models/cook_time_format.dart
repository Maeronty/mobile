// =============================================================================
// ĐỊNH DẠNG THỜI GIAN NẤU
// =============================================================================
//
// Dùng chung cho Recipe / RecipeSummary. 0 phút = không rõ → trả null để UI
// ẨN hẳn mục thời gian (không hiện "— phút").
// `estimated` = true khi server ước lượng từ nội dung các bước → thêm "~".
//
//   formatCookTime(45)                   → "45 phút"
//   formatCookTime(70, estimated: true)  → "~1 giờ 10 phút"
//   formatCookTime(240)                  → "4 giờ"
//   formatCookTimeShort(25, estimated: true) → "~25p"
//   formatCookTimeShort(250)             → "4g10"
// =============================================================================

String? formatCookTime(int minutes, {bool estimated = false}) {
  if (minutes <= 0) return null;
  final h = minutes ~/ 60;
  final m = minutes % 60;
  final text = h == 0 ? '$m phút' : (m == 0 ? '$h giờ' : '$h giờ $m phút');
  return estimated ? '~$text' : text;
}

String? formatCookTimeShort(int minutes, {bool estimated = false}) {
  if (minutes <= 0) return null;
  final h = minutes ~/ 60;
  final m = minutes % 60;
  final text = h == 0
      ? '${m}p'
      : (m == 0 ? '${h}g' : '${h}g${m.toString().padLeft(2, '0')}');
  return estimated ? '~$text' : text;
}
