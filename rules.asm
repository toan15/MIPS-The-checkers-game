# ============================================================
# rules.asm - NGUOI A: logic luat choi
# Quy uoc: ham giu nguyen $s0-$s7, $sp, $ra. $t0-$t9, $a0-$a3,
#          $v0-$v1 co the bi ghi de.
#
# Bien the (variant_flags, chi DOC o day - C moi duoc ghi):
#   FLAG_FORCE_CAPTURE : bat buoc an quan
#   FLAG_FLYING_KING   : vua bay (di/an nhieu o theo duong cheo)
#   FLAG_BACKWARD_MAN  : quan thuong duoc di va an lui
#
# Bo cuc: 0 = hang tren cung. Den (PLAYER_BLACK=0) di LEN (drow=-1),
#         Do (PLAYER_RED=1) di XUONG (drow=+1).
# Huong cheo: 0:(-1,-1)  1:(-1,+1)  2:(+1,-1)  3:(+1,+1)
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

# ============================================================
# HAM TRO GIUP NOI BO (tien to rl_) - dung chung cho nhieu ham ben duoi
# ============================================================

# ------------------------------------------------------------
# rl_add_move: $a0 = o dich, $a1 = is_capture (0/1)
#   Ghi vao move_list[count] / move_is_capture[count] (WORD, offset = count*4),
#   roi tang move_count. Bo qua neu da du MAX_MOVES.
#   Ham la (leaf), chi pha $t0-$t2.
# ------------------------------------------------------------
rl_add_move:
    lw   $t0, move_count
    bge  $t0, MAX_MOVES, ram_done
    sll  $t1, $t0, 2             # offset = count * 4
    la   $t2, move_list
    addu $t2, $t2, $t1
    sw   $a0, 0($t2)             # move_list[count] = o dich
    la   $t2, move_is_capture
    addu $t2, $t2, $t1
    sw   $a1, 0($t2)             # move_is_capture[count] = 0/1
    addiu $t0, $t0, 1
    sw   $t0, move_count
ram_done:
    jr   $ra

# ------------------------------------------------------------
# rl_path_info: $a0 = o xuat phat, $a1 = o dich (nam tren cung 1 duong cheo)
#   -> $v0 = so o KHONG TRONG nam giua hai o (khong tinh 2 dau mut)
#      $v1 = o cua quan cuoi cung gap duoc (0 neu $v0 = 0)
#   Dung cho: is_valid_move (kiem tra duong di) va apply_move (xoa quan bi an).
#   Voi nuoc hop le thi $v0 <= 1.
# ------------------------------------------------------------
rl_path_info:
    addiu $sp, $sp, -40
    sw   $ra, 32($sp)
    sw   $s7, 28($sp)
    sw   $s6, 24($sp)
    sw   $s5, 20($sp)
    sw   $s4, 16($sp)
    sw   $s3, 12($sp)
    sw   $s2, 8($sp)
    sw   $s1, 4($sp)
    sw   $s0, 0($sp)

    li   $s5, 0                  # count
    li   $s6, 0                  # last
    move $s4, $a1                # o dich (tam)
    jal  sq_to_rowcol            # $a0 van la o xuat phat
    move $s0, $v0                # hang hien tai
    move $s1, $v1                # cot hien tai
    move $a0, $s4
    jal  sq_to_rowcol
    subu $t0, $v0, $s0           # dr
    subu $t1, $v1, $s1           # dc
    slt  $s2, $zero, $t0         # dr > 0
    slt  $t2, $t0, $zero         # dr < 0
    subu $s2, $s2, $t2           # s2 = sign(dr)
    slt  $s3, $zero, $t1
    slt  $t2, $t1, $zero
    subu $s3, $s3, $t2           # s3 = sign(dc)
    bgez $t0, rpi_abs
    subu $t0, $zero, $t0         # |dr|
rpi_abs:
    addiu $s4, $t0, -1           # so o o giua = |dr| - 1
