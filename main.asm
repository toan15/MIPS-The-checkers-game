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
msg_black_turn:   .asciiz "Black's turn.\n"
msg_red_turn:     .asciiz "Red's turn.\n"
msg_enter_start:  .asciiz "Enter starting square: "
msg_enter_land:   .asciiz "Enter landing square: "
msg_invalid:      .asciiz "Not a valid move! Try again.\n"
msg_captured:     .asciiz "Captured opponent's piece.\n"
msg_chaining:     .asciiz "Chaining possible.\n"
msg_black_wins:   .asciiz "Black wins!\n"
msg_red_wins:     .asciiz "Red wins!\n"

.text
.globl main
main:
    jal  init_board
    sw   $zero, current_player       # den di truoc
    sw   $zero, variant_flags        # TODO: menu chon variant (FLAG_*)
    # TODO: hoi restart khi game ket thuc

game_loop:
    li   $a0, 0                      # TODO: truyen current_player de xoay ban co
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
    print_str(msg_enter_start)
    read_int
    move $s0, $v0                    # o xuat phat
    print_str(msg_enter_land)
    read_int
    move $s1, $v0                    # o dich

    move $a0, $s0
    move $a1, $s1
    li   $a2, 0                      # khong phai chuoi an
    jal  is_valid_move
    beqz $v0, bad_move               # TODO: in thong bao theo ma loi $v1 (ERR_*)

    move $a0, $s0
    move $a1, $s1
    jal  apply_move
    beqz $v0, end_turn               # di thuong -> het luot

chain_check:
    print_str(msg_captured)
    li   $a0, 0
    jal  draw_board
    move $a0, $s1                    # quan dang dung o o dich
    jal  can_chain
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

bad_move:
    print_str(msg_invalid)
    j    ask_move

end_turn:
    lw   $t0, current_player
    xori $t0, $t0, 1                 # doi luot
    sw   $t0, current_player
    j    game_loop

game_over:
    beqz $v0, black_wins
    print_str(msg_red_wins)
    j    exit_game
black_wins:
    print_str(msg_black_wins)
exit_game:
    li   $v0, 10
    syscall

.include "rules.asm"
.include "display.asm"
