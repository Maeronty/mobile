-- Calo ƯỚC TÍNH cho cả món (tính từ nguyên liệu × bảng calo), dùng khi món
-- không có dữ liệu dinh dưỡng (recipe_nutritions). 0 = chưa tính được.
ALTER TABLE recipes ADD COLUMN estimated_calories INTEGER NOT NULL DEFAULT 0;