rpi_loop:
    blez $s4, rpi_done
    addu $s0, $s0, $s2
    addu $s1, $s1, $s3
    move $a0, $s0
    move $a1, $s1
    jal  rowcol_to_sq
    beqz $v0, rpi_next
    move $s7, $v0                # o dang xet
    move $a0, $v0
    jal  get_piece
    beqz $v0, rpi_next           # o trong
    addiu $s5, $s5, 1
    move $s6, $s7
rpi_next:
    addiu $s4, $s4, -1
    j    rpi_loop
rpi_done:
    move $v0, $s5
    move $v1, $s6

    lw   $s0, 0($sp)
    lw   $s1, 4($sp)
    lw   $s2, 8($sp)
    lw   $s3, 12($sp)
    lw   $s4, 16($sp)
    lw   $s5, 20($sp)
    lw   $s6, 24($sp)
    lw   $s7, 28($sp)
    lw   $ra, 32($sp)
    addiu $sp, $sp, 40
    jr   $ra

# ------------------------------------------------------------
# rl_scan_dir: quet MOT huong cheo xuat phat tu quan o o $a0
#   $a0 = o chua quan, $a1 = huong (0..3), $a2 = append (1: ghi nuoc vao
#   move_list, 0: chi kiem tra, khong dong vao move_list)
#   -> $v0 = 1 neu theo huong nay co it nhat 1 nuoc AN
#
#   Luat (dung cho moi loai quan):
#   - Huong cam: quan thuong chi duoc tien (tru khi FLAG_BACKWARD_MAN); vua 4 huong.
#   - Khong bay (quan thuong / vua thuong): o ke ben trong -> nuoc di thuong;
#     o ke ben la quan dich va o ngay sau trong -> nuoc an.
#   - Bay (vua + FLAG_FLYING_KING): moi o trong lien tiep la nuoc di thuong;
#     gap quan dich dau tien, moi o trong lien tiep ngay sau no la nuoc an;
#     gap quan minh hoac 2 quan lien nhau thi dung.
#
#   Thanh ghi: s0=hang, s1=cot (vi tri dang xet), s2=drow, s3=dcol,
#              s4=chu so huu, s5=bay?, s6=append, s7=found
#   Stack: 40 byte, [36($sp)] = o dang xet (bien tam)
# ------------------------------------------------------------
rl_scan_dir:
    addiu $sp, $sp, -40
    sw   $ra, 32($sp)
    sw   $s7, 28($sp)
    sw   $s6, 24($sp)
    sw   $s5, 20($sp)
    sw   $s4, 16($sp)
    sw   $s3, 12($sp)
    sw   $s2, 8($sp)
    sw   $s1, 4($sp)
    sw   $s0, 0($sp)

    move $s6, $a2                # append
    li   $s7, 0                  # found = 0

    # huong -> (drow, dcol)
    li   $s2, 1
    slti $t0, $a1, 2
    beqz $t0, rsd_dr_ok
    li   $s2, -1                 # huong 0,1: len
rsd_dr_ok:
    andi $t0, $a1, 1
    sll  $t0, $t0, 1
    addiu $s3, $t0, -1           # huong chan: dcol=-1, huong le: dcol=+1

    # quan o o xuat phat
    move $s5, $a0                # o xuat phat (tam)
    jal  get_piece
    beqz $v0, rsd_ret            # o trong -> khong co gi
    move $s4, $v0                # loai quan (tam)
    move $a0, $s5
    jal  sq_to_rowcol
    move $s0, $v0
    move $s1, $v1
    move $s5, $s4                # s5 = loai quan
    move $a0, $s4
    jal  piece_owner
    move $s4, $v0                # s4 = chu so huu

    # phan loai: vua / quan thuong
    li   $t1, BLACK_KING
    beq  $s5, $t1, rsd_king
    li   $t1, RED_KING
    bne  $s5, $t1, rsd_man
rsd_king:
    lw   $t2, variant_flags
    andi $t2, $t2, FLAG_FLYING_KING
    sltu $s5, $zero, $t2         # s5 = 1 neu vua bay
    j    rsd_go
