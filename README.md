# MIPS-The-checkers-game

## Cấu trúc tệp mã nguồn Assembly

### `common.asm`
*   **Các hằng số:** Loại quân, Nguyên Tàihơi, cờ variant, mã lỗi.
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

Dưới đây là danh sách chi tiết các hàm cần hiện thực, được phân chia lại theo phương án **cân bằng khối lượng và chuyên môn hóa** cho 3 người (A, B, C).

Mỗi Nguyên Tàió thông số đầu vào (`$a0-$a3`), đầu ra (`$v0-$v1`), nhiệm vụ cụ thể và thứ tự code:

---

### 👤 Minh Toàn: Luật cốt lõi & Tương tác quân cờ (`rules.asm`)
> **Trách nhiệm:** Quyết định một quân cờ đi như thế nào, ăn quân ra sao và ăn liên hoàn.

#### 1. `apply_move` *(Làm đầu tiên)*
* **File:** `rules.asm`
* **Đầu vào:** `$a0` = ô xuất phát (1..32), `$a1` = ô đích (1..32)
* **Đầu ra:** 
  * `$v0` = `1` nếu là nước nhảy ăn quân, `0` nếu là đi thường
  * `$v1` = `1` nếu quân vừa được phong Vua, `0` nếu không
* **Logic thực hiện:**
  1. Lấy quân ở ô `$a0`, chuyển sang ô `$a1`, gán ô `$a0 = EMPTY`.
  2. Kiểm tra xem có phải nước nhảy ăn không (tính khoảng cách hàng $|row_2 - row_1| == 2$).
  3. Nếu là nước nhảy: tìm ô ở giữa $( \frac{row_1+row_2}{2}, \frac{col_1+col_2}{2} )$, chuyển về số ô bằng `rowcol_to_sq`, gán ô đó `= EMPTY`, đặt `$v0 = 1`.
  4. Kiểm tra phong Vua: nếu quân Đen tới hàng `0` $\rightarrow$ đổi thành `BLACK_KING`; nếu quân Đỏ tới hàng `7` $\rightarrow$ đổi thành `RED_KING`, đặt `$v1 = 1`.

#### 2. `is_valid_move` *(Làm thứ hai)*
* **File:** `rules.asm`
* **Đầu vào:** `$a0` = ô xuất phát, `$a1` = ô đích, `$a2` = `chain_only` (1 nếu đang trong chuỗi ăn, 0 nếu lượt bình thường)
* **Đầu ra:** 
  * `$v0` = `1` nếu hợp lệ, `0` nếu không
  * `$v1` = mã lỗi `ERR_*` (xem định nghĩa trong `common.asm`)
* **Logic thực hiện:**
  1. Kiểm tra `$a0`, `$a1` có nằm trong khoảng 1..32 không (`ERR_OUT_OF_RANGE`).
  2. Ô `$a0` có quân không (`ERR_EMPTY`), có phải quân của `current_player` không (`ERR_NOT_OWN`).
  3. Ô `$a1` phải đang trống (`ERR_OCCUPIED`).
  4. Đổi sang hàng/cột, tính $\Delta row = row_2 - row_1$, $\Delta col = col_2 - col_1$:
     * Bắt buộc phải đi chéo: $|\Delta row| == |\Delta col|$.
     * **Nước đi thường ($|\Delta row| == 1$):** Nếu `$a2 == 1` thì báo lỗi `ERR_CHAIN_CAPTURE`. Kiểm tra đúng hướng (quân thường Đen chỉ đi lên $\Delta row = -1$, Đỏ đi xuống $\Delta row = 1$; Vua đi được cả 2 hướng).
     * **Nước nhảy ăn ($|\Delta row| == 2$):** Ô nằm ở giữa phải có quân của đối phương.

#### 3. `can_chain` *(Làm thứ ba)*
* **File:** `rules.asm`
* **Đầu vào:** `$a0` = ô quân cờ vừa nhảy tới (1..32)
* **Đầu ra:** `$v0` = `1` nếu quân này còn ăn tiếp được, `0` nếu hết nước ăn
* **Logic thực hiện:**
  * Từ vị trí `$a0`, kiểm tra 4 hướng chéo cách 2 ô. Nếu có ít nhất 1 hướng có ô đích trống và ô kẹp giữa là quân địch $\rightarrow$ trả về `1`.

