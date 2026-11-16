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
msg_menu_hdr:     .asciiz "=== CO CHECKERS MIPS ===\n"
msg_menu_1:       .asciiz "Bat buoc an quan? (1=Co, 0=Khong): "
msg_menu_2:       .asciiz "Vua bay nhieu o?  (1=Co, 0=Khong): "
msg_menu_3:       .asciiz "Tot di/an lui?    (1=Co, 0=Khong): "
msg_play_again:   .asciiz "Choi lai? (1=Co, 0=Thoat): "

msg_black_turn:   .asciiz "Black's turn.\n"
msg_red_turn:     .asciiz "Red's turn.\n"
msg_enter_start:  .asciiz "Enter starting square: "
msg_enter_land:   .asciiz "Enter landing square: "
msg_invalid:      .asciiz "Not a valid move! Try again.\n"
msg_captured:     .asciiz "Captured opponent's piece.\n"
msg_chaining:     .asciiz "Chaining possible.\n"
msg_black_wins:   .asciiz "Black wins!\n"
msg_red_wins:     .asciiz "Red wins!\n"

msg_err_range:    .asciiz "Loi: So o phai trong khoang 1-32!\n"
msg_err_empty:    .asciiz "Loi: O xuat phat khong co quan!\n"
msg_err_not_own:  .asciiz "Loi: Khong phai quan cua ban!\n"
msg_err_occ:      .asciiz "Loi: O dich da co quan!\n"
msg_err_dir:      .asciiz "Loi: Huong di hoac khoang cach sai!\n"
msg_err_capture:  .asciiz "Loi: Bat buoc phai an quan!\n"
msg_err_chain:    .asciiz "Loi: Phai nhay an tiep!\n"

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
    # TODO: che do chon quan bang so:
    #       nhap so o -> selected_square, ve highlight; nhap -1 de bo chon;
    #       nhap so o dich (nam trong move_list) de di

ask_move:
ask_start:
    # [C.1b] Nhap o xuat phat + kich hoat highlight tren Bitmap
    print_str(msg_enter_start)
    read_int
    move $s0, $v0                    # o xuat phat
    sw   $s0, selected_square        # kich hoat highlight cho B
    lw   $a0, current_player
    jal  draw_board                  # ve lai: Bitmap hien highlight

ask_land:
    print_str(msg_enter_land)
    read_int
    move $s1, $v0                    # o dich

    li   $t0, -1
    sw   $t0, selected_square        # reset highlight truoc khi validate

    move $a0, $s0
    move $a1, $s1
    li   $a2, 0                      # khong phai chuoi an
    jal  is_valid_move
    beqz $v0, bad_move               # [C.1d] in thong bao theo ma loi $v1 (ERR_*)

    move $a0, $s0
    move $a1, $s1
    jal  apply_move
    beqz $v0, end_turn               # di thuong -> het luot

chain_check:
    print_str(msg_captured)

    # Phong Vua khi dang an: KHONG ket thuc luot (de bai muc 1.2.4, Hinh 8).
    # apply_move da doi quan thanh KING, nen can_chain ben duoi se tu xet
    # ca 4 huong (an lui) cho quan vua len Vua.

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
bad_move:
    li   $t0, -1
    sw   $t0, selected_square        # reset highlight khi loi
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
    lw   $t0, current_player
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

.include "rules.asm"
.include "display.asm"
