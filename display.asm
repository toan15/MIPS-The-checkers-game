# ============================================================
# display.asm - NGUOI B: hien thi (console + Bitmap Display)
#
# Cai dat MARS Bitmap Display (Tools > Bitmap Display):
#   Unit Width = 8, Unit Height = 8
#   Display Width = 512, Display Height = 512   (=> 64 x 64 unit)
#   Base address = 0x10040000 (heap)
#   Bam "Connect to MIPS" truoc khi chay.
#   Moi o co = 8 x 8 unit.
#
# Phu thuoc (khai bao trong common.asm / rules.asm):
#   (Ma loai quan da duoc khai bao lai cuc bo duoi dang DSP_*)
#   Bien    : selected_square, current_player, move_count, move_list, piece_chars
#   Ham     : sq_to_rowcol, rowcol_to_sq, get_piece, piece_owner, get_valid_moves
#
# Quy uoc toa do (RAT QUAN TRONG):
#   - display coord (dr, dc): vi tri tren man hinh, 0..7. px = dc*8, py = dr*8
#   - board   coord (br, bc): vi tri that tren ban co, dung cho rowcol_to_sq
#   - view_player = 0: hai he trung nhau
#   - view_player = 1: xoay 180 do => (br, bc) = (7-dr, 7-dc) va nguoc lai
# ============================================================
.eqv BMP_BASE        0x10040000
.eqv BMP_W_UNITS     64
.eqv CELL_UNITS      8

.eqv BMP_PIECE_PAD   1                  # than quan cach mep o 1 unit
.eqv BMP_PIECE_SIZE  6                  # than quan 6 x 6 unit
.eqv BMP_KING_PAD    3                  # dau vua: bat dau tai (px+3, py+3)
.eqv BMP_KING_SIZE   2                  # dau vua 2 x 2 unit

.eqv COLOR_LIGHT     0x00F0D9B5
.eqv COLOR_DARK      0x00B58863
.eqv COLOR_BLACK_PC  0x00222222
.eqv COLOR_RED_PC    0x00CC2222
.eqv COLOR_KING_MARK 0x00FFD700
.eqv COLOR_SELECT    0x0000AAFF     # quan dang chon
.eqv COLOR_MOVE      0x0066CC66     # o dich hop le

# Ma loai quan - PHAI TRUNG voi common.asm (EMPTY=0, BLACK_MAN=1, BLACK_KING=2,
# RED_MAN=3, RED_KING=4). Khai bao lai o day (ten DSP_*) de display.asm tu du,
# khong phu thuoc thu tu .include hay che do "Assemble all files in directory".
.eqv DSP_BLACK_MAN   1
.eqv DSP_BLACK_KING  2
.eqv DSP_RED_MAN     3
.eqv DSP_RED_KING    4

.data
# Tieu de cot cho console (B.4). Cot cung bi dao khi view_player = 1
dbc_hdr_black: .asciiz "   A B C D E F G H\n"
dbc_hdr_red:   .asciiz "   H G F E D C B A\n"

# Co cho bmp_highlight_moves (mac dinh 0 = tat, khong doi hanh vi cu):
#   0 : highlight moi nuoc di hop le cua quan dang chon
#   1 : CHI highlight nuoc AN (dung khi dang trong chuoi an lien hoan, luc do
#       chi duoc an tiep). main.asm (C.1c): sw 1 truoc khi draw_board trong chain,
#       va sw 0 khi het chain (cung cho ma reset selected_square = -1).
hl_capture_only: .word 0

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
#   [B.4] Them tieu de cot (A..H) o dau + cuoi ban co, va so hang (1..8) o le trai.
#     view 0: tieu de A..H, hang tren cung = 8, duoi cung = 1
#     view 1: ban co xoay 180 do nen tieu de la H..A, hang tren cung = 1, duoi cung = 8
#     => nhan "A1", "H8"... luon chi dung cung mot o that tren ban co, du nhin tu phia nao.
# ------------------------------------------------------------
draw_board_console:
    addiu $sp, $sp, -24
    sw   $ra, 20($sp)
    sw   $s0, 16($sp)
    sw   $s1, 12($sp)
    sw   $s2, 8($sp)
    move $s2, $a0                # view_player

    move $a0, $s2                # [B.4] tieu de cot phia tren
    jal  dbc_print_header

    li   $s0, 0                  # hang (hang hien thi, tu tren xuong)
