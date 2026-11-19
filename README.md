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

# Phân Công Nhiệm Vụ
*(Đã recheck & cập nhật — v3, kiểm tra kỹ bằng simulation)*

> [!IMPORTANT]
> **Nguyên tắc vàng:** Mỗi người code xong phần mình là merge ngay. STUB sẵn trong code đảm bảo game không crash khi phần người khác chưa xong. Thứ tự trong mỗi nhóm **bắt buộc phải theo** vì có phụ thuộc dữ liệu.

---

## Hằng số & Quy ước (đọc TRƯỚC khi code — nguồn: `common.asm` + simulation)

| Hằng số | Giá trị | Ý nghĩa |
|---|---|---|
| `EMPTY` | 0 | Ô trống |
| `BLACK_MAN` | 1 | Quân thường Đen |
| `BLACK_KING` | 2 | Vua Đen |
| `RED_MAN` | 3 | Quân thường Đỏ |
| `RED_KING` | 4 | Vua Đỏ |
| `PLAYER_BLACK` | **0** | Người chơi Đen |
| `PLAYER_RED` | **1** | Người chơi Đỏ |
| `FLAG_FORCE_CAPTURE` | 1 | Bit 0 |
| `FLAG_FLYING_KING` | 2 | Bit 1 |
| `FLAG_BACKWARD_MAN` | 4 | Bit 2 |
| `ERR_NONE` | 0 | Hợp lệ |
| `ERR_OUT_OF_RANGE` | 1 | Ô ngoài 1–32 |
| `ERR_EMPTY` | 2 | Ô xuất phát trống |
| `ERR_NOT_OWN` | 3 | Quân không phải của mình |
| `ERR_OCCUPIED` | 4 | Ô đích đã có quân |
| `ERR_BAD_DIRECTION` | 5 | Sai hướng/khoảng cách |
| `ERR_MUST_CAPTURE` | 6 | Bắt buộc phải ăn quân |
| `ERR_CHAIN_CAPTURE` | 7 | Phải nhảy ăn tiếp |
| `MAX_MOVES` | 16 | Tối đa 16 nước trong `move_list` |

---

### Bố cục bàn cờ (đã xác nhận bằng simulation)

```
Hàng 0 (trên cùng): ô 1–4    ← Quân ĐỎ xuất phát (hàng 0–2, ô 1–12)
Hàng 1:             ô 5–8
Hàng 2:             ô 9–12
Hàng 3:             ô 13–16   ← 8 ô trống giữa sân
Hàng 4:             ô 17–20
Hàng 5:             ô 21–24   ← Quân ĐEN xuất phát (hàng 5–7, ô 21–32)
Hàng 6:             ô 25–28
Hàng 7 (dưới cùng): ô 29–32
```

- **Quân Đen** (`PLAYER_BLACK = 0`): đi **LÊN** (`Δrow = -1`). Phong Vua khi đến **hàng 0**.
- **Quân Đỏ** (`PLAYER_RED = 1`): đi **XUỐNG** (`Δrow = +1`). Phong Vua khi đến **hàng 7**.
- **Ô hợp lệ** (ô tối, ô chơi được): luôn có `(row + col) % 2 == 1` ← **đã xác nhận bằng simulation tất cả 32 ô**.
- `sq_to_rowcol(sq)` → `$v0 = row`, `$v1 = col`.
- `rowcol_to_sq(row, col)` → `$v0 = ô (1–32)` hoặc `0` nếu không hợp lệ.

---

### Quy ước `move_list` (đọc kỹ — dùng **word**, không phải byte)

Mỗi phần tử là **1 word (4 byte)**. Phần tử thứ `i` ở **byte offset `i * 4`** từ địa chỉ nhãn:
```asm
# Ghi vào move_list[count]:
lw   $t5, move_count
sll  $t6, $t5, 2            # offset = count * 4
la   $t7, move_list
addu $t7, $t7, $t6
sw   $reg_sq, 0($t7)        # move_list[count] = sq_dich

la   $t7, move_is_capture
addu $t7, $t7, $t6
sw   $reg_cap, 0($t7)       # move_is_capture[count] = 0 hoặc 1

addiu $t5, $t5, 1
sw   $t5, move_count

# Đọc move_list[i]:
sll  $t0, $reg_i, 2
la   $t1, move_list
addu $t1, $t1, $t0
lw   $reg_sq, 0($t1)
```

---

## Thứ tự làm việc (Roadmap)

