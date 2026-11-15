# ============================================================
# rules.asm - NGUOI A: logic luat choi
# Quy uoc: ham giu nguyen $s0-$s7, $sp, $ra. $t0-$t9, $a0-$a3,
#          $v0-$v1 co the bi ghi de.
# Phan [DONE] da viet san, phan [TODO] la viec cua A.
# ============================================================
.text

# ------------------------------------------------------------
# [DONE] init_board: xep 12 quan do (o 1..12), 12 quan den (o 21..32)
# ------------------------------------------------------------
init_board:
    la   $t0, board
    li   $t1, 0                  # chi so 0..31
ib_loop:
    li   $t2, EMPTY
    slti $t3, $t1, 12
    beqz $t3, ib_not_red
    li   $t2, RED_MAN            # chi so 0..11
    j    ib_store
ib_not_red:
    slti $t3, $t1, 20
    bnez $t3, ib_store           # chi so 12..19: trong
    li   $t2, BLACK_MAN          # chi so 20..31
ib_store:
    addu $t4, $t0, $t1
    sb   $t2, 0($t4)
    addiu $t1, $t1, 1
    blt  $t1, 32, ib_loop
    jr   $ra

# ------------------------------------------------------------
# [DONE] sq_to_rowcol: $a0 = o (1..32) -> $v0 = hang (0..7, 0 la tren cung)
#                                         $v1 = cot  (0..7)
# Hang chan (0,2,..): o nam o cot le (1,3,5,7); hang le: cot chan (0,2,4,6)
# ------------------------------------------------------------
sq_to_rowcol:
    addiu $t0, $a0, -1
    srl  $v0, $t0, 2             # hang = idx / 4
    andi $t1, $t0, 3
    sll  $t1, $t1, 1             # 2 * (idx % 4)
    andi $t2, $v0, 1
    xori $t2, $t2, 1             # 1 neu hang chan
    addu $v1, $t1, $t2
    jr   $ra

# ------------------------------------------------------------
# [DONE] rowcol_to_sq: $a0 = hang, $a1 = cot -> $v0 = o (1..32) hoac 0
#                      neu ngoai ban co / la o khong dung duoc
# ------------------------------------------------------------
rowcol_to_sq:
    bltz $a0, rc_bad
    bgt  $a0, 7, rc_bad
    bltz $a1, rc_bad
    bgt  $a1, 7, rc_bad
    addu $t0, $a0, $a1
    andi $t0, $t0, 1
    beqz $t0, rc_bad             # (hang + cot) chan = o trang
    sll  $v0, $a0, 2
    srl  $t1, $a1, 1
    addu $v0, $v0, $t1
    addiu $v0, $v0, 1
    jr   $ra
rc_bad:
    li   $v0, 0
    jr   $ra

# ------------------------------------------------------------
# [DONE] get_piece: $a0 = o (1..32) -> $v0 = gia tri o (EMPTY..RED_KING)
# ------------------------------------------------------------
get_piece:
    la   $t0, board
    addiu $t1, $a0, -1
    addu $t0, $t0, $t1
    lb   $v0, 0($t0)
    jr   $ra

# ------------------------------------------------------------
# [DONE] set_piece: $a0 = o (1..32), $a1 = gia tri moi
# ------------------------------------------------------------
set_piece:
    la   $t0, board
    addiu $t1, $a0, -1
    addu $t0, $t0, $t1
    sb   $a1, 0($t0)
    jr   $ra

# ------------------------------------------------------------
# [DONE] piece_owner: $a0 = gia tri o -> $v0 = PLAYER_BLACK / PLAYER_RED / -1 (trong)
# ------------------------------------------------------------
piece_owner:
    beqz $a0, po_none
    blt  $a0, RED_MAN, po_black
    li   $v0, PLAYER_RED
    jr   $ra
po_black:
    li   $v0, PLAYER_BLACK
    jr   $ra
po_none:
    li   $v0, -1
    jr   $ra

