-- Đánh dấu thời gian nấu là ƯỚC LƯỢNG (tính từ nội dung các bước) hay dữ liệu
-- gốc của nguồn. 0 = dữ liệu gốc (hoặc chưa có), 1 = ước lượng → app hiện "~".
ALTER TABLE recipes ADD COLUMN cook_time_estimated INTEGER NOT NULL DEFAULT 0;