```
GĐ 0 — ĐÃ CÓ SẴN, không được sửa:
       init_board, sq_to_rowcol, rowcol_to_sq,
       get_piece, set_piece, piece_owner,
       draw_board_console, bmp_fill_rect, draw_board (wrapper)

GĐ 1 — Làm SONG SONG (ba người làm cùng lúc, không phụ thuộc nhau):
       A.1 apply_move          (Người A)
       A.2 is_valid_move       (Người A)   ← test sau A.1
       A.3 can_chain           (Người A)   ← test sau A.1
       B.1 draw_board_bitmap   (Người B)   ← hoàn toàn độc lập
       C.1 main.asm fixes      (Người C)   ← hoàn toàn độc lập

GĐ 2 — Sau khi GĐ1 merge xong (cần A.1–A.3 đúng để test đầy đủ):
       B.2 get_valid_moves     (Người B)
       B.3 bmp_highlight_moves (Người B)   ← cần B.2
       C.2 player_has_any_move (Người C)   ← cần B.2
           check_winner        (Người C)   ← cần C.2

GĐ 3 — Sau khi GĐ2 merge xong:
       C.3 Menu Variant + Restart  (Người C)

GĐ 4 — Điểm cộng:
       A.4 FLAG_FLYING_KING    (Người A)   ← cần B.2
       A.4 FLAG_BACKWARD_MAN  (Người A)   ← cần A.2, B.2
       C.4 player_has_capture  (Người C)   ← cần B.2
       B.4 Làm đẹp Console     (Người B)   ← độc lập
```

---

## 👤 NGƯỜI A — Logic di chuyển & Ăn quân (`rules.asm`)

### A.1 — `apply_move` ⭐ *(Làm đầu tiên)*
**File:** `rules.asm` | **Xóa toàn bộ STUB và viết lại**

| | |
|---|---|
| **Đầu vào** | `$a0` = ô xuất phát (1–32), `$a1` = ô đích (1–32) |
| **Đầu ra** | `$v0` = 1 nếu ăn quân / 0 nếu đi thường |
| | `$v1` = 1 nếu vừa phong Vua / 0 nếu không |
| **Stack** | `addiu $sp, $sp, -24` / lưu `$ra, $s4, $s3, $s2, $s1, $s0` |

> [!WARNING]
> Cần lưu **6 thanh ghi** (`$s0`–`$s4` + `$ra`) = **24 byte stack**. Sai số này gây stack overflow hoặc crash.

**Các bước (theo thứ tự thực hiện trong MIPS):**
```
Bước 1: Lưu tham số vào $s trước khi gọi jal
   $s0 = $a0  (from_sq)
   $s1 = $a1  (to_sq)

Bước 2: Lấy và di chuyển quân
   get_piece($s0) → $v0 = piece_type → $s2 = $v0
   set_piece($s1, $s2)         ← đặt quân vào ô đích
   set_piece($s0, EMPTY)       ← xóa ô xuất phát

Bước 3: Lấy tọa độ từ và đến
   sq_to_rowcol($s0) → $s3=row1, $s4=col1
   sq_to_rowcol($s1) → $t0=row2, $t1=col2
   dr = row2 - row1 = $t0 - $s3
   dc = col2 - col1 = $t1 - $s4

Bước 4: Kiểm tra nước nhảy ăn
   abs(dr) == 2?
   Nếu có: mid_row = $s3 + dr/2,  mid_col = $s4 + dc/2
           rowcol_to_sq(mid_row, mid_col) → $v0 = mid_sq
           set_piece(mid_sq, EMPTY)       ← xóa quân bị ăn
           $v0 = 1
   Nếu không: $v0 = 0

Bước 5: Phong Vua (dùng $s2=piece, $s1=to_sq)
   sq_to_rowcol($s1) → row_dest = $v0
   Nếu $s2==BLACK_MAN && row_dest==0: set_piece($s1, BLACK_KING), $v1=1
   Nếu $s2==RED_MAN   && row_dest==7: set_piece($s1, RED_KING),   $v1=1
   Mặc định: $v1 = 0
```

> [!NOTE]
> STUB hiện tại đã di chuyển quân (bước 2) nhưng **bỏ qua bước 4 và 5**. Phải thêm bước 3→5, không xóa bước 2.

---

### A.2 — `is_valid_move` *(Làm sau A.1)*
**File:** `rules.asm` | **Xóa STUB `li $v0, 1`**

| | |
|---|---|
| **Đầu vào** | `$a0` = ô xuất phát, `$a1` = ô đích, `$a2` = `chain_only` (0/1) |
| **Đầu ra** | `$v0` = 1 hợp lệ / 0 không hợp lệ; `$v1` = mã lỗi `ERR_*` |
| **Stack** | `addiu $sp, $sp, -24` / lưu `$ra, $s4, $s3, $s2, $s1, $s0` |

**Kiểm tra theo thứ tự (sai → set `$v0=0, $v1=ERR_*`, `jr $ra` ngay):**

| Bước | Điều kiện cần thỏa | Lỗi nếu sai |
|---|---|---|
| 1 | `1 ≤ $a0 ≤ 32` **VÀ** `1 ≤ $a1 ≤ 32` | `ERR_OUT_OF_RANGE` |
| 2 | `get_piece($a0) != EMPTY` → lưu piece vào `$s2` | `ERR_EMPTY` |
| 3 | `piece_owner($s2) == current_player` | `ERR_NOT_OWN` |
| 4 | `get_piece($a1) == EMPTY` | `ERR_OCCUPIED` |
| 5 | Lấy tọa độ: `sq_to_rowcol($a0)` → `$s3=row1, $s4=col1`; `sq_to_rowcol($a1)` → `$t0=row2, $t1=col2` | — |
| 6 | `dr = row2-row1`, `dc = col2-col1`. Phải `abs(dr)==abs(dc)` (đi chéo) | `ERR_BAD_DIRECTION` |
| 7a | Nếu `abs(dr)==1` và `$a2==1` (đang chain) | `ERR_CHAIN_CAPTURE` |
| 7b | Nếu `abs(dr)==1`: quân thường Đen cần `dr==-1`; quân thường Đỏ cần `dr==+1`; Vua: cả 2 OK | `ERR_BAD_DIRECTION` |
| 8 | Nếu `abs(dr)==2`: ô giữa phải có quân đối phương | `ERR_BAD_DIRECTION` |
| 9 | Nếu `abs(dr) > 2` hoặc `abs(dr) == 0` | `ERR_BAD_DIRECTION` |
| ✅ | Qua hết: `$v0=1`, `$v1=ERR_NONE` | — |