# ------------------------------------------------------------
# [TODO] get_valid_moves: $a0 = o chua quan
#   Dien vao: move_count, move_list[], move_is_capture[]
#   - Quan thuong: 2 huong tien (+ 2 huong lui neu FLAG_BACKWARD_MAN)
#   - Vua: 4 huong; neu FLAG_FLYING_KING thi di/an nhieu o theo duong cheo
#   - Neu FLAG_FORCE_CAPTURE va co nuoc an o bat ky quan nao -> chi tra nuoc an
#   Dung cho: B (highlight tren bitmap), C (che do chon quan bang so)
# ------------------------------------------------------------
get_valid_moves:
    sw   $zero, move_count       # STUB: khong co nuoc di
    jr   $ra

# ------------------------------------------------------------
# [TODO] is_valid_move: $a0 = o xuat phat, $a1 = o dich,
#                       $a2 = chain_only (1 = dang trong chuoi an, chi duoc an)
#   -> $v0 = 1 neu hop le, 0 neu khong
#   -> $v1 = ma loi ERR_* (ERR_NONE neu hop le)
#   Kiem tra: o trong 1..32, o xuat phat co quan, quan cua current_player,
#             o dich trong, huong/khoang cach, bat buoc an (neu bat variant)
# ------------------------------------------------------------
is_valid_move:
    li   $v0, 1                  # STUB: luon hop le (de chay thu luong game)
    li   $v1, ERR_NONE
    jr   $ra

# ------------------------------------------------------------
# [TODO] apply_move: $a0 = o xuat phat, $a1 = o dich (da duoc kiem tra hop le)
#   -> $v0 = 1 neu vua an quan, 0 neu di thuong
#   -> $v1 = 1 neu vua phong vua
#   Viec can lam: di chuyen quan, xoa quan bi an (o giua), phong vua
#   (den: hang 0, do: hang 7). Khong doi luot o day.
# ------------------------------------------------------------
apply_move:
    # STUB TAM THOI: chi dich chuyen quan, khong an, khong phong vua
    addiu $sp, $sp, -16
    sw   $ra, 12($sp)
    sw   $s0, 8($sp)
    sw   $s1, 4($sp)
    move $s0, $a0
    move $s1, $a1
    jal  get_piece               # $a0 van la o xuat phat
    move $a0, $s1
    move $a1, $v0
    jal  set_piece
    move $a0, $s0
    li   $a1, EMPTY
    jal  set_piece
    li   $v0, 0
    li   $v1, 0
    lw   $s1, 4($sp)
    lw   $s0, 8($sp)
    lw   $ra, 12($sp)
    addiu $sp, $sp, 16
    jr   $ra

# ------------------------------------------------------------
# [TODO] can_chain: $a0 = o quan vua nhay xong -> $v0 = 1 neu con nuoc an tiep
#   (luu y: neu vua phong vua trong luot an thi vua co the an lui tiep)
# ------------------------------------------------------------
can_chain:
    li   $v0, 0                  # STUB
    jr   $ra

# ------------------------------------------------------------
# [TODO] player_has_capture: $a0 = nguoi choi -> $v0 = 1 neu co bat ky nuoc an
#   Dung cho FLAG_FORCE_CAPTURE
# ------------------------------------------------------------
player_has_capture:
    li   $v0, 0                  # STUB
    jr   $ra

# ------------------------------------------------------------
# [TODO] player_has_any_move: $a0 = nguoi choi -> $v0 = 1 neu con nuoc di nao do
#   (dung cho dieu kien thua do bi chan het duong)
# ------------------------------------------------------------
player_has_any_move:
    li   $v0, 1                  # STUB
    jr   $ra

# ------------------------------------------------------------
# [TODO] check_winner: kiem tra theo current_player (nguoi sap di)
#   -> $v0 = -1 neu chua ket thuc
#           PLAYER_BLACK / PLAYER_RED = nguoi thang
#   Het quan HOAC khong con nuoc di -> nguoi kia thang
# ------------------------------------------------------------
check_winner:
    li   $v0, -1                 # STUB: khong bao gio ket thuc
    jr   $ra
