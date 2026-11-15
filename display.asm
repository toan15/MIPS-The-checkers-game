# ============================================================
# display.asm - NGUOI B: hien thi (console + Bitmap Display)
#
# Cai dat MARS Bitmap Display (Tools > Bitmap Display):
#   Unit Width = 8, Unit Height = 8
#   Display Width = 512, Display Height = 512   (=> 64 x 64 unit)
#   Base address = 0x10040000 (heap)
#   Bam "Connect to MIPS" truoc khi chay.
#   Moi o co = 8 x 8 unit.
# ============================================================
.eqv BMP_BASE        0x10040000
.eqv BMP_W_UNITS     64
.eqv CELL_UNITS      8

.eqv COLOR_LIGHT     0x00F0D9B5
.eqv COLOR_DARK      0x00B58863
.eqv COLOR_BLACK_PC  0x00222222
.eqv COLOR_RED_PC    0x00CC2222
.eqv COLOR_KING_MARK 0x00FFD700
.eqv COLOR_SELECT    0x0000AAFF     # quan dang chon
.eqv COLOR_MOVE      0x0066CC66     # o dich hop le

.text

# ------------------------------------------------------------
# draw_board: $a0 = view_player (0 = nhin tu phia den, 1 = nhin tu phia do)
#   Ve ca console lan bitmap. Luc dau goi voi $a0 = 0 (khong xoay).
# ------------------------------------------------------------
draw_board:
    addiu $sp, $sp, -8
    sw   $ra, 4($sp)
    sw   $s0, 0($sp)
    move $s0, $a0
    jal  draw_board_console
    move $a0, $s0
    jal  draw_board_bitmap
    lw   $s0, 0($sp)
    lw   $ra, 4($sp)
    addiu $sp, $sp, 8
    jr   $ra

# ------------------------------------------------------------
# [DONE] draw_board_console: in ban co ra console theo mau de bai
#   $a0 = view_player. view_player = 1 -> xoay 180 do (hang, cot) -> (7-hang, 7-cot)
#   '0' = trong, b/B = den, r/R = do, ' ' = o khong dung duoc
#   TODO (QoL): them so hang/cot, ky hieu dep hon, danh so o theo goc nhin
# ------------------------------------------------------------
draw_board_console:
    addiu $sp, $sp, -24
    sw   $ra, 20($sp)
    sw   $s0, 16($sp)
    sw   $s1, 12($sp)
    sw   $s2, 8($sp)
    move $s2, $a0                # view_player
    li   $s0, 0                  # hang
dbc_row:
    li   $s1, 0                  # cot
dbc_col:
    move $a0, $s0
    move $a1, $s1
    beqz $s2, dbc_lookup
    li   $t0, 7
    subu $a0, $t0, $s0           # xoay ban co
    subu $a1, $t0, $s1
dbc_lookup:
    jal  rowcol_to_sq
    beqz $v0, dbc_blank
    move $a0, $v0
    jal  get_piece
    la   $t0, piece_chars
    addu $t0, $t0, $v0
    lb   $a0, 0($t0)
    li   $v0, 11
    syscall
    j    dbc_sep
dbc_blank:
    li   $a0, 32
    li   $v0, 11
    syscall
dbc_sep:
    li   $a0, 32
    li   $v0, 11
    syscall
    addiu $s1, $s1, 1
    blt  $s1, 8, dbc_col
    li   $a0, 10
    li   $v0, 11
    syscall
    addiu $s0, $s0, 1
    blt  $s0, 8, dbc_row
    lw   $s2, 8($sp)
    lw   $s1, 12($sp)
    lw   $s0, 16($sp)
    lw   $ra, 20($sp)
    addiu $sp, $sp, 24
    jr   $ra

# ------------------------------------------------------------
# [DONE] bmp_fill_rect: to hinh chu nhat tren bitmap (don vi = unit)
#   $a0 = x, $a1 = y, $a2 = rong, $a3 = cao, $t8 = mau
# ------------------------------------------------------------
bmp_fill_rect:
    move $t0, $a1                # y hien tai
    addu $t1, $a1, $a3           # y ket thuc
bfr_y:
    bge  $t0, $t1, bfr_done
    move $t2, $a0                # x hien tai
    addu $t3, $a0, $a2           # x ket thuc
bfr_x:
    bge  $t2, $t3, bfr_next
    mul  $t4, $t0, BMP_W_UNITS
    addu $t4, $t4, $t2
    sll  $t4, $t4, 2
    li   $t5, BMP_BASE
    addu $t4, $t4, $t5
    sw   $t8, 0($t4)
    addiu $t2, $t2, 1
    j    bfr_x
bfr_next:
    addiu $t0, $t0, 1
    j    bfr_y
bfr_done:
    jr   $ra

# ------------------------------------------------------------
# [TODO] draw_board_bitmap: $a0 = view_player
#   1. Duyet 8x8 o: to nen COLOR_LIGHT / COLOR_DARK bang bmp_fill_rect
#   2. Voi o dung duoc: lay quan (rowcol_to_sq + get_piece), ve hinh
#      vuong/tron nho mau COLOR_BLACK_PC / COLOR_RED_PC; vua them dau COLOR_KING_MARK
#   3. view_player = 1: dao (hang, cot) -> (7-hang, 7-cot) nhu ban console
#   4. Neu selected_square != -1: goi bmp_highlight_moves
#   Meo: de dep, ve vong tron bang cach tu hinh vuong bo 4 goc
# ------------------------------------------------------------
draw_board_bitmap:
    jr   $ra                     # STUB

# ------------------------------------------------------------
# [TODO] bmp_highlight_moves: $a0 = view_player
#   Doc selected_square: to COLOR_SELECT, goi get_valid_moves(selected_square),
#   roi to COLOR_MOVE cac o trong move_list[0 .. move_count-1]
# ------------------------------------------------------------
bmp_highlight_moves:
    jr   $ra                     # STUB