> [!NOTE]
> Chưa kiểm tra `ERR_MUST_CAPTURE` (để comment `# TODO Phase4: FLAG_FORCE_CAPTURE` sau bước 4). Logic ép ăn được xử lý trong `get_valid_moves` (B.2).

---

### A.3 — `can_chain` *(Làm sau A.2)*
**File:** `rules.asm` | **Xóa STUB `li $v0, 0`**

| | |
|---|---|
| **Đầu vào** | `$a0` = ô quân vừa nhảy tới (1–32) |
| **Đầu ra** | `$v0` = 1 còn ăn tiếp được / 0 hết |
| **Stack** | `addiu $sp, $sp, -16` / lưu `$ra, $s2, $s1, $s0` |

**Logic:**
```
$s0 = $a0 (ô hiện tại)
get_piece($s0) → $s1 = loại quân
sq_to_rowcol($s0) → $s2=row, $t_=col (lưu col vào $t9 hoặc tính lại mỗi lần)

Hướng thử:
  BLACK_MAN: (-2,-2), (-2,+2)         # chỉ tiến lên
  RED_MAN:   (+2,-2), (+2,+2)         # chỉ tiến xuống
  BLACK_KING, RED_KING: cả 4 hướng

Mỗi hướng (dr, dc):
  mid_sq  = rowcol_to_sq(row + dr/2, col + dc/2)
  dest_sq = rowcol_to_sq(row + dr,   col + dc)
  Nếu mid_sq > 0 AND dest_sq > 0:
    get_piece(mid_sq)  → phải có quân đối phương (piece_owner != current_player AND != -1)
    get_piece(dest_sq) → phải == EMPTY
    Nếu cả 2 thỏa: $v0 = 1, jr $ra

Hết tất cả hướng: $v0 = 0
```

> [!WARNING]
> `can_chain` **không dùng** `move_list`/`move_count` — tự tính trực tiếp trên bàn cờ. Lý do: để tránh làm mất kết quả `move_list` đang dùng bởi hàm khác.

---

### A.4 — Hỗ trợ Variant *(Giai đoạn 4 — sau B.2 merge)*
**File:** `rules.asm` (mở rộng vào hàm B.2 và A.2 đã có)

| Variant | Hằng | Chỗ sửa | Chi tiết |
|---|---|---|---|
| **Vua Bay** | `FLAG_FLYING_KING` (bit 1) | `get_valid_moves` | Nếu Vua và cờ bật: thay vì chỉ thử 1 ô, duyệt toàn đường chéo đến khi gặp cản. Gặp quân địch + ô sau trống → tất cả ô trống sau quân địch là ô đích hợp lệ. |
| **Tốt đi lùi** | `FLAG_BACKWARD_MAN` (bit 2) | `get_valid_moves` + `is_valid_move` A.2 | Thêm 2 hướng lui cho quân thường. Trong `is_valid_move`: bỏ kiểm tra hướng 1 chiều ở bước 7b khi cờ bật. |

Cách đọc cờ:
```asm
lw   $t0, variant_flags
andi $t0, $t0, FLAG_FLYING_KING    # 2
bnez $t0, nhanh_vua_bay
```

---

## 👤 NGƯỜI B — Đồ họa Bitmap + `get_valid_moves` (`display.asm` + `rules.asm`)

### B.1 — `draw_board_bitmap` ⭐ *(Làm đầu tiên — độc lập)*
**File:** `display.asm` | **Xóa STUB `jr $ra`**

| | |
|---|---|
| **Đầu vào** | `$a0` = `view_player` (0 = nhìn từ Đen, 1 = nhìn từ Đỏ) |
| **Stack** | `addiu $sp, $sp, -24` / lưu `$ra, $s4, $s3, $s2, $s1, $s0` |

> [!WARNING]
> **Phân biệt rõ 2 hệ tọa độ:**
> - **Display coord** (`dr`, `dc`): vị trí trên màn hình Bitmap (0..7). Tính `px = dc*8`, `py = dr*8`.
> - **Board coord** (`br`, `bc`): vị trí thực trên bàn cờ. Dùng để gọi `rowcol_to_sq`.
>
> **Nếu nhầm 2 loại này, bàn cờ sẽ hiện sai quân hoặc sai màu.**