rsd_man:
    li   $s5, 0                  # quan thuong khong bay
    lw   $t2, variant_flags
    andi $t2, $t2, FLAG_BACKWARD_MAN
    bnez $t2, rsd_go             # bat di/an lui: huong nao cung duoc
    sll  $t3, $s4, 1
    addiu $t3, $t3, -1           # huong tien: den(0) -> -1, do(1) -> +1
    bne  $s2, $t3, rsd_ret       # huong lui khong duoc phep
rsd_go:

    # --- giai doan 1: cac o trong -> nuoc di thuong ---
rsd_step:
    addu $s0, $s0, $s2
    addu $s1, $s1, $s3
    move $a0, $s0
    move $a1, $s1
    jal  rowcol_to_sq
    beqz $v0, rsd_ret            # ra ngoai ban
    sw   $v0, 36($sp)
    move $a0, $v0
    jal  get_piece
    bnez $v0, rsd_blocked
    beqz $s6, rsd_noadd1
    lw   $a0, 36($sp)
    li   $a1, 0
    jal  rl_add_move             # nuoc di thuong
rsd_noadd1:
    beqz $s5, rsd_ret            # khong bay: chi 1 o
    j    rsd_step

    # --- giai doan 2: gap quan -> neu la quan dich thi tim o trong phia sau ---
rsd_blocked:
    move $a0, $v0
    jal  piece_owner
    beq  $v0, $s4, rsd_ret       # quan minh chan duong
rsd_land:
    addu $s0, $s0, $s2
    addu $s1, $s1, $s3
    move $a0, $s0
    move $a1, $s1
    jal  rowcol_to_sq
    beqz $v0, rsd_ret            # het ban co
    sw   $v0, 36($sp)
    move $a0, $v0
    jal  get_piece
    bnez $v0, rsd_ret            # o sau bi chan -> khong an duoc (them)
    li   $s7, 1                  # co nuoc an
    beqz $s6, rsd_ret            # chi kiem tra: du roi
    lw   $a0, 36($sp)
    li   $a1, 1
    jal  rl_add_move             # nuoc an
    beqz $s5, rsd_ret            # khong bay: chi o ngay sau
    j    rsd_land

rsd_ret:
    move $v0, $s7
    lw   $s0, 0($sp)
    lw   $s1, 4($sp)
    lw   $s2, 8($sp)
    lw   $s3, 12($sp)
    lw   $s4, 16($sp)
    lw   $s5, 20($sp)
    lw   $s6, 24($sp)
    lw   $s7, 28($sp)
    lw   $ra, 32($sp)
    addiu $sp, $sp, 40
    jr   $ra

# ------------------------------------------------------------
# rl_gen_moves: $a0 = o chua quan
#   Sinh TAT CA nuoc di cua quan do vao move_count / move_list / move_is_capture
#   (CHUA loc bat buoc an). O trong -> move_count = 0.
# ------------------------------------------------------------
rl_gen_moves:
    addiu $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $s1, 4($sp)
    sw   $s0, 0($sp)
    sw   $zero, move_count
    move $s0, $a0
    li   $s1, 0                  # huong 0..3
rgm_loop:
    bge  $s1, 4, rgm_done
    move $a0, $s0
    move $a1, $s1
    li   $a2, 1                  # append = 1
    jal  rl_scan_dir
    addiu $s1, $s1, 1
    j    rgm_loop
rgm_done:
    lw   $s0, 0($sp)
    lw   $s1, 4($sp)
    lw   $ra, 8($sp)
    addiu $sp, $sp, 12
    jr   $ra

# ------------------------------------------------------------
# rl_piece_has_capture: $a0 = o chua quan -> $v0 = 1 neu quan do con nuoc AN
#   Tinh truc tiep tren ban co, KHONG dong vao move_list / move_count.
# ------------------------------------------------------------
rl_piece_has_capture:
    addiu $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $s1, 4($sp)
    sw   $s0, 0($sp)
    move $s0, $a0
    li   $s1, 0