---

### 👤 Hữu Thắng: Đồ họa Bitmap & Tìm kiếm nước đi (`display.asm` & `rules.asm`)
> **Trách nhiệm:** Đưa game lên Bitmap Display và xử lý gợi ý nước đi (Highlight).

#### 1. `draw_board_bitmap` *(Làm đầu tiên)*
* **File:** `display.asm`
* **Đầu vào:** `$a0` = `view_player` (0 = nhìn từ phía Đen, 1 = nhìn từ phía Đỏ)
* **Logic thực hiện:**
  1. Duyệt 2 vòng lặp $row = 0..7$ và $col = 0..7$.
  2. Nếu `view_player == 1`, xoay tọa độ: $row' = 7 - row, col' = 7 - col$.
  3. Tính tọa độ pixel unit: $x = col \times 8, y = row \times 8$.
  4. Gọi hàm `bmp_fill_rect` (kích thước $8 \times 8$):
     * Ô trắng: tô màu `COLOR_LIGHT`.
     * Ô tối: tô màu `COLOR_DARK`.
  5. Nếu ô tối có quân cờ: vẽ hình vuông nhỏ bên trong ($6 \times 6$ tại $x+1, y+1$) màu `COLOR_BLACK_PC` hoặc `COLOR_RED_PC`. Nếu là Vua, vẽ tâm màu vàng `COLOR_KING_MARK`.
  6. Kiểm tra `selected_square`: nếu khác `-1` thì gọi `bmp_highlight_moves`.

#### 2. `get_valid_moves` *(Làm thứ hai)*
* **File:** `rules.asm`
* **Đầu vào:** `$a0` = ô cần tìm nước đi (1..32)
* **Đầu ra:** Ghi kết quả vào biến toàn cục:
  * `move_count`: số nước đi hợp lệ tìm được
  * `move_list[]`: mảng các ô đích có thể đi
  * `move_is_capture[]`: đánh dấu ô đó là ăn quân (1) hay đi thường (0)
* **Logic thực hiện:**
  * Lấy loại quân tại `$a0`. Thử kiểm tra các hướng đi chéo (1 bước và 2 bước). Nếu nước đi nào hợp lệ thì lưu ô đích vào `move_list` và tăng `move_count`.

#### 3. `bmp_highlight_moves` *(Làm thứ ba)*
* **File:** `display.asm`
* **Đầu vào:** `$a0` = `view_player`
* **Logic thực hiện:**
  1. Lấy `selected_square`, chuyển sang tọa độ $x, y$ trên bitmap, tô viền/nền màu `COLOR_SELECT`.
  2. Gọi `get_valid_moves(selected_square)`.
  3. Lặp qua `move_list[0 .. move_count-1]`: với mỗi ô đích, tô màu xanh `COLOR_MOVE` lên Bitmap để Nguyên Tàihơi biết ô có thể đi.

#### 4. Hoàn thiện giao diện Console (QoL) *(Làm sau cùng)*
* **File:** `display.asm` (`draw_board_console`)
* **Logic thực hiện:** Thêm nhãn cột `A B C D E F G H` và số hàng `1..8` ở viền ngoài bàn cờ in trên console.

---

### 👤 Nguyên Tài: Luồng Game, Điều kiện thắng & Biến thể (`main.asm` & `rules.asm`)
> **Trách nhiệm:** Điều khiển toàn bộ vòng lặp trò chơi, xử lý lỗi, kiểm tra thắng/thua và các luật nâng cao.

