# ============================================================
# main.asm - NGUOI C: vong lap game, nhap lieu (file CHAY CHINH)
#
# Cach chay trong MARS:
#   1. Mo main.asm
#   2. Settings > "Initialize Program Counter to global 'main' if defined" (tich)
#   3. Settings > "Assemble all files in directory" (tich) HOAC giu nguyen .include
#      o cuoi file nay (cach hien tai) - dung ca hai cung luc se bi trung nhan
#   4. Tools > Bitmap Display (xem display.asm), Connect, roi Assemble + Run
# ============================================================
.include "common.asm"

.data
msg_menu_hdr:     .asciiz "=== MIPS CHECKERS GAME ===\n"
msg_menu_1:       .asciiz "Force capture? (1=Yes, 0=No): "
msg_menu_2:       .asciiz "Flying kings?  (1=Yes, 0=No): "
msg_menu_3:       .asciiz "Pawns move/capture backward? (1=Yes, 0=No): "
msg_play_again:   .asciiz "Play again? (1=Yes, 0=Exit): "

msg_black_turn:   .asciiz "Black's turn.\n"
msg_red_turn:     .asciiz "Red's turn.\n"
msg_enter_start:  .asciiz "Enter starting square: "
msg_enter_land:   .asciiz "Enter landing square: "
msg_invalid:      .asciiz "Not a valid move! Try again.\n"
msg_captured:     .asciiz "Captured opponent's piece.\n"
msg_chaining:     .asciiz "Chaining possible.\n"
msg_black_wins:   .asciiz "Black wins!\n"
msg_red_wins:     .asciiz "Red wins!\n"

msg_err_range:    .asciiz "Error: Square must be between 1 and 32!\n"
msg_err_empty:    .asciiz "Error: Starting square has no piece!\n"
msg_err_not_own:  .asciiz "Error: Piece does not belong to you!\n"
msg_err_occ:      .asciiz "Error: Destination square is already occupied!\n"
msg_err_dir:      .asciiz "Error: Invalid direction or distance!\n"
msg_err_capture:  .asciiz "Error: Forced capture is in effect!\n"
msg_err_chain:    .asciiz "Error: Must continue the capture chain!\n"
msg_err_nomove:   .asciiz "Error: This piece has no valid moves!\n"
msg_err_input:    .asciiz "Invalid input! Please enter an integer: "

msg_draw_offered: .asciiz "You offered a draw. Opponent accepts by entering 0 on their turn.\n"
msg_draw_pending: .asciiz "Opponent offers a draw. Enter 0 to accept, or make a move to decline.\n"
msg_draw_already: .asciiz "You have already offered a draw.\n"
msg_draw:         .asciiz "Draw agreed. The game is a draw!\n"

input_buf:        .space 64
.text
.globl main
main:
    jal  init_board
    sw   $zero, current_player       # den di truoc
    sw   $zero, variant_flags

    # [C.3] Menu chon Variant
    print_str(msg_menu_hdr)
    print_str(msg_menu_1)
    read_int
    beqz $v0, menu2
    lw   $t0, variant_flags
    ori  $t0, $t0, FLAG_FORCE_CAPTURE
    sw   $t0, variant_flags
menu2:
    print_str(msg_menu_2)
    read_int
    beqz $v0, menu3
    lw   $t0, variant_flags
    ori  $t0, $t0, FLAG_FLYING_KING
    sw   $t0, variant_flags
menu3:
    print_str(msg_menu_3)
    read_int
    beqz $v0, menu_done
    lw   $t0, variant_flags
    ori  $t0, $t0, FLAG_BACKWARD_MAN
    sw   $t0, variant_flags
menu_done:
    j    game_loop

game_loop:
    # [C.1a] Xoay ban co theo luot nguoi choi hien tai
    lw   $a0, current_player
    jal  draw_board
    jal  check_winner
    bgez $v0, game_over              # $v0 = -1: chua ket thuc
    lw   $t0, current_player
    bnez $t0, show_red
    print_str(msg_black_turn)
    j    ask_move