dbc_row:
    # [B.4] in so hang o le trai: view 0 -> 8 - hang ; view 1 -> hang + 1
    li   $t0, 8
    subu $t0, $t0, $s0
    beqz $s2, dbc_label
    addiu $t0, $s0, 1
dbc_label:
    addiu $a0, $t0, 48           # '0' + so hang
    li   $v0, 11
    syscall
    li   $a0, 32                 # 2 dau cach de cot thang hang voi tieu de
    li   $v0, 11
    syscall
    li   $a0, 32
    li   $v0, 11
    syscall

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

    move $a0, $s2                # [B.4] tieu de cot phia duoi
    jal  dbc_print_header

    lw   $s2, 8($sp)
    lw   $s1, 12($sp)
    lw   $s0, 16($sp)
    lw   $ra, 20($sp)
    addiu $sp, $sp, 24
    jr   $ra

# ------------------------------------------------------------
# dbc_print_header: in dong tieu de cot cua console
#   $a0 = view_player (0 -> "A..H", 1 -> "H..A")
#   Ham la (leaf), khong dung stack. Pha $a0, $v0, $t0.
# ------------------------------------------------------------
dbc_print_header:
    la   $t0, dbc_hdr_black
    beqz $a0, dbc_hdr_print
    la   $t0, dbc_hdr_red
dbc_hdr_print:
    move $a0, $t0
    li   $v0, 4
    syscall
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
# bmp_view_rc: doi (hang, cot) giua toa do ban co <-> toa do hien thi
#   $a0 = hang, $a1 = cot, $a2 = view_player
#   $v0 = hang', $v1 = cot'
#   view 0: giu nguyen. view 1: (7-hang, 7-cot).
#   Phep xoay 180 do tu nghich dao => dung duoc theo ca hai chieu
#   (display->board va board->display).
#   Ham la (leaf), khong dung stack. Chi pha $t0.
# ------------------------------------------------------------
bmp_view_rc:
    move $v0, $a0
    move $v1, $a1
    beqz $a2, bvr_done
    li   $t0, 7
    subu $v0, $t0, $a0
    subu $v1, $t0, $a1
bvr_done:
    jr   $ra

# ------------------------------------------------------------
# bmp_draw_piece: ve mot quan len bitmap
#   $a0 = px, $a1 = py (goc tren-trai cua o, don vi unit), $a2 = loai quan
#   EMPTY (hoac gia tri la) -> khong ve gi.
#   Than quan 6x6 tai (px+1, py+1); vua them dau vang 2x2 tai (px+3, py+3).
#   Stack: 16 byte (luu $ra, $s2, $s1, $s0)
# ------------------------------------------------------------
bmp_draw_piece:
    addiu $sp, $sp, -16
    sw   $ra, 12($sp)
    sw   $s2, 8($sp)
    sw   $s1, 4($sp)
    sw   $s0, 0($sp)

    move $s0, $a0                # px
    move $s1, $a1                # py
    move $s2, $a2                # piece

    # chon mau than quan
    li   $t0, DSP_BLACK_MAN
    beq  $s2, $t0, bdp_black
    li   $t0, DSP_BLACK_KING
    beq  $s2, $t0, bdp_black
    li   $t0, DSP_RED_MAN
    beq  $s2, $t0, bdp_red
    li   $t0, DSP_RED_KING
    beq  $s2, $t0, bdp_red
    j    bdp_done                # EMPTY: khong ve
bdp_black:
    li   $t8, COLOR_BLACK_PC     # $t8 gan ngay truoc jal bmp_fill_rect
    j    bdp_body
bdp_red:
    li   $t8, COLOR_RED_PC
bdp_body:
    addiu $a0, $s0, BMP_PIECE_PAD
    addiu $a1, $s1, BMP_PIECE_PAD
    li   $a2, BMP_PIECE_SIZE
    li   $a3, BMP_PIECE_SIZE
    jal  bmp_fill_rect

    # vua: them dau vang o giua
    li   $t0, DSP_BLACK_KING
    beq  $s2, $t0, bdp_king
    li   $t0, DSP_RED_KING
    bne  $s2, $t0, bdp_done
bdp_king:
    li   $t8, COLOR_KING_MARK    # gan lai $t8 (jal da pha)
    addiu $a0, $s0, BMP_KING_PAD
    addiu $a1, $s1, BMP_KING_PAD
    li   $a2, BMP_KING_SIZE
    li   $a3, BMP_KING_SIZE
    jal  bmp_fill_rect