rph_loop:
    bge  $s1, 4, rph_no
    move $a0, $s0
    move $a1, $s1
    li   $a2, 0                  # append = 0
    jal  rl_scan_dir
    bnez $v0, rph_yes
    addiu $s1, $s1, 1
    j    rph_loop
rph_yes:
    li   $v0, 1
    j    rph_end
rph_no:
    li   $v0, 0
rph_end:
    lw   $s0, 0($sp)
    lw   $s1, 4($sp)
    lw   $ra, 8($sp)
    addiu $sp, $sp, 12
    jr   $ra

# ============================================================
# CAC HAM CHINH
# ============================================================

# ------------------------------------------------------------
# [DONE] get_valid_moves: $a0 = o chua quan
#   Dien vao: move_count, move_list[], move_is_capture[]
#   - Quan thuong: 2 huong tien (+ 2 huong lui neu FLAG_BACKWARD_MAN)
#   - Vua: 4 huong; neu FLAG_FLYING_KING thi di/an nhieu o theo duong cheo
#   - Neu FLAG_FORCE_CAPTURE va chu quan co nuoc an o BAT KY quan nao
#     -> chi giu nuoc an (quan khong co nuoc an thi danh sach rong)
#   O ngoai 1..32 hoac o trong -> move_count = 0.
#   Dung cho: B (highlight tren bitmap), C (che do chon quan bang so)
#   Stack: 16 byte (luu $ra, $s2, $s1, $s0)
# ------------------------------------------------------------
get_valid_moves:
    addiu $sp, $sp, -16
    sw   $ra, 12($sp)
    sw   $s2, 8($sp)
    sw   $s1, 4($sp)
    sw   $s0, 0($sp)

    sw   $zero, move_count       # reset
    move $s0, $a0                # o quan
    blt  $a0, 1, gvm_done
    bgt  $a0, 32, gvm_done
    jal  get_piece
    beqz $v0, gvm_done           # o trong
    move $a0, $v0
    jal  piece_owner
    move $s2, $v0                # chu so huu quan

    # --- co bat buoc an khong? (hoi TRUOC khi sinh nuoc, vi no khong dung move_list) ---
    li   $s1, 0                  # has_capture
    lw   $t0, variant_flags
    andi $t0, $t0, FLAG_FORCE_CAPTURE
    beqz $t0, gvm_gen            # co tat -> khong loc
    move $a0, $s2
    jal  player_has_capture
    move $s1, $v0
gvm_gen:
    move $a0, $s0
    jal  rl_gen_moves
    beqz $s1, gvm_done           # khong phai loc

    # --- loc: chi giu nuoc an, don lai tu dau mang ---
    lw   $t0, move_count
    li   $t1, 0                  # i
    li   $t2, 0                  # write_idx
gvm_filter:
    bge  $t1, $t0, gvm_filter_end
    sll  $t3, $t1, 2
    la   $t4, move_is_capture
    addu $t4, $t4, $t3
    lw   $t5, 0($t4)
    beqz $t5, gvm_filter_next    # khong phai nuoc an -> bo
    la   $t6, move_list
    addu $t6, $t6, $t3
    lw   $t7, 0($t6)             # move_list[i]
    sll  $t8, $t2, 2
    la   $t9, move_list
    addu $t9, $t9, $t8
    sw   $t7, 0($t9)             # move_list[write_idx] = move_list[i]
    la   $t9, move_is_capture
    addu $t9, $t9, $t8
    li   $t5, 1
    sw   $t5, 0($t9)             # move_is_capture[write_idx] = 1
    addiu $t2, $t2, 1
gvm_filter_next:
    addiu $t1, $t1, 1
    j    gvm_filter
gvm_filter_end:
    sw   $t2, move_count
gvm_done:
    lw   $s0, 0($sp)
    lw   $s1, 4($sp)
    lw   $s2, 8($sp)
    lw   $ra, 12($sp)
    addiu $sp, $sp, 16
    jr   $ra