**Logic đúng:**
```
Lưu $a0 → $s0 (view_player)
Vòng lặp $s1 = dr: 0..7 (display row)
  Vòng lặp $s2 = dc: 0..7 (display col)
    px = dc * 8  →  $s3 = $s2 * 8
    py = dr * 8  →  $s4 = $s1 * 8

    # Tính board coords từ display coords:
    Nếu $s0 == 0 (view Đen): br = dr, bc = dc
    Nếu $s0 == 1 (view Đỏ):  br = 7-dr, bc = 7-dc

    # Màu nền ô:  (board_row + board_col) % 2 == 1 → COLOR_DARK (ô tối, ô chơi được)
    #             (board_row + board_col) % 2 == 0 → COLOR_LIGHT (ô sáng, không dùng)
    Tô nền: li $t8, COLOR_DARK/LIGHT
            jal bmp_fill_rect với $a0=px, $a1=py, $a2=8, $a3=8

    # Vẽ quân (chỉ ô tối mới có quân):
    Nếu (br + bc) % 2 == 1:
      rowcol_to_sq(br, bc) → $v0 = sq
      get_piece(sq) → $v0 = piece
      Nếu piece == BLACK_MAN:
        li $t8, COLOR_BLACK_PC
        jal bmp_fill_rect(px+1, py+1, 6, 6)
      Nếu piece == RED_MAN:
        li $t8, COLOR_RED_PC
        jal bmp_fill_rect(px+1, py+1, 6, 6)
      Nếu piece == BLACK_KING:
        li $t8, COLOR_BLACK_PC / jal bmp_fill_rect(px+1, py+1, 6, 6)
        li $t8, COLOR_KING_MARK / jal bmp_fill_rect(px+3, py+3, 2, 2)
      Nếu piece == RED_KING:
        li $t8, COLOR_RED_PC / jal bmp_fill_rect(px+1, py+1, 6, 6)
        li $t8, COLOR_KING_MARK / jal bmp_fill_rect(px+3, py+3, 2, 2)

Sau khi vẽ xong toàn bộ ô:
  lw $t0, selected_square
  li $t1, -1
  beq $t0, $t1, dbb_done    # -1 = chưa chọn, bỏ qua highlight
  move $a0, $s0              # view_player
  jal bmp_highlight_moves
dbb_done:
  # restore $s, lw $ra, addiu $sp, jr $ra
```

> [!WARNING]
> **`$t8` là caller-saved.** Sau mỗi lệnh `jal` (kể cả `rowcol_to_sq`, `get_piece`), giá trị `$t8` bị xóa. Phải `li $t8, COLOR_...` **ngay trước** mỗi lần gọi `jal bmp_fill_rect`, không được `li $t8` trước rồi gọi nhiều `jal` khác.

> [!TIP]
> Người B có thể test B.1 ngay khi xong, không cần chờ A: Chạy game với STUB của A, bàn cờ Bitmap sẽ hiện 12 quân đỏ + 12 quân đen đúng vị trí.

---

### B.2 — `get_valid_moves` *(Làm sau B.1)*
**File:** `rules.asm` | **Xóa STUB `sw $zero, move_count`**

| | |
|---|---|
| **Đầu vào** | `$a0` = ô chứa quân (1–32) |
| **Đầu ra** | Ghi vào: `move_count` (word), `move_list[i]` (word), `move_is_capture[i]` (word) |
| **Stack** | `addiu $sp, $sp, -24` / lưu `$ra, $s4, $s3, $s2, $s1, $s0` |

**Logic:**
```
sw $zero, move_count           # reset về 0

get_piece($a0) → $s0 = loại quân
Nếu $s0 == EMPTY → jr $ra

sq_to_rowcol($a0) → $s1=row, $s2=col

Xác định hướng thử (các cặp dr, dc):
  BLACK_MAN: (-1,-1),(-1,+1)                     # 2 hướng đi thường
             (-2,-2),(-2,+2)                     # 2 hướng nhảy ăn
  RED_MAN:   (+1,-1),(+1,+1)                     # 2 hướng đi thường
             (+2,-2),(+2,+2)                     # 2 hướng nhảy ăn
  BLACK/RED_KING: (-1,-1),(-1,+1),(+1,-1),(+1,+1) # 4 hướng đi thường
                  (-2,-2),(-2,+2),(+2,-2),(+2,+2) # 4 hướng nhảy ăn

Với TỪNG hướng (dr, dc):
  → Thử ĐI THƯỜNG (abs(dr)==1):
    dest = rowcol_to_sq(row+dr, col+dc)
    Nếu dest > 0 AND get_piece(dest)==EMPTY:
      Thêm dest vào move_list, move_is_capture[i]=0, move_count++

  → Thử NHẢY ĂN (abs(dr)==2):
    mid = rowcol_to_sq(row+dr/2, col+dc/2)
    dest = rowcol_to_sq(row+dr,  col+dc)
    Nếu mid > 0 AND dest > 0:
      get_piece(mid) → piece_mid
      piece_owner(piece_mid) → owner_mid
      Nếu owner_mid != current_player AND owner_mid != -1:  # có quân địch ở giữa
        get_piece(dest)==EMPTY:
          Thêm dest vào move_list, move_is_capture[i]=1, move_count++

SAU KHI điền xong tất cả hướng → Lọc FLAG_FORCE_CAPTURE:
  lw $t0, variant_flags
  andi $t0, $t0, FLAG_FORCE_CAPTURE
  beqz $t0, gvm_done                 # cờ tắt → không lọc

  # Đếm số nước ăn:
  Duyệt move_is_capture[0..move_count-1], đếm capture_count
  Nếu capture_count == 0 → gvm_done  # không có nước ăn → không cần lọc

  # Lọc: chỉ giữ nước ăn, dồn lại từ đầu mảng:
  write_idx = 0
  Duyệt i = 0..move_count-1:
    Nếu move_is_capture[i] == 1:
      move_list[write_idx] = move_list[i]
      move_is_capture[write_idx] = 1
      write_idx++
  sw write_idx, move_count

gvm_done: jr $ra
```