show_red:
    print_str(msg_red_turn)

    # TODO: cho phep cau hoa (hoi nguoi choi, ghi draw_offer_*, ca hai dong y -> hoa)

# ------------------------------------------------------------
# Vong nhap kieu chon quan bang so
#   selected_square = -1 : chua chon quan -> hoi "Enter starting square"
#   selected_square >= 1 : dang chon quan -> hoi "Enter landing square"
#     - nhap -1            : bo chon
#     - nhap o quan cung phe: doi quan chon
#     - nhap so khac       : coi nhu o dich -> is_valid_move
#   Thanh ghi: $s0 = o dang chon, $s2 = so vua nhap
# ------------------------------------------------------------
ask_move:
    li   $t0, -1
    sw   $t0, selected_square        # luot moi: chua chon quan

    lw   $t0, current_player
    bnez $t0, pend_red_turn
    lw   $t1, draw_offer_red         # luot Den: xem Do co cau hoa khong
    j    pend_check
pend_red_turn:
    lw   $t1, draw_offer_black       # luot Do: xem Den co cau hoa khong
pend_check:
    beqz $t1, ask_start
    print_str(msg_draw_pending)
ask_start:
    lw   $t0, selected_square
    bltz $t0, prompt_select
    print_str(msg_enter_land)
    j    read_cmd
prompt_select:
    print_str(msg_enter_start)
read_cmd:
    read_int
    move $s2, $v0                    # so vua nhap
    lw   $s0, selected_square        # o dang chon (-1 neu chua)
    bgez $s0, have_selected
    beqz $s2, draw_offer
    j do_select
have_selected:
    # --- dang chon quan ---
    li   $t0, -1
    beq  $s2, $t0, do_deselect
    blt  $s2, 1, do_move             # ngoai khoang -> de is_valid_move bao loi
    bgt  $s2, 32, do_move
    move $a0, $s2
    jal  get_piece
    beqz $v0, do_move                # o trong -> la o dich
    move $a0, $v0
    jal  piece_owner
    lw   $t0, current_player
    beq  $v0, $t0, do_select         # quan cung phe -> doi quan chon
    j    do_move                     # quan doi thu -> is_valid_move bao ERR_OCCUPIED

draw_offer:
    lw   $t0, current_player
    bnez $t0, draw_offer_by_red
    lw   $t1, draw_offer_red
    bnez $t1, game_draw              # Do da cau hoa truoc -> hoa
    lw   $t2, draw_offer_black
    bnez $t2, draw_offer_dup
    li   $t2, 1
    sw   $t2, draw_offer_black
    print_str(msg_draw_offered)
    j    ask_start
draw_offer_by_red:
    lw   $t1, draw_offer_black
    bnez $t1, game_draw              # Den da cau hoa truoc -> hoa
    lw   $t2, draw_offer_red
    bnez $t2, draw_offer_dup
    li   $t2, 1
    sw   $t2, draw_offer_red
    print_str(msg_draw_offered)
    j    ask_start
draw_offer_dup:
    print_str(msg_draw_already)
    j    ask_start

game_draw:
    print_str(msg_draw)
    j    go_ask
do_deselect:
    li   $t0, -1
    sw   $t0, selected_square
    lw   $a0, current_player
    jal  draw_board                  # xoa highlight
    j    ask_start

do_select:
    blt  $s2, 1, sel_err_range
    bgt  $s2, 32, sel_err_range
    move $a0, $s2
    jal  get_piece
    beqz $v0, sel_err_empty
    move $a0, $v0
    jal  piece_owner
    lw   $t0, current_player
    bne  $v0, $t0, sel_err_own
    move $a0, $s2
    jal  get_valid_moves             # da loc theo FLAG_FORCE_CAPTURE
    lw   $t0, move_count
    beqz $t0, sel_err_nomove
    sw   $s2, selected_square
    lw   $a0, current_player
    jal  draw_board                  # Bitmap hien highlight
    j    ask_start
