# Kịch Bản Kiểm Thử & Phân Công Chạy Demo (CO2008 Checkers)

## 1. Cấu hình MARS chuẩn (bắt buộc trước khi chạy)

- Mở tệp `main.asm` trong MARS.
- **Settings**:
  - Bật `Initialize Program Counter to global 'main' if defined`.
  - Tắt `Assemble all files in directory` (tránh lỗi trùng nhãn với `.include`).
- **Tools → Bitmap Display**:
  - Unit Width: `2` | Unit Height: `2`
  - Display Width: `512` | Display Height: `512`
  - Base address: `0x10040000 (heap)`
  - Nhấn **Connect to MIPS** trước khi bấm **Assemble** và **Run**.

## 2. Chi tiết từng kịch bản

### Kịch bản 1 — Chức năng cơ bản, báo lỗi, highlight, xoay bàn và ăn 1 quân
- **Phủ ID:** `B01`, `B02`, `B03`, `B04`, `B05`, `B06`, `E01`, `E02`, `E03`, `E10`
- **Cấu hình menu khởi đầu:** `0`, `0`, `0` (tắt cả 3 biến thể)

| Bước | Lượt | Nhập trên Console | Kết quả mong đợi (Console & Bitmap) | Ảnh cần chụp |
| :--- | :--- | :--- | :--- | :--- |
| 1 | Đen | *(chỉ quan sát)* | 12 Đỏ (`1–12`), 12 Đen (`21–32`), giữa trống (`13–20`), mũi tên **đen** ở góc dưới phải (`B01`, `E01`). | `img_01_init.png` |
| 2 | Đen | `abc` *(hoặc Enter trống)* | In `Invalid input! Please enter an integer:`, chương trình không dừng (`E10`). | — |
| 3 | Đen | `33` → `14` → `9` → `25` | Lần lượt báo: ngoài phạm vi (`B03`), ô trống (`B04`), không phải quân mình (`B04`), quân không có nước đi. | `img_02_errors.png` |
| 4 | Đen | `22` → `13` → `-1` | Ô `22` xanh dương, `17` & `18` xanh lá (`E03`); nhập `13` báo sai hướng (`B05`); nhập `-1` bỏ chọn. | `img_03_highlight_move.png` |
| 5 | Đen | `22` → `18` | Quân Đen đi tới `18` (`B02`); bàn cờ xoay 180° sang góc nhìn Đỏ, mũi tên góc dưới phải đổi màu **đỏ** (`E02`). | `img_04_rotate_red.png` |
| 6 | Đỏ | `9` → `14` | Quân Đỏ tiến tới `14`, sát cạnh quân Đen ở `18`. | — |
| 7 | Đen | `18` → `9` | Khi chọn `18`, ô `9` tô **vàng** (nước ăn), ô `15` tô xanh lá (`E03`); nhập `9` ăn quân Đỏ ở `14` (`B06`). | `img_05_capture.png` |

### Kịch bản 2 — Ăn liên hoàn (Chain), Phong Vua và Vua bay
- **Phủ ID:** `B07`, `B08`, `E03`, `E08`
- **Cấu hình menu khởi đầu:** `0`, `1`, `0` (bật **Flying kings**; dùng `0, 0, 0` nếu chỉ muốn test cơ bản)

| Lượt | Bên đi | Chuỗi nhập (`start` → `land`) | Ghi chú / Kết quả mong đợi |
| :--- | :--- | :--- | :--- |
| 1 | Đen | `24` → `20` | Mở đường |
| 2 | Đỏ | `10` → `15` | Làm trống ô `10` |
| 3 | Đen | `23` → `19` | Nước chờ |
| 4 | Đỏ | `6` → `10` | Làm trống ô `6` |
| 5 | Đen | `22` → `18` | Đưa quân Đen vào vị trí chuẩn bị ăn đôi |
| 6 | Đỏ | `2` → `6` | Làm trống ô `2`, đặt quân Đỏ tại `6` |
| 7 | Đen | `21` → `17` | Nước chờ |
| 8 | Đỏ | `9` → `14` | Làm trống ô `9`, đặt quân Đỏ tại `14` |
| 9 | Đen | `18` → `9` → *(chain)* `2` | Sau `18 → 9`: bật `hl_capture_only`, **chỉ tô vàng ô `2`**, in `Chaining possible.` (`B07`, `E03`). Nhập `2`: ăn tiếp quân ở `6` và **phong Vua Đen** (`B`, dấu vàng) (`B08`). |
| 10 | Đỏ | `12` → `16` | Đi 1 nước bất kỳ |
| 11 | Đen | Chọn `2` *(quan sát)* | Vua Đen bay tô sáng dọc cả đường chéo nhiều ô (`6`, `9`, `13`) (`E08`). |