---

### B.3 — `bmp_highlight_moves` *(Làm sau B.2)*
**File:** `display.asm` | **Xóa STUB `jr $ra`**

| | |
|---|---|
| **Đầu vào** | `$a0` = `view_player` |
| **Stack** | `addiu $sp, $sp, -16` / lưu `$ra, $s2, $s1, $s0` |

**Logic:**
```
$s0 = view_player
lw $s1, selected_square

# Tính px, py cho ô được chọn (nhớ xoay nếu view=1):
sq_to_rowcol($s1) → board_r=$v0, board_c=$v1
Nếu $s0==1: display_r=7-board_r, display_c=7-board_c
Nếu $s0==0: display_r=board_r,   display_c=board_c
px = display_c * 8, py = display_r * 8

# Tô ô đang chọn:
li $t8, COLOR_SELECT
jal bmp_fill_rect(px, py, 8, 8)      ← phủ toàn ô

# Vẽ lại quân lên trên COLOR_SELECT:
get_piece($s1) → piece
[vẽ quân theo piece như B.1 tại px,py]

# Lấy và tô các ô đích:
move $a0, $s1
jal get_valid_moves                   ← ghi vào move_count, move_list[]

$s2 = 0 (chỉ số i)
loop:
  lw $t0, move_count
  bge $s2, $t0, bhm_done

  sll $t1, $s2, 2
  la $t2, move_list
  addu $t2, $t2, $t1
  lw $t3, 0($t2)                      ← sq_dich = move_list[i]

  # Tính pixel cho sq_dich (nhớ xoay):
  sq_to_rowcol($t3) → board_r, board_c
  [xoay nếu view=1]
  px2 = display_c * 8, py2 = display_r * 8

  li $t8, COLOR_MOVE
  jal bmp_fill_rect(px2+1, py2+1, 6, 6)

  addiu $s2, $s2, 1
  j loop
bhm_done: jr $ra
```

---

### B.4 — Làm đẹp `draw_board_console` *(Giai đoạn 4 — độc lập)*
**File:** `display.asm`

Thêm vào hàm `draw_board_console`:
- Trước vòng lặp hàng: in `"   A B C D E F G H\n"`.
- Đầu mỗi hàng: in số hàng (1–8) ở lề trái. Nếu `view=0`: hàng 7 → in `"1"`, hàng 0 → in `"8"`. Nếu `view=1`: ngược lại.
- Sau vòng lặp hàng: in lại `"   A B C D E F G H\n"`.

---

## 👤 NGƯỜI C — Luồng game, Thắng/Thua & Biến thể (`main.asm` + `rules.asm`)

### C.1 — Sửa luồng `main.asm` ⭐ *(Song song GĐ1 — độc lập)*
**File:** `main.asm`

**C.1a — Xoay bàn cờ theo lượt** (sửa `game_loop`):
```asm
game_loop:
    lw   $a0, current_player    # thay "li $a0, 0"
    jal  draw_board
```

**C.1b — Luồng nhập + kích hoạt Highlight** (sửa `ask_move`):
```asm
ask_start:
    print_str(msg_enter_start)
    read_int
    move $s0, $v0               # ô xuất phát
    sw   $s0, selected_square   # kích hoạt highlight cho B
    lw   $a0, current_player
    jal  draw_board             # vẽ lại: Bitmap hiện highlight

ask_land:
    print_str(msg_enter_land)
    read_int
    move $s1, $v0               # ô đích

    li   $t0, -1
    sw   $t0, selected_square   # reset highlight trước khi validate

    move $a0, $s0
    move $a1, $s1
    li   $a2, 0
    jal  is_valid_move
    beqz $v0, bad_move
    # ... (tiếp tục như code gốc)
```

**C.1c — Trong vòng lặp chain: cũng highlight + xử lý phong Vua**

Sửa `chain_check:` (thêm 2 đoạn):
```asm
chain_check:
    print_str(msg_captured)

    # --- THÊM: highlight ô hiện tại trước khi hỏi nước tiếp ---
    sw   $s1, selected_square
    lw   $a0, current_player
    jal  draw_board                  # Bitmap tô màu ô đang chain

    move $a0, $s1
    jal  can_chain
    beqz $v0, chain_done_highlight

chain_done_highlight:
    li   $t0, -1
    sw   $t0, selected_square        # reset highlight

    beqz $v0, end_turn               # thay "beqz $v0, end_turn" gốc
    print_str(msg_chaining)
    # ... (tiếp tục như code gốc)
```

