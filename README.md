# MIPS-The-checkers-game

## Cấu trúc tệp mã nguồn Assembly

### `common.asm`
*   **Các hằng số:** Loại quân, người chơi, cờ variant, mã lỗi.
*   **Macro:** `print_str`, `read_int`.
*   **Biến toàn cục:** `board`, `current_player`, `variant_flags`, `move_list`...

### `rules.asm`
*   `init_board`
*   `sq_to_rowcol`
*   `rowcol_to_sq`
*   `get_piece`
*   `set_piece`
*   `piece_owner`

### `display.asm`
*   `draw_board_console`: Đã hỗ trợ xoay bàn khi truyền `$a0 = 1`.
*   `bmp_fill_rect`: Hàm vẽ hình chữ nhật cho bitmap.

### `main.asm`
*   **Vòng lặp game** theo đúng luồng đề bài, bao gồm:
    *   Nhập ô xuất phát và ô đích.
    *   Kiểm tra tính hợp lệ.
    *   Ăn quân.
    *   Chain (ăn liên hoàn).
    *   Đổi lượt.
    *   Thông báo thắng.