sel_err_range:
    print_str(msg_err_range)
    j    ask_start
sel_err_empty:
    print_str(msg_err_empty)
    j    ask_start
sel_err_own:
    print_str(msg_err_not_own)
    j    ask_start
sel_err_nomove:
    print_str(msg_err_nomove)
    j    ask_start

do_move:
    move $a0, $s0                    # o dang chon
    move $a1, $s2                    # o dich
    li   $a2, 0                      # khong phai chuoi an
    jal  is_valid_move
    beqz $v0, bad_move               # [C.1d] in thong bao theo ma loi $v1 (ERR_*)
    move $s1, $s2                    # chain_check dung $s1 = o dich
    li   $t0, -1
    sw   $t0, selected_square        # da di: bo chon
    move $a0, $s0
    move $a1, $s1
    jal  apply_move
    beqz $v0, end_turn               # di thuong -> het luot

chain_check:
    print_str(msg_captured)

    # Phong Vua khi dang an: KHONG ket thuc luot (de bai muc 1.2.4, Hinh 8).
    # apply_move da doi quan thanh KING, nen can_chain ben duoi tu xet ca 4 huong
    # (an lui) cho quan vua len Vua.

    # [C.1c] Highlight o hien tai truoc khi hoi nuoc tiep
    sw   $s1, selected_square
    li   $t0, 1
    sw   $t0, hl_capture_only        # chi highlight nuoc an trong chuoi chain
    lw   $a0, current_player
    jal  draw_board                  # Bitmap to mau o dang chain

    move $a0, $s1                    # quan dang dung o o dich
    jal  can_chain
    beqz $v0, chain_done_highlight

chain_done_highlight:
    li   $t0, -1
    sw   $t0, selected_square        # reset highlight
    sw   $zero, hl_capture_only

    beqz $v0, end_turn
    print_str(msg_chaining)
    print_str(msg_enter_land)
    read_int
    move $s0, $s1                    # o xuat phat cua nhay tiep
    move $s2, $v0                    # o dich moi
chain_try:
    move $a0, $s0
    move $a1, $s2
    li   $a2, 1                      # bat buoc la nuoc an
    jal  is_valid_move
    beqz $v0, chain_bad
    move $s1, $s2
    move $a0, $s0
    move $a1, $s1
    jal  apply_move
    j    chain_check
chain_bad:
    print_str(msg_invalid)
    print_str(msg_enter_land)
    read_int
    move $s2, $v0
    j    chain_try

# [C.1d] In ma loi $v1 chi tiet
# KHONG reset selected_square o day: giu nguyen quan dang chon de nhap lai o dich.
bad_move:
    beq  $v1, ERR_OUT_OF_RANGE,  bm_range
    beq  $v1, ERR_EMPTY,         bm_empty
    beq  $v1, ERR_NOT_OWN,       bm_not_own
    beq  $v1, ERR_OCCUPIED,      bm_occ
    beq  $v1, ERR_BAD_DIRECTION, bm_dir
    beq  $v1, ERR_MUST_CAPTURE,  bm_capture
    beq  $v1, ERR_CHAIN_CAPTURE, bm_chain
    print_str(msg_invalid)
    j    ask_start
bm_range:
    print_str(msg_err_range)
    j    ask_start
bm_empty:
    print_str(msg_err_empty)
    j    ask_start
bm_not_own:
    print_str(msg_err_not_own)
    j    ask_start
bm_occ:
    print_str(msg_err_occ)
    j    ask_start
bm_dir:
    print_str(msg_err_dir)
    j    ask_start
bm_capture:
    print_str(msg_err_capture)
    j    ask_start
bm_chain:
    print_str(msg_err_chain)
    j    ask_start

end_turn:
    # Offer cau hoa chi co hieu luc 1 luot: neu nguoi choi hien tai di quan
    # (khong chap nhan hoa) thi huy offer cau hoa dang cho cua doi thu.
    lw   $t0, current_player
    bnez $t0, et_clear_black
    sw   $zero, draw_offer_red       # Den da di -> huy offer cua Do (neu co)
    j    et_switch