#### 1. In thông báo lỗi chi tiết `ERR_*` *(Làm đầu tiên)*
* **File:** `main.asm` (nhánh `bad_move`)
* **Đầu vào:** `$v1` = mã lỗi trả về từ `is_valid_move`
* **Logic thực hiện:**
  * Dựa vào `$v1` để in ra câu thông báo tương ứng thay vì chỉ in một câu chung chung:
    * `ERR_OUT_OF_RANGE`: *"O ngoai pham vi 1..32!"*
    * `ERR_EMPTY`: *"O xuat phat khong co quan!"*
    * `ERR_NOT_OWN`: *"Khong phai quan cua ban!"*
    * `ERR_OCCUPIED`: *"O dich da co quan!"*
    * `ERR_BAD_DIRECTION`: *"Di sai huong hoac sai khoang cach!"*
    * `ERR_CHAIN_CAPTURE`: *"Dang trong chuoi an, phai nhay an tiep!"*

#### 2. `player_has_any_move` & Hoàn thiện `check_winner` *(Làm thứ hai)*
* **File:** `rules.asm`
* **Logic thực hiện:**
  * `player_has_any_move($a0)`: Duyệt qua 32 ô của bàn cờ. Với mỗi ô có quân của Nguyên Tàihơi `$a0`, gọi hàm `get_valid_moves`. Nếu có bất kỳ ô nào có `move_count > 0` thì trả về `1`. Nếu duyệt hết mà không có nước đi nào thì trả về `0`.
  * `check_winner`:
    1. Đếm số quân Đen và Đỏ trên bàn. Bên nào hết quân ($= 0$) $\rightarrow$ bên kia thắng.
    2. Nếu cả hai còn quân: gọi `player_has_any_move(current_player)`. Nếu người sắp đi bị chặn hết đường đi $\rightarrow$ người đối diện thắng!
    3. Chưa ai thắng trả về `-1`.

#### 3. Tích hợp Xoay bàn cờ & Menu / Restart / Cầu hòa *(Làm thứ ba)*
* **File:** `main.asm`
* **Logic thực hiện:**
  * **Xoay bàn:** Tại nhãn `game_loop:`, truyền `lw $a0, current_player` vào hàm `draw_board` để tự động xoay bàn theo lượt.
  * **Menu Variant:** Đầu hàm `main`, in menu cho phép Nguyên Tàihơi nhập bit chọn: Bắt buộc ăn (`FLAG_FORCE_CAPTURE`), Vua bay (`FLAG_FLYING_KING`), Tốt đi lùi (`FLAG_BACKWARD_MAN`). Lưu vào biến `variant_flags`.
  * **Hỏi Restart:** Tại nhãn `game_over:`, in thông báo hỏi *"Choi lai? (1: Co, 0: Thoat)"*. Nếu chọn 1 thì `j main`.
  * **Cầu hòa:** Cho phép nhập mã đặc biệt (ví dụ `-99`) lúc nhập nước đi để xin hòa (`draw_offer_*`).

#### 4. `player_has_capture` (Biến thể bắt buộc ăn) *(Làm sau cùng)*
* **File:** `rules.asm`
* **Logic thực hiện:** Kiểm tra xem Nguyên hơi hiện tại có bất kỳ quân nào thực hiện được nước nhảy ăn hay không. Dùng để ép buộc Nguyên Tàihơi phải ăn quân nếu bật cờ `FLAG_FORCE_CAPTURE`.

---

### Bảng tổng kết phân công:

| Thành viên | File chính | Danh sách hàm / tính năng phụ trách | Trọng số |
| :--- | :--- | :--- | :---: |
| **Minh Toàn** | `rules.asm` | `apply_move` $\rightarrow$ `is_valid_move` $\rightarrow$ `can_chain` | **~35%** |
| **Hữu Thắng** | `display.asm`<br>`rules.asm` | `draw_board_bitmap` $\rightarrow$ `get_valid_moves` $\rightarrow$ `bmp_highlight_moves` $\rightarrow$ Làm đẹp Console | **~33%** |
| **Nguyên Tài** | `main.asm`<br>`rules.asm` | In mã lỗi `$v1` $\rightarrow$ `player_has_any_move` $\rightarrow$ `check_winner` $\rightarrow$ Menu/Restart/Cầu hòa $\rightarrow$ `player_has_capture` | **~32%** |