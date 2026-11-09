# =============================================================================
# CORE: CHUẨN HOÁ CHỮ TIẾNG VIỆT
# =============================================================================
#
# VAI TRÒ
#   Cùng một chữ có dấu có thể được mã hoá theo hai dạng Unicode (dựng sẵn hoặc
#   tổ hợp). Phải đưa về một dạng thì "Thịt bò" gõ từ app mới khớp với dữ liệu.
# =============================================================================

import unicodedata


def normalize_text(value: str) -> str:
    return unicodedata.normalize("NFC", value).strip().casefold()