**C.1d — In mã lỗi `$v1` chi tiết** (sửa `bad_move`):

Thêm vào `.data`:
```asm
msg_err_range:   .asciiz "Error: Square must be between 1 and 32!\n"
msg_err_empty:   .asciiz "Error: Starting square has no piece!\n"
msg_err_not_own: .asciiz "Error: Piece does not belong to you!\n"
msg_err_occ:     .asciiz "Error: Destination square is already occupied!\n"
msg_err_dir:     .asciiz "Error: Invalid direction or distance!\n"
msg_err_capture: .asciiz "Error: Forced capture is in effect!\n"
msg_err_chain:   .asciiz "Error: Must continue the capture chain!\n"
```

Sửa `bad_move:`:
```asm
bad_move:
    li   $t0, -1
    sw   $t0, selected_square        # reset highlight khi lỗi
    beq  $v1, ERR_OUT_OF_RANGE,  bm_range
    beq  $v1, ERR_EMPTY,         bm_empty
    beq  $v1, ERR_NOT_OWN,       bm_not_own
    beq  $v1, ERR_OCCUPIED,      bm_occ
    beq  $v1, ERR_BAD_DIRECTION, bm_dir
    beq  $v1, ERR_MUST_CAPTURE,  bm_capture
    beq  $v1, ERR_CHAIN_CAPTURE, bm_chain
    print_str(msg_invalid)
    j    ask_start
bm_range:    print_str(msg_err_range)    
             j    ask_start
bm_empty:    print_str(msg_err_empty)
             j    ask_start
bm_not_own:  print_str(msg_err_not_own)
             j    ask_start
bm_occ:      print_str(msg_err_occ)
             j    ask_start
bm_dir:      print_str(msg_err_dir)
             j    ask_start
bm_capture:  print_str(msg_err_capture)
             j    ask_start
bm_chain:    print_str(msg_err_chain)
             j    ask_start
```

---

### C.2 — `player_has_any_move` + `check_winner` *(Làm sau B.2 merge)*
**File:** `rules.asm`

**`player_has_any_move`:** Xóa STUB `li $v0, 1`

| | |
|---|---|
| **Đầu vào** | `$a0` = người chơi |
| **Đầu ra** | `$v0` = 1 còn nước đi / 0 bị chặn |
| **Stack** | `addiu $sp, $sp, -12` / lưu `$ra, $s1, $s0` |

```
$s0 = 1  (chỉ số ô, 1..32)
$s1 = $a0 (người chơi cần kiểm tra)

pham_loop:
  beq $s0, 33, pham_no_move    # hết 32 ô

  get_piece($s0) → $v0 = piece
  Nếu piece == EMPTY → $s0++, j pham_loop

  piece_owner(piece) → $v0 = owner
  Nếu owner != $s1 → $s0++, j pham_loop

  get_valid_moves($s0)          ← ghi vào move_count
  lw $t0, move_count
  bgtz $t0, pham_found          # có nước đi → trả về 1 ngay

  addiu $s0, $s0, 1
  j pham_loop

pham_found: li $v0, 1 / jr $ra
pham_no_move: li $v0, 0 / jr $ra
```

**`check_winner`:** Xóa STUB `li $v0, -1`

| | |
|---|---|
| **Đầu ra** | `$v0` = -1 chưa kết thúc; `0` (PLAYER_BLACK) hoặc `1` (PLAYER_RED) thắng |
| **Stack** | `addiu $sp, $sp, -16` / lưu `$ra, $s2, $s1, $s0` |

```
$s0 = 0 (black_count), $s1 = 0 (red_count)
Duyệt 32 ô:
  get_piece(ô) → so sánh với BLACK_MAN,BLACK_KING / RED_MAN,RED_KING
  Tăng $s0 hoặc $s1 tương ứng

Nếu $s1 == 0 → $v0 = PLAYER_BLACK (=0), jr $ra    # Đỏ hết quân → Đen thắng
Nếu $s0 == 0 → $v0 = PLAYER_RED   (=1), jr $ra    # Đen hết quân → Đỏ thắng

lw $s2, current_player
move $a0, $s2
jal player_has_any_move
beqz $v0, cw_blocked              # người sắp đi bị chặn hết

li $v0, -1                         # chưa kết thúc
jr $ra

cw_blocked:
  xori $v0, $s2, 1                 # người kia thắng
  jr $ra
```

> [!WARNING]
> `check_winner` trả về `0` (Đen thắng) và `1` (Đỏ thắng). Code `main.asm` gốc có `beqz $v0, black_wins` — **đúng**. Không được đảo ngược.

---

### C.3 — Menu Variant + Restart *(Làm sau C.2 merge)*
**File:** `main.asm`

**Thêm vào `.data`:**
```asm
msg_menu_hdr:   .asciiz "=== MIPS CHECKERS GAME ===\n"
msg_menu_1:     .asciiz "Force capture? (1=Yes, 0=No): "
msg_menu_2:     .asciiz "Flying kings?  (1=Yes, 0=No): "
msg_menu_3:     .asciiz "Pawns move/capture backward? (1=Yes, 0=No): "
msg_play_again: .asciiz "Play again? (1=Yes, 0=Exit): "
```