# ------------------------------------------------------------
# [DONE] is_valid_move: $a0 = o xuat phat, $a1 = o dich,
#                       $a2 = chain_only (1 = dang trong chuoi an, chi duoc an)
#   -> $v0 = 1 neu hop le, 0 neu khong
#   -> $v1 = ma loi ERR_* (ERR_NONE neu hop le)
#   Kiem tra theo thu tu:
#     1 o trong 1..32            ERR_OUT_OF_RANGE
#     2 o xuat phat co quan      ERR_EMPTY
#     3 quan cua current_player  ERR_NOT_OWN
#     4 o dich trong             ERR_OCCUPIED
#     5-6 toa do, di cheo        ERR_BAD_DIRECTION
#     7a chain ma di 1 o         ERR_CHAIN_CAPTURE
#     7b huong (quan thuong chi tien, tru FLAG_BACKWARD_MAN; ap dung ca khi an)
#     8-9 khoang cach: thuong 1 hoac 2 (2 = nhay qua quan dich); vua bay: bat ky,
#         tren duong di co dung 1 quan dich (an) hoac khong co quan nao (di thuong)
#     chain ma khong an          ERR_CHAIN_CAPTURE
#     FLAG_FORCE_CAPTURE: di thuong ma con nuoc an   ERR_MUST_CAPTURE
#   Thanh ghi: s0=tu, s1=den, s2=loai quan (sau do: bay?), s3=hang tu/so quan giua,
#              s4=cot tu/o quan giua, s5=dr, s6=dc, s7=chain_only
#   Stack: 40 byte
# ------------------------------------------------------------
is_valid_move:
    addiu $sp, $sp, -40
    sw   $ra, 32($sp)
    sw   $s7, 28($sp)
    sw   $s6, 24($sp)
    sw   $s5, 20($sp)
    sw   $s4, 16($sp)
    sw   $s3, 12($sp)
    sw   $s2, 8($sp)
    sw   $s1, 4($sp)
    sw   $s0, 0($sp)

    move $s0, $a0
    move $s1, $a1
    move $s7, $a2

    # [1] o trong 1..32
    blt  $s0, 1, ivm_range
    bgt  $s0, 32, ivm_range
    blt  $s1, 1, ivm_range
    bgt  $s1, 32, ivm_range

    # [2] o xuat phat co quan
    move $a0, $s0
    jal  get_piece
    move $s2, $v0
    beqz $s2, ivm_empty

    # [3] quan phai la cua nguoi dang di
    move $a0, $s2
    jal  piece_owner
    lw   $t0, current_player
    bne  $v0, $t0, ivm_notown

    # [4] o dich phai trong
    move $a0, $s1
    jal  get_piece
    bnez $v0, ivm_occupied

    # [5] toa do hai o, dr / dc
    move $a0, $s0
    jal  sq_to_rowcol
    move $s3, $v0
    move $s4, $v1
    move $a0, $s1
    jal  sq_to_rowcol
    subu $s5, $v0, $s3           # dr = row2 - row1
    subu $s6, $v1, $s4           # dc = col2 - col1

    # [6] phai di cheo: |dr| == |dc|, khac 0
    move $t0, $s5
    bgez $t0, ivm_abs_r
    subu $t0, $zero, $t0
ivm_abs_r:
    move $t1, $s6
    bgez $t1, ivm_abs_c
    subu $t1, $zero, $t1
ivm_abs_c:
    bne  $t0, $t1, ivm_baddir
    beqz $t0, ivm_baddir         # $t0 = |dr| (giu nguyen den ivm_dist)

    # [7a] dang trong chuoi an ma chi di 1 o
    bne  $t0, 1, ivm_classify
    bnez $s7, ivm_chain_err
ivm_classify:
    # [7b] phan loai quan: vua / quan thuong, vua bay?
    li   $t9, 0                  # t9 = bay?
    li   $t1, BLACK_KING
    beq  $s2, $t1, ivm_king
    li   $t1, RED_KING
    bne  $s2, $t1, ivm_man
ivm_king:
    lw   $t2, variant_flags
    andi $t2, $t2, FLAG_FLYING_KING
    sltu $t9, $zero, $t2         # 1 neu bat vua bay
    j    ivm_dist