bdp_done:
    lw   $s0, 0($sp)
    lw   $s1, 4($sp)
    lw   $s2, 8($sp)
    lw   $ra, 12($sp)
    addiu $sp, $sp, 16
    jr   $ra

# ------------------------------------------------------------
# [DONE] draw_board_bitmap: $a0 = view_player
#   1. Duyet 8x8 o hien thi: to nen COLOR_LIGHT / COLOR_DARK
#      ((board_row + board_col) % 2 == 1 -> o toi, o choi duoc)
#   2. Voi o toi: lay quan (rowcol_to_sq + get_piece), ve than quan 6x6;
#      vua them dau COLOR_KING_MARK 2x2
#   3. view_player = 1: (hang, cot) hien thi -> (7-hang, 7-cot) tren ban co
#   4. Neu selected_square != -1: goi bmp_highlight_moves
#
#   Thanh ghi: $s0 = view_player, $s1 = dr, $s2 = dc, $s3 = px, $s4 = py
#   Stack: 24 byte (luu $ra, $s4..$s0)
# ------------------------------------------------------------
draw_board_bitmap:
    addiu $sp, $sp, -24
    sw   $ra, 20($sp)
    sw   $s4, 16($sp)
    sw   $s3, 12($sp)
    sw   $s2, 8($sp)
    sw   $s1, 4($sp)
    sw   $s0, 0($sp)

    move $s0, $a0                # view_player
    li   $s1, 0                  # dr: hang hien thi 0..7
dbb_row:
    li   $s2, 0                  # dc: cot hien thi 0..7
dbb_col:
    sll  $s3, $s2, 3             # px = dc * 8   (toa do HIEN THI)
    sll  $s4, $s1, 3             # py = dr * 8

    # --- display -> board ---
    move $a0, $s1
    move $a1, $s2
    move $a2, $s0
    jal  bmp_view_rc             # $v0 = br, $v1 = bc

    # --- nen o: (br + bc) % 2 == 1 -> toi, nguoc lai -> sang ---
    addu $t0, $v0, $v1
    andi $t0, $t0, 1
    li   $t8, COLOR_LIGHT
    beqz $t0, dbb_bg
    li   $t8, COLOR_DARK
dbb_bg:
    move $a0, $s3
    move $a1, $s4
    li   $a2, CELL_UNITS
    li   $a3, CELL_UNITS
    jal  bmp_fill_rect           # (jal pha $t0..$t5 nen se tinh lai br, bc ben duoi)

    # --- ve quan (chi o toi moi co quan) ---
    move $a0, $s1
    move $a1, $s2
    move $a2, $s0
    jal  bmp_view_rc             # $v0 = br, $v1 = bc
    addu $t0, $v0, $v1
    andi $t0, $t0, 1
    beqz $t0, dbb_next           # o sang: khong co quan

    move $a0, $v0                # br
    move $a1, $v1                # bc
    jal  rowcol_to_sq            # $v0 = so o 1..32 (0 neu khong hop le)
    beqz $v0, dbb_next
    move $a0, $v0
    jal  get_piece               # $v0 = loai quan
    move $a2, $v0
    move $a0, $s3                # px, py: toa do HIEN THI
    move $a1, $s4
    jal  bmp_draw_piece

dbb_next:
    addiu $s2, $s2, 1
    blt  $s2, 8, dbb_col
    addiu $s1, $s1, 1
    blt  $s1, 8, dbb_row

    # --- highlight neu dang co o duoc chon ---
    lw   $t0, selected_square
    li   $t1, -1
    beq  $t0, $t1, dbb_done      # -1 = chua chon, bo qua
    move $a0, $s0                # view_player
    jal  bmp_highlight_moves
dbb_done:
    lw   $s0, 0($sp)
    lw   $s1, 4($sp)
    lw   $s2, 8($sp)
    lw   $s3, 12($sp)
    lw   $s4, 16($sp)
    lw   $ra, 20($sp)
    addiu $sp, $sp, 24
    jr   $ra