**Thêm vào `.text` tại `main` (trước `game_loop`):**
```asm
    print_str(msg_menu_hdr)
    print_str(msg_menu_1)
    read_int
    beqz $v0, menu2
    lw $t0, variant_flags
    ori $t0, $t0, FLAG_FORCE_CAPTURE
    sw $t0, variant_flags
menu2:
    print_str(msg_menu_2)
    read_int
    beqz $v0, menu3
    lw $t0, variant_flags
    ori $t0, $t0, FLAG_FLYING_KING
    sw $t0, variant_flags
menu3:
    print_str(msg_menu_3)
    read_int
    beqz $v0, menu_done
    lw $t0, variant_flags
    ori $t0, $t0, FLAG_BACKWARD_MAN
    sw $t0, variant_flags
menu_done:
    j game_loop
```

**Sửa `game_over` (thêm hỏi restart):**
```asm
game_over:
    beqz $v0, go_black_wins
    print_str(msg_red_wins)
    j    go_ask
go_black_wins:
    print_str(msg_black_wins)
go_ask:
    print_str(msg_play_again)
    read_int
    beqz $v0, exit_game
    # Reset toàn bộ:
    jal  init_board
    sw   $zero, current_player
    sw   $zero, variant_flags
    li   $t0, -1
    sw   $t0, selected_square
    sw   $zero, draw_offer_black
    sw   $zero, draw_offer_red
    j    main              # quay về menu chọn Variant lại
```

---

### C.4 — `player_has_capture` *(Giai đoạn 4 — sau B.2)*
**File:** `rules.asm` | Xóa STUB `li $v0, 0`

| | |
|---|---|
| **Đầu vào** | `$a0` = người chơi |
| **Đầu ra** | `$v0` = 1 có nước ăn / 0 không |
| **Stack** | `addiu $sp, $sp, -12` / lưu `$ra, $s1, $s0` |

```
$s1 = $a0
$s0 = 1 (ô 1..32)
phc_loop:
  beq $s0, 33, phc_no

  get_piece($s0) → piece
  beqz piece, phc_next
  piece_owner(piece) → owner
  bne owner, $s1, phc_next

  get_valid_moves($s0)        ← điền move_is_capture[]
  lw $t0, move_count
  beqz $t0, phc_next

  Duyệt move_is_capture[0..move_count-1]:
    Nếu tìm thấy == 1 → $v0=1, jr $ra

phc_next:
  addiu $s0, $s0, 1
  j phc_loop

phc_no: li $v0, 0, jr $ra
```

---

## Bảng Tổng Hợp Cuối

| # | Hàm / Tính năng | File | Người | GĐ | Phụ thuộc |
|---|---|---|---|---|---|
| 1 | `apply_move` | `rules.asm` | **A** | 1 | `get_piece`,`set_piece`,`sq_to_rowcol`,`rowcol_to_sq` ✅ |
| 2 | `is_valid_move` | `rules.asm` | **A** | 1 | `get_piece`,`piece_owner`,`sq_to_rowcol`,`rowcol_to_sq` ✅ |
| 3 | `can_chain` | `rules.asm` | **A** | 1 | `get_piece`,`piece_owner`,`sq_to_rowcol`,`rowcol_to_sq` ✅ |
| 4 | `draw_board_bitmap` | `display.asm` | **B** | 1 | `bmp_fill_rect`,`get_piece`,`rowcol_to_sq`,`sq_to_rowcol` ✅ |
| 5 | Xoay bàn + selected_square + mã lỗi | `main.asm` | **C** | 1 | Biến `common.asm` ✅ |
| 6 | `get_valid_moves` | `rules.asm` | **B** | 2 | `get_piece`,`piece_owner`,`sq_to_rowcol`,`rowcol_to_sq` ✅ |
| 7 | `bmp_highlight_moves` | `display.asm` | **B** | 2 | #6 |
| 8 | `player_has_any_move` | `rules.asm` | **C** | 2 | #6 |
| 9 | `check_winner` | `rules.asm` | **C** | 2 | `get_piece` ✅, #8 |
| 10 | Menu Variant + Restart | `main.asm` | **C** | 3 | `variant_flags` ✅ |
| 11 | Vua Bay (`FLAG_FLYING_KING`) | `rules.asm` | **A** | 4 | #6 |
| 12 | Tốt đi lùi (`FLAG_BACKWARD_MAN`) | `rules.asm` | **A** | 4 | #2, #6 |
| 13 | `player_has_capture` | `rules.asm` | **C** | 4 | #6 |
| 14 | Làm đẹp Console | `display.asm` | **B** | 4 | Độc lập ✅ |

---

## Trạng thái STUB hiện tại (cái nào cần hiện thực)