ivm_man:
    lw   $t2, variant_flags
    andi $t2, $t2, FLAG_BACKWARD_MAN
    bnez $t2, ivm_dist           # bat di/an lui: khong gioi han huong
    lw   $t3, current_player
    sll  $t3, $t3, 1
    addiu $t3, $t3, -1           # huong tien: den -> -1, do -> +1
    slt  $t4, $zero, $s5         # dr > 0 ?
    sll  $t4, $t4, 1
    addiu $t4, $t4, -1           # dr > 0 -> +1, dr < 0 -> -1
    bne  $t4, $t3, ivm_baddir    # di/an lui khi chua duoc phep

    # [8-9] khoang cach
ivm_dist:
    bnez $t9, ivm_scan           # vua bay: khoang cach bat ky
    bgt  $t0, 2, ivm_baddir      # con lai: chi 1 hoac 2 o
ivm_scan:
    move $s2, $t9                # s2 = bay?
    move $a0, $s0
    move $a1, $s1
    jal  rl_path_info            # $v0 = so quan o giua, $v1 = o quan cuoi cung
    move $s3, $v0
    move $s4, $v1
    bgt  $s3, 1, ivm_baddir      # nhay qua tu 2 quan tro len
    beqz $s3, ivm_nocap

    # co dung 1 quan o giua: phai la quan doi phuong -> day la nuoc AN
    move $a0, $s4
    jal  get_piece
    move $a0, $v0
    jal  piece_owner
    lw   $t0, current_player
    beq  $v0, $t0, ivm_baddir    # quan minh -> khong nhay qua duoc
    j    ivm_ok

ivm_nocap:
    # khong co quan o giua: di thuong
    bnez $s2, ivm_plain          # vua bay: di thuong bat ky khoang cach
    move $t0, $s5
    bgez $t0, ivm_abs_n
    subu $t0, $zero, $t0
ivm_abs_n:
    bne  $t0, 1, ivm_baddir      # nhay 2 o ma khong an gi -> sai
ivm_plain:
    bnez $s7, ivm_chain_err      # dang chain: bat buoc phai an tiep
    lw   $t0, variant_flags
    andi $t0, $t0, FLAG_FORCE_CAPTURE
    beqz $t0, ivm_ok
    lw   $a0, current_player
    jal  player_has_capture
    bnez $v0, ivm_must_cap       # con nuoc an ma di thuong -> bi cam

ivm_ok:
    li   $v0, 1
    li   $v1, ERR_NONE
    j    ivm_end

ivm_range:
    li   $v1, ERR_OUT_OF_RANGE
    j    ivm_fail
ivm_empty:
    li   $v1, ERR_EMPTY
    j    ivm_fail
ivm_notown:
    li   $v1, ERR_NOT_OWN
    j    ivm_fail
ivm_occupied:
    li   $v1, ERR_OCCUPIED
    j    ivm_fail
ivm_baddir:
    li   $v1, ERR_BAD_DIRECTION
    j    ivm_fail
ivm_must_cap:
    li   $v1, ERR_MUST_CAPTURE
    j    ivm_fail
ivm_chain_err:
    li   $v1, ERR_CHAIN_CAPTURE
ivm_fail:
    li   $v0, 0
ivm_end:
    lw   $s0, 0($sp)
    lw   $s1, 4($sp)
    lw   $s2, 8($sp)
    lw   $s3, 12($sp)
    lw   $s4, 16($sp)
    lw   $s5, 20($sp)
    lw   $s6, 24($sp)
    lw   $s7, 28($sp)
    lw   $ra, 32($sp)
    addiu $sp, $sp, 40
    jr   $ra