# ------------------------------------------------------------
# [DONE] bmp_highlight_moves: $a0 = view_player
#   Doc selected_square: to COLOR_SELECT (ca o) + ve lai quan len tren,
#   goi get_valid_moves(selected_square), roi to COLOR_MOVE (6x6, giua o)
#   cac o trong move_list[0 .. move_count-1].
#   Neu hl_capture_only = 1: chi to cac o dich cua nuoc AN (dang trong chain).
#   Bao ve: bo qua (khong ve gi) neu selected_square ngoai 1..32, o trong,
#   hoac quan khong thuoc nguoi dang di (do C ghi selected_square truoc khi validate).
#
#   Thanh ghi: $s0 = view_player, $s1 = selected_square, $s2 = i,
#              $s3 = px, $s4 = py
#   Stack: 24 byte (luu $ra, $s4..$s0)
# ------------------------------------------------------------
bmp_highlight_moves:
    addiu $sp, $sp, -24
    sw   $ra, 20($sp)
    sw   $s4, 16($sp)
    sw   $s3, 12($sp)
    sw   $s2, 8($sp)
    sw   $s1, 4($sp)
    sw   $s0, 0($sp)

    move $s0, $a0                # view_player
    lw   $s1, selected_square

    # --- bao ve: ngoai 1..32 -> thoat (tranh ve ra ngoai bitmap) ---
    blt  $s1, 1, bhm_done
    bgt  $s1, 32, bhm_done

    # --- bao ve: o trong hoac quan cua doi thu -> khong highlight ---
    move $a0, $s1
    jal  get_piece
    beqz $v0, bhm_done           # EMPTY = 0
    move $a0, $v0
    jal  piece_owner
    lw   $t0, current_player
    bne  $v0, $t0, bhm_done

    # --- to o dang chon: tinh px, py (xoay neu view = 1) ---
    move $a0, $s1
    jal  sq_to_rowcol            # $v0 = board_r, $v1 = board_c
    move $a0, $v0
    move $a1, $v1
    move $a2, $s0
    jal  bmp_view_rc             # $v0 = display_r, $v1 = display_c
    sll  $s4, $v0, 3             # py = display_r * 8
    sll  $s3, $v1, 3             # px = display_c * 8

    li   $t8, COLOR_SELECT
    move $a0, $s3
    move $a1, $s4
    li   $a2, CELL_UNITS
    li   $a3, CELL_UNITS
    jal  bmp_fill_rect           # phu toan bo o

    # --- ve lai quan len tren COLOR_SELECT ---
    move $a0, $s1
    jal  get_piece
    move $a2, $v0
    move $a0, $s3
    move $a1, $s4
    jal  bmp_draw_piece

    # --- lay danh sach nuoc di va to cac o dich ---
    move $a0, $s1
    jal  get_valid_moves         # ghi move_count, move_list[], move_is_capture[]

    li   $s2, 0                  # i = 0
bhm_loop:
    lw   $t0, move_count
    bge  $s2, $t0, bhm_done

    sll  $t1, $s2, 2             # move_list dung WORD => offset = i * 4
    lw   $t3, hl_capture_only
    beqz $t3, bhm_draw           # co tat: ve moi nuoc
    la   $t4, move_is_capture
    addu $t4, $t4, $t1
    lw   $t5, 0($t4)
    beqz $t5, bhm_skip           # co bat: bo qua nuoc di thuong
bhm_draw:
    la   $t2, move_list
    addu $t2, $t2, $t1
    lw   $a0, 0($t2)             # sq_dich = move_list[i]

    jal  sq_to_rowcol            # $v0 = board_r, $v1 = board_c
    move $a0, $v0
    move $a1, $v1
    move $a2, $s0
    jal  bmp_view_rc             # $v0 = display_r, $v1 = display_c
    sll  $s4, $v0, 3             # py2
    sll  $s3, $v1, 3             # px2

    li   $t8, COLOR_MOVE
    addiu $a0, $s3, BMP_PIECE_PAD
    addiu $a1, $s4, BMP_PIECE_PAD
    li   $a2, BMP_PIECE_SIZE
    li   $a3, BMP_PIECE_SIZE
    jal  bmp_fill_rect

bhm_skip:
    addiu $s2, $s2, 1
    j    bhm_loop
bhm_done:
    lw   $s0, 0($sp)
    lw   $s1, 4($sp)
    lw   $s2, 8($sp)
    lw   $s3, 12($sp)
    lw   $s4, 16($sp)
    lw   $ra, 20($sp)
    addiu $sp, $sp, 24
    jr   $ra