| Hàm | STUB hiện tại trong code | Người làm | GĐ |
|---|---|---|---|
| `get_valid_moves` | `sw $zero, move_count; jr $ra` | **B** | 2 |
| `is_valid_move` | `li $v0, 1; li $v1, ERR_NONE; jr $ra` ← luôn hợp lệ | **A** | 1 |
| `apply_move` | Di chuyển quân nhưng **chưa xóa quân bị ăn, chưa phong Vua** | **A** | 1 |
| `can_chain` | `li $v0, 0; jr $ra` ← không bao giờ chain | **A** | 1 |
| `player_has_capture` | `li $v0, 0; jr $ra` | **C** | 4 |
| `player_has_any_move` | `li $v0, 1; jr $ra` ← luôn còn nước đi | **C** | 2 |
| `check_winner` | `li $v0, -1; jr $ra` ← không bao giờ kết thúc | **C** | 2 |
| `draw_board_bitmap` | `jr $ra` ← không vẽ gì | **B** | 1 |
| `bmp_highlight_moves` | `jr $ra` ← không highlight | **B** | 2 |

> [!NOTE]
> Nhờ STUB được thiết kế cẩn thận, game luôn **chạy được** dù chưa implement hết. Mỗi khi một hàm được hiện thực xong và merge, tính năng tương ứng sẽ hoạt động ngay.

---

## Yêu cầu kỹ thuật MARS

1. Mở `main.asm` trong MARS.
2. Settings → **"Initialize Program Counter to global 'main' if defined"** (tích ✓).
3. Settings → **"Assemble all files in directory"** (tích ✓) **HOẶC** giữ nguyên `.include` ở cuối `main.asm` — **không dùng cả hai cùng lúc** (sẽ bị trùng nhãn).
4. Tools → **Bitmap Display** → chỉnh:
   - Unit Width = **2**, Unit Height = **2**
   - Display Width = **512**, Display Height = **512**
   - Base address = **0x10040000 (heap)**
   - Bấm **"Connect to MIPS"** trước khi Assemble & Run.

> [!NOTE]
> `BMP_W_UNITS = 256` khớp với 512/2 = 256 unit columns. Giữ nguyên setting gốc của MARS.

### Turn Indicator (Corner Overlay)

Hàm `draw_turn_indicator` vẽ một **tam giác đều trỏ xuống** cố định ở **góc dưới-phải** của bàn cờ (ô sáng (7,7) — không bao giờ có quân), đổi màu theo lượt:

| Lượt | Màu tam giác | Hex |
|------|-------------|-----|
| Black | Tối (đen xám) | `0x00222222` |
| Red   | Đỏ            | `0x00CC2222` |

**Thông số:** center_x=240, top_y=229, base_half=12, height=22 — vừa gọn trong ô 32×32.

---

## Thỏa Thuận Interface — Bắt buộc cả 3 người

> [!IMPORTANT]
> **1. Quy tắc Stack — Không được vi phạm:**
> Hàm có lệnh `jal` → phải lưu `$ra` + tất cả `$s_` đang dùng. Tính đủ slot:
> ```asm
> addiu $sp, $sp, -24    # 6 regs × 4 byte
> sw    $ra, 20($sp)
> sw    $s4, 16($sp)
> sw    $s3, 12($sp)
> sw    $s2,  8($sp)
> sw    $s1,  4($sp)
> sw    $s0,  0($sp)
> # ... code ...
> lw    $s0,  0($sp)
> lw    $s1,  4($sp)
> lw    $s2,  8($sp)
> lw    $s3, 12($sp)
> lw    $s4, 16($sp)
> lw    $ra, 20($sp)
> addiu $sp, $sp, 24
> jr    $ra
> ```

> [!IMPORTANT]
> **2. `$t8` là caller-saved:** Giá trị `$t8` bị xóa sau mỗi lệnh `jal`. Người B phải `li $t8, COLOR` **ngay trước** `jal bmp_fill_rect`, không được `li $t8` trước rồi gọi `jal` khác ở giữa.

> [!IMPORTANT]
> **3. Phân biệt display/board coords trong B.1:**
> `px/py` tính từ **display coord**. `rowcol_to_sq` gọi với **board coord**. Hai cái này chỉ bằng nhau khi `view_player=0`.

> [!IMPORTANT]
> **4. `variant_flags` ownership:**
> Chỉ **Người C** (`main.asm`) được `sw` vào `variant_flags`. A và B chỉ được `lw` + `andi`.

> [!IMPORTANT]
> **5. `move_list` ownership:**
> Chỉ `get_valid_moves` (Người B) được ghi vào `move_list`, `move_is_capture`, `move_count`. `can_chain` (Người A) **không dùng** `move_list` — tính trực tiếp trên bàn. Người C đọc SAU khi gọi `get_valid_moves`.

> [!IMPORTANT]
> **6. Hướng đi nhất quán (đã xác nhận):**
> - Đen (`PLAYER_BLACK=0`): đi lên, `Δrow = -1`.
> - Đỏ (`PLAYER_RED=1`): đi xuống, `Δrow = +1`.
> - Phong Vua: Đen đến **hàng 0**, Đỏ đến **hàng 7**.

> [!IMPORTANT]
> **7. Phong Vua khi chain:**
> `apply_move` trả `$v1=1` chỉ để thông báo, chain vẫn tiếp tục nếu `can_chain` = 1; Vua mới được ăn lùi ngay.