# ------------------------------------------------------------
# [DONE] apply_move: $a0 = o xuat phat, $a1 = o dich (da duoc kiem tra hop le)
#   -> $v0 = 1 neu vua an quan, 0 neu di thuong
#   -> $v1 = 1 neu vua phong vua
#   Viec lam: xoa quan bi an tren duong di (o giua; vua bay co the o xa hon),
#   di chuyen quan, phong vua (den: hang 0, do: hang 7). Khong doi luot o day.
#   Stack: 24 byte (luu $ra, $s4, $s3, $s2, $s1, $s0)
#   s0=tu, s1=den, s2=loai quan, s3=da an?, s4=da phong vua?
# ------------------------------------------------------------
apply_move:
    addiu $sp, $sp, -24
    sw   $ra, 20($sp)
    sw   $s4, 16($sp)
    sw   $s3, 12($sp)
    sw   $s2, 8($sp)
    sw   $s1, 4($sp)
    sw   $s0, 0($sp)

    move $s0, $a0
    move $s1, $a1
    li   $s3, 0                  # chua an
    li   $s4, 0                  # chua phong vua

    # [1] xoa quan bi an (neu co) tren duong tu o xuat phat toi o dich
    move $a0, $s0
    move $a1, $s1
    jal  rl_path_info            # $v0 = so quan o giua, $v1 = o cua quan do
    beqz $v0, apm_move
    move $a0, $v1
    li   $a1, EMPTY
    jal  set_piece               # xoa quan bi an
    li   $s3, 1

    # [2] di chuyen quan
apm_move:
    move $a0, $s0
    jal  get_piece
    move $s2, $v0                # loai quan
    move $a0, $s1
    move $a1, $s2
    jal  set_piece               # dat vao o dich
    move $a0, $s0
    li   $a1, EMPTY
    jal  set_piece               # xoa o xuat phat

    # [3] phong vua
    move $a0, $s1
    jal  sq_to_rowcol            # $v0 = hang o dich
    li   $t0, BLACK_MAN
    bne  $s2, $t0, apm_chk_red
    bnez $v0, apm_done           # den phai den hang 0
    li   $a1, BLACK_KING
    j    apm_promote
apm_chk_red:
    li   $t0, RED_MAN
    bne  $s2, $t0, apm_done
    li   $t1, 7
    bne  $v0, $t1, apm_done      # do phai den hang 7
    li   $a1, RED_KING
apm_promote:
    move $a0, $s1
    jal  set_piece
    li   $s4, 1
apm_done:
    move $v0, $s3
    move $v1, $s4

    lw   $s0, 0($sp)
    lw   $s1, 4($sp)
    lw   $s2, 8($sp)
    lw   $s3, 12($sp)
    lw   $s4, 16($sp)
    lw   $ra, 20($sp)
    addiu $sp, $sp, 24
    jr   $ra

# ------------------------------------------------------------
# [DONE] can_chain: $a0 = o quan vua nhay xong -> $v0 = 1 neu con nuoc an tiep
#   Tinh truc tiep tren ban co (KHONG dung move_list / move_count) theo dung
#   loai quan dang dung o do: quan thuong 2 huong tien (4 huong neu
#   FLAG_BACKWARD_MAN), vua 4 huong (bay neu FLAG_FLYING_KING).
#   Neu vua phong vua trong luot an thi o do da la vua -> an lui tiep duoc.
#   (Dung chung rl_piece_has_capture.)
# ------------------------------------------------------------
can_chain:
    j    rl_piece_has_capture

# ------------------------------------------------------------
# [DONE] player_has_capture: $a0 = nguoi choi -> $v0 = 1 neu co bat ky nuoc an
#   Dung cho FLAG_FORCE_CAPTURE
#   Stack: 12 byte (luu $ra, $s1, $s0)
# ------------------------------------------------------------
player_has_capture:
    addiu $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $s1, 4($sp)
    sw   $s0, 0($sp)
    move $s1, $a0                # nguoi choi can kiem tra
    li   $s0, 1                  # o 1..32
phc_loop:
    bgt  $s0, 32, phc_no
    move $a0, $s0
    jal  get_piece
    beqz $v0, phc_next           # o trong
    move $a0, $v0
    jal  piece_owner
    bne  $v0, $s1, phc_next      # khong phai quan cua nguoi do
    move $a0, $s0
    jal  rl_piece_has_capture
    bnez $v0, phc_yes