et_clear_black:
    sw   $zero, draw_offer_black     # Do da di -> huy offer cua Den (neu co)
et_switch:
    xori $t0, $t0, 1                 # doi luot
    sw   $t0, current_player
    j    game_loop

# [C.3] Ket thuc game + hoi choi lai (Restart)
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
    # Reset toan bo trang thai:
    jal  init_board
    sw   $zero, current_player
    sw   $zero, variant_flags
    li   $t0, -1
    sw   $t0, selected_square
    sw   $zero, draw_offer_black
    sw   $zero, draw_offer_red
    sw   $zero, hl_capture_only
    j    main                        # quay ve menu chon Variant lai

exit_game:
    li   $v0, 10
    syscall

# ------------------------------------------------------------
# read_int_safe: doc so nguyen bang syscall 8 (read_string)
#   - Bo qua khoang trang dau/cuoi (' ', '\t', '\r')
#   - Neu nhap rong, chi co khoang trang, ky tu la, hoac qua dai:
#     in thong bao loi va yeu cau nhap lai (khong dung game)
#   - Tra ve: $v0 = so nguyen hop le
#   - Chi dung $a0, $a1, $v0, $t0-$t5 (giu nguyen $s0-$s7)
# ------------------------------------------------------------
read_int_safe:
ris_loop:
    la   $a0, input_buf
    li   $a1, 64
    li   $v0, 8                      # syscall read_string
    syscall

    la   $t0, input_buf
    li   $t2, 0                      # acc = 0
    li   $t3, 0                      # neg = 0
    li   $t4, 0                      # has_digit = 0

ris_skip_ws:
    lbu  $t1, 0($t0)
    beq  $t1, 32, ris_ws_next        # ' '
    beq  $t1, 9,  ris_ws_next        # '\t'
    beq  $t1, 13, ris_ws_next        # '\r'
    j    ris_check_sign
ris_ws_next:
    addiu $t0, $t0, 1
    j    ris_skip_ws

ris_check_sign:
    beq  $t1, 45, ris_neg            # '-'
    beq  $t1, 43, ris_pos            # '+'
    j    ris_digits
ris_neg:
    li   $t3, 1
    addiu $t0, $t0, 1
    j    ris_digits
ris_pos:
    addiu $t0, $t0, 1

ris_digits:
    lbu  $t1, 0($t0)
    blt  $t1, 48, ris_after_digits   # < '0'
    bgt  $t1, 57, ris_after_digits   # > '9'
    li   $t5, 100000000
    bgt  $t2, $t5, ris_invalid       # tranh tran so 32-bit
    sll  $t5, $t2, 3                 # acc * 8
    sll  $t2, $t2, 1                 # acc * 2
    addu $t2, $t2, $t5               # acc = acc * 10
    addiu $t1, $t1, -48              # c - '0'
    addu $t2, $t2, $t1
    li   $t4, 1                      # da doc it nhat 1 chu so
    addiu $t0, $t0, 1
    j    ris_digits

ris_after_digits:
    beqz $t4, ris_invalid            # khong co chu so nao

ris_skip_trail:
    lbu  $t1, 0($t0)
    beqz $t1, ris_done               # '\0'
    beq  $t1, 10, ris_done           # '\n'
    beq  $t1, 32, ris_trail_next     # ' '
    beq  $t1, 9,  ris_trail_next     # '\t'
    beq  $t1, 13, ris_trail_next     # '\r'
    j    ris_invalid                 # ky tu khong hop le sau so
ris_trail_next:
    addiu $t0, $t0, 1
    j    ris_skip_trail

ris_done:
    beqz $t3, ris_ret
    subu $t2, $zero, $t2             # doi dau neu am
ris_ret:
    move $v0, $t2
    jr   $ra

ris_invalid:
    print_str(msg_err_input)
    j    ris_loop

.include "rules.asm"
.include "display.asm"
