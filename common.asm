# ============================================================
# common.asm - hang so, macro, du lieu dung chung (CA CO2008)
# Ca nhom CHI sua file nay khi da thong nhat voi nhau.
# ============================================================

# ---------- Gia tri o tren ban co ----------
.eqv EMPTY       0
.eqv BLACK_MAN   1      # 'b'
.eqv BLACK_KING  2      # 'B'
.eqv RED_MAN     3      # 'r'
.eqv RED_KING    4      # 'R'

# ---------- Nguoi choi ----------
.eqv PLAYER_BLACK 0     # di truoc, o phia duoi (o 21..32)
.eqv PLAYER_RED   1     # o phia tren (o 1..12)

# ---------- Bit trong variant_flags ----------
.eqv FLAG_FORCE_CAPTURE  1   # bat buoc an quan
.eqv FLAG_FLYING_KING    2   # vua bay
.eqv FLAG_BACKWARD_MAN   4   # tot duoc di/an lui

# ---------- Ma loi tra ve boi is_valid_move ($v1) ----------
.eqv ERR_NONE          0
.eqv ERR_OUT_OF_RANGE  1     # so o ngoai 1..32
.eqv ERR_EMPTY         2     # o xuat phat khong co quan
.eqv ERR_NOT_OWN       3     # quan khong phai cua nguoi choi hien tai
.eqv ERR_OCCUPIED      4     # o dich da co quan
.eqv ERR_BAD_DIRECTION 5     # sai huong / sai khoang cach
.eqv ERR_MUST_CAPTURE  6     # dang bat buoc an quan
.eqv ERR_CHAIN_CAPTURE 7     # dang trong chuoi an, phai an tiep

.eqv MAX_MOVES 16            # so nuoc di toi da cua 1 quan (du cho flying king)

# ---------- Macro tien ich ----------
.macro print_str (%label)
    la   $a0, %label
    li   $v0, 4
    syscall
.end_macro

.macro print_int_reg (%reg)
    move $a0, %reg
    li   $v0, 1
    syscall
.end_macro

.macro print_char (%c)
    li   $a0, %c
    li   $v0, 11
    syscall
.end_macro

.macro read_int
    jal  read_int_safe       # doc so nguyen an toan (khong crash MARS) -> ket qua trong $v0
.end_macro

# ============================================================
# DU LIEU TOAN CUC
# ============================================================
.data
# board[0..31]  <->  o so 1..32 theo ky hieu de bai (chi so = o - 1)
board:            .space 32
                  .align 2
current_player:   .word 0            # PLAYER_BLACK / PLAYER_RED
variant_flags:    .word 0            # to hop FLAG_*
selected_square:  .word -1           # -1 = chua chon quan (che do chon quan bang so)
draw_offer_black: .word 0
draw_offer_red:   .word 0

# Ket qua cua get_valid_moves(square):
move_count:       .word 0
move_list:        .space 64          # MAX_MOVES * 4 byte: cac o dich hop le
move_is_capture:  .space 64          # MAX_MOVES * 4 byte: 1 neu nuoc do la an quan

piece_chars:      .asciiz "0bBrR"    # ky tu in ra cho tung gia tri o