phc_next:
    addiu $s0, $s0, 1
    j    phc_loop
phc_yes:
    li   $v0, 1
    j    phc_end
phc_no:
    li   $v0, 0
phc_end:
    lw   $s0, 0($sp)
    lw   $s1, 4($sp)
    lw   $ra, 8($sp)
    addiu $sp, $sp, 12
    jr   $ra

# ------------------------------------------------------------
# [DONE] player_has_any_move: $a0 = nguoi choi -> $v0 = 1 neu con nuoc di nao do
#   (dung cho dieu kien thua do bi chan het duong)
#   Neu bat FLAG_FORCE_CAPTURE: co nuoc an thi nuoc an cung la nuoc di, khong
#   co nuoc an thi moi nuoc di thuong deu hop le -> dung danh sach chua loc la du.
#   Stack: 12 byte (luu $ra, $s1, $s0)
# ------------------------------------------------------------
player_has_any_move:
    addiu $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $s1, 4($sp)
    sw   $s0, 0($sp)
    move $s1, $a0
    li   $s0, 1
pham_loop:
    bgt  $s0, 32, pham_no_move
    move $a0, $s0
    jal  get_piece
    beqz $v0, pham_next
    move $a0, $v0
    jal  piece_owner
    bne  $v0, $s1, pham_next
    move $a0, $s0
    jal  rl_gen_moves            # ghi vao move_count
    lw   $t0, move_count
    bgtz $t0, pham_found         # co nuoc di -> tra ve 1 ngay
pham_next:
    addiu $s0, $s0, 1
    j    pham_loop
pham_found:
    li   $v0, 1
    j    pham_end
pham_no_move:
    li   $v0, 0
pham_end:
    lw   $s0, 0($sp)
    lw   $s1, 4($sp)
    lw   $ra, 8($sp)
    addiu $sp, $sp, 12
    jr   $ra

# ------------------------------------------------------------
# [DONE] check_winner: kiem tra theo current_player (nguoi sap di)
#   -> $v0 = -1 neu chua ket thuc
#           PLAYER_BLACK / PLAYER_RED = nguoi thang
#   Het quan HOAC khong con nuoc di -> nguoi kia thang
#   Stack: 20 byte (luu $ra, $s2, $s1, $s0) - dung 24 cho can bang
# ------------------------------------------------------------
check_winner:
    addiu $sp, $sp, -24
    sw   $ra, 20($sp)
    sw   $s3, 16($sp)
    sw   $s2, 12($sp)
    sw   $s1, 8($sp)
    sw   $s0, 4($sp)

    li   $s0, 0                  # black_count
    li   $s1, 0                  # red_count
    li   $s2, 1                  # o 1..32
cw_count:
    bgt  $s2, 32, cw_counted
    move $a0, $s2
    jal  get_piece
    beqz $v0, cw_cnext
    move $a0, $v0
    jal  piece_owner
    li   $t0, PLAYER_BLACK
    beq  $v0, $t0, cw_is_black
    addiu $s1, $s1, 1            # quan do
    j    cw_cnext
cw_is_black:
    addiu $s0, $s0, 1            # quan den
cw_cnext:
    addiu $s2, $s2, 1
    j    cw_count
cw_counted:
    beqz $s1, cw_black_wins      # Do het quan -> Den thang
    beqz $s0, cw_red_wins        # Den het quan -> Do thang

    lw   $s3, current_player
    move $a0, $s3
    jal  player_has_any_move
    beqz $v0, cw_blocked         # nguoi sap di bi chan het duong
    li   $v0, -1                 # chua ket thuc
    j    cw_end
cw_black_wins:
    li   $v0, PLAYER_BLACK
    j    cw_end
cw_red_wins:
    li   $v0, PLAYER_RED
    j    cw_end
cw_blocked:
    xori $v0, $s3, 1             # nguoi kia thang
cw_end:
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    lw   $s2, 12($sp)
    lw   $s3, 16($sp)
    lw   $ra, 20($sp)
    addiu $sp, $sp, 24
    jr   $ra