- **Ảnh cần chụp:** `img_06_chain_highlight.png` (sau nước `18 → 9`) và `img_07_king_flying.png` (sau khi phong Vua & chọn ô `2`).

### Kịch bản 3 — Bắt buộc ăn (`FLAG_FORCE_CAPTURE`)
- **Phủ ID:** `E07`
- **Cấu hình menu khởi đầu:** `1`, `0`, `0` (bật **Force capture**)

| Bước | Lượt | Nhập trên Console | Kết quả mong đợi |
| :--- | :--- | :--- | :--- |
| 1 | Đen | `22` → `18` | Nước đi thường bình thường |
| 2 | Đỏ | `9` → `14` | Tạo thế bắt buộc ăn cho Đen (`18 → 9`) |
| 3 | Đen | `21` | Bị từ chối vì không có nước ăn khi đang có quân khác ăn được |
| 4 | Đen | `18` → `15` | Chỉ ô `9` (màu vàng) được highlight; nhập `15` báo `Error: Forced capture is in effect!` |
| 5 | Đen | `9` | Thực hiện ăn quân hợp lệ, chuyển lượt |

### Kịch bản 4 — Quân thường đi lùi, Đề nghị hòa và Chơi lại
- **Phủ ID:** `E09`, `E05`, `E06`
- **Cấu hình menu khởi đầu:** `0`, `0`, `1` (bật **Pawns move/capture backward**)

| Bước | Lượt | Nhập trên Console | Kết quả mong đợi |
| :--- | :--- | :--- | :--- |
| 1 | Đen | `22` → `18` | Đen tiến lên `18` |
| 2 | Đỏ | `9` → `13` | Đỏ đi thường |
| 3 | Đen | `18` → `22` | Chọn `18` thấy cả ô `22` phía sau tô xanh lá; nhập `22` đi lùi hợp lệ (`E09`) |
| 4 | Đỏ | `0` → `13` → `17` | Nhập `0` ghi nhận đề nghị hòa (chưa đổi lượt), sau đó Đỏ đi `13 → 17` (`E05`) |
| 5 | Đen | `0` | Console hiện `Opponent offers a draw...`; nhập `0` chấp nhận → in `Draw agreed. The game is a draw!` (`E05`) |
| 6 | Hệ thống | `1` | Tại `Play again? (1=Yes, 0=Exit):`, nhập `1` → reset toàn bộ bàn cờ, biến trạng thái và quay lại Menu (`E06`) |

- **Ảnh cần chụp:** `img_08_draw_restart.png` (Console hiển thị hòa và quay về menu chơi lại).

### Kịch bản 5 — Kết thúc ván: Hết quân & Bị chặn hết nước đi
- **Phủ ID:** `B09`, `E04`
- **Cách thực hiện nhanh:** Tạm sửa `init_board` trong `rules.asm` để xếp thế cờ mẫu (nhớ khôi phục `init_board` gốc sau khi chụp ảnh xong).

| Ca kiểm thử | Thế cờ xếp trong `init_board` | Thao tác chạy | Kết quả mong đợi |
| :--- | :--- | :--- | :--- |
| `B09` (Hết quân) | Toàn bộ ô `EMPTY`, chỉ đặt `BLACK_MAN` ở ô `18` và `RED_MAN` ở ô `14` | Menu `0, 0, 0` → Đen nhập `18` → `9` | Ăn quân cuối của Đỏ, in ngay `Black wins!` và hỏi `Play again?` |
| `E04` (Bị chặn) | Theo **Figure 9** đề bài: `BLACK_KING` ở `1`, `BLACK_MAN` ở `6`, `RED_MAN` ở `5` & `10`, `RED_KING` ở `2` | Menu `0, 0, 0` → vừa vào lượt Đen | Đen còn 2 quân nhưng 0 nước đi hợp lệ → báo ngay `Red wins!` |

- **Ảnh cần chụp:** `img_09_win_blocked.png` (Bitmap + Console báo thắng do bị chặn).

## 3. Checklist ảnh chèn vào Chương 5 báo cáo

- [ ] `img_01_init.png` — Khởi tạo bàn cờ + mũi tên đen góc dưới phải (`B01`, `E01`)
- [ ] `img_03_highlight_move.png` — Highlight ô đang chọn & nước đi thường (`E03`)
- [ ] `img_04_rotate_red.png` — Bàn cờ xoay 180° lượt Đỏ + mũi tên đỏ góc dưới phải (`E02`, mục `4.1.4`)
- [ ] `img_06_chain_highlight.png` — Ăn liên hoàn với `hl_capture_only` (`B07`, `E03`)
- [ ] `img_07_king_flying.png` — Phong Vua & Vua bay (`B08`, `E08`)
- [ ] `img_09_win_blocked.png` — Thắng do bị chặn (`E04`)
