### syscall constants
PRINT_STRING            = 4
PRINT_CHAR              = 11
PRINT_INT               = 1

### MMIO addrs
ANGLE                   = 0xffff0014
ANGLE_CONTROL           = 0xffff0018
VELOCITY                = 0xffff0010
LOCK_SLAB               = 0xffff2000;
UNLOCK_SLAB             = 0xffff2004;
GET_SLABS		= 0xffff200c

BOT_X                   = 0xffff0020
BOT_Y                   = 0xffff0024
OTHER_X                 = 0xffff00a0
OTHER_Y                 = 0xffff00a4

REQUEST_PUZZLE          = 0xffff00d0  ## Puzzle
AVAIL_PUZZLES           = 0xffff00d4  ## Puzzle
CURRENT_PUZZLE          = 0xffff00d8  ## Puzzle
PUZZLE_FEEDBACK         = 0xffff00e0  ## Puzzle
SUBMIT_SOLUTION         = 0xffff00e4  ## Puzzle
	
TIMER                   = 0xffff001c
GET_MAP                 = 0xffff2008

FOLLOW			= 0xffff2010	
	
FEEDBACK_INT_MASK       = 0x0800      ## Feedback
FEEDBACK_ACK            = 0xffff00e8  ## Feedback
BONK_INT_MASK           = 0x1000      ## Bonk
BONK_ACK                = 0xffff0060  ## Bonk
TIMER_INT_MASK          = 0x8000      ## Timer
TIMER_ACK               = 0xffff006c  ## Timer
FOLLOW_INT_MASK         = 0x0400      ## Timer
FOLLOW_ACK              = 0xffff00f4  ## Timer
	
MMIO_STATUS             = 0xffff204c
GET_ENERGY	 	= 0xffff2014

.data

# // Stuff to put into the data segment
# struct wordle_feedback_t feedbacks[6];
# wordle_state_t state;
# char feedback_received = 0;  // guess_received: .byte 0

feedbacks: .space 96            # 6 * 16 bytes
state: .space 100               # 100 bytes
slab_info: .space 84            # 84 byte struct to store slab_info_t
last_word_checked: .word 0
feedback_received: .byte 0

# If you want, you can use the following to detect if a bonk has happened.
has_bonked: .byte 0

.text
main:

    # enable interrupts
    li      $t4     1
    or      $t4     $t4     TIMER_INT_MASK
    or      $t4,    $t4,    BONK_INT_MASK               # enable bonk interrupt
    or      $t4,    $t4,    FEEDBACK_INT_MASK           # enable feedback interrupt
    or      $t4,    $t4,    1 # global enable
    mtc0    $t4     $12

    li $t1, 0
    sw $t1, ANGLE
    li $t1, 1
    sw $t1, ANGLE_CONTROL
    li $t2, 0
    sw $t2, VELOCITY

    # YOUR CODE GOES HERE!!!!!!

    # master plan to just qualify
    # get list of all the slabs
    # iterate through them one by one pushing them to the other side

    li  $s0, 0                  # s0 holds the current slab we're trying to push
unlocking_loop:
    
    # load information about slabs
    la  $s2, slab_info          # s2 stores address of slab_info
    sw  $s2, GET_SLABS

    add $s2, $s2, 4             # skip over length
    mul $t1, $s0, 4             # find address of slab_info.metadata[i]
    add $s2, $s2, $t1           # s2 is now address of slab_info.metadata[i]

    # check if slab is on the right side already
    # if this is the case, we don't need to push this slab
    lbu $t1, 1($s2)
    bgt $t1, 20, unlocking_loop_end

    # check if slab is locked
    # if so, while we don't have enough energy, solve puzzles
    lbu $t1, 2($s2)             # loads owner + locked into t1
    and $t2, $t1, 1             # t2 stores owner
    and $t3, $t1, 2             # t3 stores locked

    beq $t3, 0, unlocking_loop_end      # if the slab is not locked, don't need to unlock
    beq $t2, 0, unlocking_loop_end      # if we own it already, don't need to unlock

    # check if we have enough energy
unlocking_get_energy_loop:
    lw  $t4, GET_ENERGY                 # load the current amount of energy we have into t4
    bgt $t4, 100, unlocking_get_energy_loop_end   # stop solving puzzles if more than 100 energy

    move $a0, $s1               # call solve_puzzle(s1)
    jal solve_puzzle
    add $s1, $s1, 1             # increment s1 to the next puzzle

    j   unlocking_get_energy_loop

unlocking_get_energy_loop_end:
    # unlock the slab
    sw  $s0, UNLOCK_SLAB

unlocking_loop_end:
    add $s0, $s0, 1             # increment s0 to check the next slab next loop
    la  $t0, slab_info          # load slab_info.length into t0
    lw  $t0, 0($t0)
    blt $s0, $t0, unlocking_loop    # loop if s0 < len

    li  $s0, 0                  # s0 holds the current slab we're trying to push
    li  $s1, 0                  # s1 holds the index of the next puzzle to solve
main_loop:

    # load information about slabs
    la  $s2, slab_info          # s2 stores address of slab_info
    sw  $s2, GET_SLABS

    add $s2, $s2, 4             # skip over length
    mul $t1, $s0, 4             # find address of slab_info.metadata[i]
    add $s2, $s2, $t1           # s2 is now address of slab_info.metadata[i]

    # check if slab is on the right side already
    # if this is the case, we don't need to push this slab
    lbu $t1, 1($s2)
    bgt $t1, 20, main_loop_end

    # check if slab is locked
    # if so, while we don't have enough energy, solve puzzles
    lbu $t1, 2($s2)             # loads owner + locked into t1
    and $t2, $t1, 1             # t2 stores owner
    and $t3, $t1, 2             # t3 stores locked

    beq $t3, 0, main_loop_push_slab     # if the slab is not locked, don't need to unlock
    beq $t2, 0, main_loop_push_slab     # if we own it already, don't need to unlock

    # check if we have enough energy
get_energy_loop:
    lw  $t4, GET_ENERGY                 # load the current amount of energy we have into t4
    bgt $t4, 100, get_energy_loop_end   # stop solving puzzles if more than 100 energy

    move $a0, $s1               # call solve_puzzle(s1)
    jal solve_puzzle
    add $s1, $s1, 1             # increment s1 to the next puzzle

    j   get_energy_loop

get_energy_loop_end:

    # unlock the slab
    sw  $s0, UNLOCK_SLAB

main_loop_push_slab:

    # push slab to other side
    # how do i implement this?

    # first move as left as possible...
    jal move_as_left_as_possible

    # then move to the same y as the slab
    lw  $t0, BOT_Y              # load our y position into t0
    lbu $t1, 0($s2)             # load the slab's y position into t1
    mul $t1, $t1, 8             # convert slab's coords into pixels

    # do we need to move up or down?
    sub $t2, $t1, $t0           # s2 = slab_y - bot_y

    bgt $t2, 2, push_slab_move_down_loop
    blt $t2, -2, push_slab_move_up_loop
    j   push_slab_move_right

    # move up until our y matches with the slab
push_slab_move_up_loop:
    lw  $t0, BOT_Y              # load our y position into t0
    lbu $t1, 0($s2)             # load the slab's y position into t1
    mul $t1, $t1, 8             # convert slab's coords into pixels
    sub $t2, $t1, $t0           # s2 = slab_y - bot_y
    bgt $t2, -6, push_slab_align

    jal move_up
    j   push_slab_move_up_loop

    # move down until our y matches with the slab
push_slab_move_down_loop:
    lw  $t0, BOT_Y              # load our y position into t0
    lbu $t1, 0($s2)             # load the slab's y position into t1
    mul $t1, $t1, 8             # convert slab's coords into pixels
    sub $t2, $t1, $t0           # s2 = slab_y - bot_y

    blt $t2, 4, push_slab_align

    jal move_down
    j   push_slab_move_down_loop

    # put the slab at the right y level for pushing
push_slab_align:

    # if the slab's y is already good, we don't need to fix it
    lbu $t1, 0($s2)             # load the slab's y position into t1
    blt $t1, 5, push_slab_move_right    # already near the top?
    bgt $t1, 34, push_slab_move_right   # already near the bottom?

    # going to push the slab to the right y level:
    # figure out if we need to push the slab up or down

    # bgt $t1, 20, push_slab_scoot_up     # if y > 20, push down
push_slab_scoot_down:
    jal move_down
    jal move_down
    j   push_slab_move_to_slab_x_loop
push_slab_scoot_up:
    jal move_up
    jal move_up
    j   push_slab_move_to_slab_x_loop

    # move right under the slab
push_slab_move_to_slab_x_loop:
    jal move_right
    lw  $t0, BOT_X              # load our x position into t0
    lbu $t1, 1($s2)             # load the slab's x position into t1
    mul $t1, $t1, 8             # convert slab position to pixels

    sub $t2, $t1, $t0           # s2 = slab_x - bot_x
    bgt $t2, 0, push_slab_move_to_slab_x_loop     # loop while this difference is big

    # push the slab to the edge of the board and reposition to its left
    lbu $t1, 0($s2)             # load the slab's y position into t1
    # bgt $t1, 20, push_slab_down         # if y > 20, push down
push_slab_up:
    jal move_as_up_as_possible
    jal move_down
    jal move_left
    jal move_left
    jal move_up
    jal move_up
    j   push_slab_move_right

push_slab_down:
    jal move_as_down_as_possible
    jal move_up
    jal move_left
    jal move_left
    jal move_down
    jal move_down
    j   push_slab_move_right

    # try to push the slab right 25 times
push_slab_move_right:
    li  $s3, 25
push_slab_move_right_loop:
    jal move_right
    sub $s3, $s3, 1
    bgt $s3, 0, push_slab_move_right_loop

main_loop_end:

    add $s0, $s0, 1             # increment s0 to check the next slab next loop
    la  $t0, slab_info          # load slab_info.length into t0
    lw  $t0, 0($t0)

    blt $s0, $t0, main_loop     # loop if s0 < len
    sub $s0, $s0, $t0
    j   main_loop

rest:
    j   rest

# =========== helper functions ===========

# go all the way to the left
move_as_left_as_possible:
    sub $sp, $sp, 4
    sw  $ra, 0($sp)

move_as_left_as_possible_loop:
    lw  $t0, BOT_X
    blt $t0, 18, move_as_left_as_possible_end
    jal move_left
    j   move_as_left_as_possible_loop

move_as_left_as_possible_end:
    lw  $ra, 0($sp)
    add $sp, $sp, 4
    jr  $ra

# go all the way up
move_as_up_as_possible:
    sub $sp, $sp, 4
    sw  $ra, 0($sp)

move_as_up_as_possible_loop:
    lw  $t0, BOT_Y
    blt $t0, 32, move_as_up_as_possible_end
    jal move_up
    j   move_as_up_as_possible_loop

move_as_up_as_possible_end:
    lw  $ra, 0($sp)
    add $sp, $sp, 4
    jr  $ra

# go all the way down
move_as_down_as_possible:
    sub $sp, $sp, 4
    sw  $ra, 0($sp)

move_as_down_as_possible_loop:
    lw  $t0, BOT_Y
    bgt $t0, 290, move_as_down_as_possible_end
    jal move_down
    j   move_as_down_as_possible_loop

move_as_down_as_possible_end:
    lw  $ra, 0($sp)
    add $sp, $sp, 4
    jr  $ra

# ================ movement code ================
move_up:
    # start moving
    li  $t0, 270
    sw  $t0, ANGLE
    li  $t0, 1
    sw  $t0, ANGLE_CONTROL
    li  $t0, 10
    sw  $t0, VELOCITY

    # sleep until done
    li  $t1, 2666               # wait long enough to move 8 pixels
move_up_loop:
    sub $t1, $t1, 1
    bgt $t1, 0, move_up_loop

    # stop moving
    li  $t0, 0
    sw  $t0, VELOCITY
    jr  $ra

move_down:
    # start moving
    li  $t0, 90
    sw  $t0, ANGLE
    li  $t0, 1
    sw  $t0, ANGLE_CONTROL
    li  $t0, 10
    sw  $t0, VELOCITY

    # sleep until done
    li  $t1, 2666               # wait long enough to move 8 pixels
move_down_loop:
    sub $t1, $t1, 1
    bgt $t1, 0, move_down_loop

    # stop moving
    li  $t0, 0
    sw  $t0, VELOCITY
    jr  $ra

move_right:
    # start moving
    li  $t0, 0
    sw  $t0, ANGLE
    li  $t0, 1
    sw  $t0, ANGLE_CONTROL
    li  $t0, 10
    sw  $t0, VELOCITY

    # sleep until done
    li  $t1, 2666               # wait long enough to move 8 pixels
move_right_loop:
    sub $t1, $t1, 1
    bgt $t1, 0, move_right_loop

    # stop moving
    li  $t0, 0
    sw  $t0, VELOCITY
    jr  $ra

move_left:
    # start moving
    li  $t0, 180
    sw  $t0, ANGLE
    li  $t0, 1
    sw  $t0, ANGLE_CONTROL
    li  $t0, 10
    sw  $t0, VELOCITY

    # sleep until done
    li  $t1, 2666               # wait long enough to move 8 pixels
move_left_loop:
    sub $t1, $t1, 1
    bgt $t1, 0, move_left_loop

    # stop moving
    li  $t0, 0
    sw  $t0, VELOCITY
    jr  $ra


# ======================== Solve Puzzle ================================		

solve_puzzle:

    # // Stuff to put into the data segment
    # struct wordle_feedback_t feedbacks[6];
    # wordle_state_t state;                             
    # char feedback_received = 0;  // guess_received: .byte 0

    # set last_word_checked to 0
    li  $t0, 0
    sw  $t0, last_word_checked

    # allocate stack
    sub $sp, $sp, 20
    sw  $ra, 0($sp)
    sw  $a0, 4($sp)
    sw  $s0, 8($sp)
    sw  $s1, 12($sp)
    sw  $s2, 16($sp)

    li  $s0, 0                  # s0 = current_feedback = NULL

    sw  $t0, REQUEST_PUZZLE     # request a puzzle
    move $t0, $a0
    sw  $t0, CURRENT_PUZZLE     # set current puzzle to be the one this func is solving

    # loop 6 times to try to solve
    li  $s1, 0                  # s1 is i
sp_loop:

    # build_state(current_feedback, &state);
    move $a0, $s0
    la  $a1, state
    jal build_state

    # char *guess = find_matching_word(&state, words);
    la  $a0, state
    la  $a1, words
    jal find_matching_word

    # *PUZZLE_FEEDBACK = &feedbacks[i]; // put each feedback in a different place
    la  $s2, feedbacks
    mul $t0, $s1, 16
    add $s2, $s2, $t0               # s2 = &feedbacks[i]
    sw  $s2, PUZZLE_FEEDBACK        # *PUZZLE_FEEDBACK = &feedbacks[i]

    sw  $v0, SUBMIT_SOLUTION        # *SUBMIT_SOLUTION = guess

    # while (feedback_received == 0)
sp_wait_for_feedback:
    lb  $t0, feedback_received
    beq $t0, 0, sp_wait_for_feedback

    # feedback_received = 0;  // reset wait variable
    li  $t0, 0
    sw  $t0, feedback_received

    # if (is_solved(&feedbacks[i])) {  // provided in part2.s (checks if all 5 feedback are MATCH)
    move $a0, $s2
    jal is_solved
    bne $v0, 0, sp_return           # return

    sw  $s0, 12($s2)                # feedbacks[i].next = current_feedback
    move $s0, $s2                   # current_feedback = &feedbacks[i];			 

    add $s1, $s1, 1                 # i++
    blt $s1, 6, sp_loop

sp_return:

    # fix stack
    lw  $ra, 0($sp)
    lw  $a0, 4($sp)
    lw  $s0, 8($sp)
    lw  $s1, 12($sp)
    lw  $s2, 16($sp)
    add $sp, $sp, 20

    jr  $ra

# ======================== kernel code ================================
.kdata
chunkIH:    .space 40
non_intrpt_str:    .asciiz "Non-interrupt exception\n"
unhandled_str:    .asciiz "Unhandled interrupt type\n"
.ktext 0x80000180
interrupt_handler:
.set noat
    move    $k1, $at        # Save $at
                            # NOTE: Don't touch $k1 or else you destroy $at!
.set at
    la      $k0, chunkIH
    sw      $a0, 0($k0)        # Get some free registers
    sw      $v0, 4($k0)        # by storing them to a global variable
    sw      $t0, 8($k0)
    sw      $t1, 12($k0)
    sw      $t2, 16($k0)
    sw      $t3, 20($k0)
    sw      $t4, 24($k0)
    sw      $t5, 28($k0)

    # Save coprocessor1 registers!
    # If you don't do this and you decide to use division or multiplication
    #   in your main code, and interrupt handler code, you get WEIRD bugs.
    mfhi    $t0
    sw      $t0, 32($k0)
    mflo    $t0
    sw      $t0, 36($k0)

    mfc0    $k0, $13                # Get Cause register
    srl     $a0, $k0, 2
    and     $a0, $a0, 0xf           # ExcCode field
    bne     $a0, 0, non_intrpt


interrupt_dispatch:                 # Interrupt:
    mfc0    $k0, $13                # Get Cause register, again
    beq     $k0, 0, done            # handled all outstanding interrupts

    and     $a0, $k0, BONK_INT_MASK     # is there a bonk interrupt?
    bne     $a0, 0, bonk_interrupt

    and     $a0, $k0, TIMER_INT_MASK    # is there a timer interrupt?
    bne     $a0, 0, timer_interrupt

    and     $a0, $k0, FEEDBACK_INT_MASK # is there a feedback interrupt?
    bne     $a0, 0, feedback_interrupt

    li      $v0, PRINT_STRING       # Unhandled interrupt types
    la      $a0, unhandled_str
    syscall
    j       done

bonk_interrupt:
    sw      $0, BONK_ACK
    #Fill in your bonk handler code here
    j       interrupt_dispatch      # see if other interrupts are waiting

timer_interrupt:
    sw      $0, TIMER_ACK
    #Fill in your timer interrupt code here
    j       interrupt_dispatch      # see if other interrupts are waiting

feedback_interrupt:
    sw      $0, FEEDBACK_ACK        # acknowledge the interrupt
    li      $t0, 1
    sw      $t0, feedback_received  # feedback_received = 1;
    j       interrupt_dispatch      # see if other interrupts are waiting

non_intrpt:                         # was some non-interrupt
    li      $v0, PRINT_STRING
    la      $a0, non_intrpt_str
    syscall                         # print out an error message
    # fall through to done

done:
    la      $k0, chunkIH

    # Restore coprocessor1 registers!
    # If you don't do this and you decide to use division or multiplication
    #   in your main code, and interrupt handler code, you get WEIRD bugs.
    lw      $t0, 32($k0)
    mthi    $t0
    lw      $t0, 36($k0)
    mtlo    $t0

    lw      $a0, 0($k0)             # Restore saved registers
    lw      $v0, 4($k0)
    lw      $t0, 8($k0)
    lw      $t1, 12($k0)
    lw      $t2, 16($k0)
    lw      $t3, 20($k0)
    lw      $t4, 24($k0)
    lw      $t5, 28($k0)

.set noat
    move    $at, $k1        # Restore $at
.set at
    eret

## Provided code from Labs 6 and 7  + is_solved
.text	

# example printing function that takes two arguments ($a0, $a1) and prints them with a space between and then a return.	
print_xy:
	# this syscall takes $a0 as an argument of what INT to print
	li	$v0, PRINT_INT
        syscall

	li	$a0, 32		#space
	li	$v0, PRINT_CHAR
        syscall

	move	$a0, $a1
	li	$v0, PRINT_INT
        syscall
	
	li	$a0, 13		#return
	li	$v0, PRINT_CHAR
        syscall
	
	jr	$ra

#########################################	
	
is_solved:
	li	$t0, 0			# i = 0
is_loop:
	add	$t1, $a0, $t0		# &feedback->feedback[i] - 5
	lb	$t2, 5($t1)		# feedback->feedback[i]
	bne	$t2, 2, is_false	# return false if not MATCH
	add	$t0, $t0, 1		# i ++ 
	blt	$t0, 5, is_loop		# loop while i < 5
	
is_true:
	li	$v0, 1			# return TRUE
	jr	$ra

is_false:
	li	$v0, 0			# return FALSE
	jr	$ra

#########################################	
	
init_state:
	li	$t0, 0x03ffffff
	sw	$t0, 0($a0)
	sw	$t0, 4($a0)
	sw	$t0, 8($a0)
	sw	$t0, 12($a0)
	sw	$t0, 16($a0)

	sw	$0, 20($a0)
	sw	$0, 24($a0)
	sh	$0, 28($a0)

	jr	$ra

#########################################	

letters_allowed:	
	li	$t0, 0		# i = 0 
la_loop:
	bge	$t0, 5, la_done_true
	
	add	$t1, $a1, $t0	# &candidate[i]
	lb	$t1, 0($t1)	# candidate[i]
	sub	$t1, $t1, 97

	sll	$t2, $t0, 2	# 4*i
	add	$t2, $t2, $a0	# &state->letter_flags[i]
	lw	$t2, 0($t2)	# state->letter_flags[i]
	li	$t3, 1
	sll	$t3, $t3, $t1	# (1 << letter_index)
	and	$t3, $t3, $t2	# (state->letter_flags[i] & (1 << letter_index))
	beq	$t3, $0, la_done_false

	add	$t0, $t0, 1	# i ++
	j	la_loop

la_done_true:
	li	$v0, 1
	jr	$ra

la_done_false:
	li	$v0, 0
	jr	$ra

#########################################	

letters_required:
	li	$t0, 0
lr_loop:
	sll	$t1, $t0, 1	# 2*i
	add	$t1, $a0, $t1
	lb	$t2, 21($t1)	# state->letters[i].count
	beq	$t2, 0, lr_done_true

	lb	$t1, 20($t1)	# letter_index = state->letters[i].letter_index
	li	$t3, 0		# count
	li	$t4, 0		# j

lr_loop2:
	add	$t5, $a1, $t4	# &candidate[j]
	lb	$t5, 0($t5)	# candidate[j]
	sub	$t5, $t5, 97	# candidate[j] - 'a'
	bne	$t1, $t5, lr_skip
	
	add	$t3, $t3, 1	# count ++
lr_skip:	
	add	$t4, $t4, 1	# j ++
	blt	$t4, 5, lr_loop2
	
	and	$t6, $t2, 0x40	# desired_count & EXACTLY
	beq	$t6, $0, lr_skip2

	li	$t7, 0x40	# EXACTLY
	not	$t7, $t7	# ~EXACTLY
	and	$t2, $t2, $t7	# desired_count &= ~EXACTLY
	bne	$t2, $t3, lr_done_false
	j	lr_skip3

lr_skip2:
	blt	$t3, $t2, lr_done_false
	
lr_skip3:	
	add	$t0, $t0, 1	# i ++
	blt	$t0, 5, lr_loop # continue if i < 5
lr_done_true:
	li	$v0, 1
	jr	$ra

lr_done_false:
	li	$v0, 0
	jr	$ra

#########################################	
	
find_matching_word:	
    sub     $sp     $sp     24
    sw      $s0     0($sp)
    sw      $s1     4($sp)
    sw      $s2     8($sp)
    sw      $s3     12($sp)         
    sw      $s4     16($sp)         
    sw      $ra     20($sp)
    
    move    $s0     $a0             # state
    move    $s1     $a1             # words

    la      $s2     last_word_checked
    lw      $s2     0($s2)          # i = last_word_checked
    mul     $t0     $s2     6
    add     $s1     $s1     $t0     # address of words[last_word_checked]

    la      $s3     g_num_words
    lw      $s3     0($s3)          # g_num_words
    
_loop:
    bge     $s2     $s3     _ret_null
    
    move    $a0     $s0             # state
    move    $a1     $s1             # &words[i * 6]
    jal     letters_allowed
    move    $s4     $v0             # letters_allowed
    
    move    $a0     $s0             # state
    move    $a1     $s1             # &words[i * 6]
    jal     letters_required        
    and     $s4     $s4     $v0     # letters_allowed & letters_required
    
    move    $v0     $s1
    sw      $s2     last_word_checked   # update last_word_checked

    bne     $s4     $zero   _return # return candidate
    
    add     $s2     $s2     1       # ++i
    add     $s1     $s1     6       # ++words
    j       _loop

_ret_null:
    li      $v0     0
    
_return:
    lw      $s0     0($sp)
    lw      $s1     4($sp)
    lw      $s2     8($sp)
    lw      $s3     12($sp)
    lw      $s4     16($sp)
    lw      $ra     20($sp)
    add     $sp     $sp     24
    jr      $ra

#########################################	

count_instances_of_letter:
	li	$v0, 0		# count = 0

ciol_loop:
	add	$t1, $a0, $a1	# &feedback->word[i]
	lb	$t2, 0($t1)	# feedback->word[i]
	sub	$t2, $t2, 97	# i_letter_index = feedback->word[i] - 'a'

	bne	$t2, $a2, ciol_loop_end		# if (i_letter_index == letter_index) {
	lb	$t3, 5($t1)	# i_fback = feedback->feedback[i]

	bne	$t3, 0, ciol_else		# if (i_fback == NOMATCH) {
	or	$v0, $v0, 0x40	# count |= EXACTLY
	j	ciol_endif
	
ciol_else:
	add	$v0, $v0, 1	# count ++
	
ciol_endif:
	lw	$t4, 0($a3)	# *already_visited
	li	$t5, 1
	sll	$t5, $t5, $a1	# (1 << i)
	or	$t4, $t4, $t5
	sw	$t4, 0($a3)	# *already_visited != (1 << i)

ciol_loop_end:	
	add	$a1, $a1, 1	# i++
	blt	$a1, 5, ciol_loop
	
	jr	$ra

#########################################	

update_state:
	move	$v0, $a3
	
	li	$t0, 0x40	# EXACTLY
	bne	$a1, $t0, us_else

	li	$t1, 0		# i
	li	$t2, 1
	sll	$t2, $t2, $a2	# (1 << letter_index)
	nor	$t2, $t2, $0	# ~(1 << letter_index)
us_loop:
	mul	$t3, $t1, 4	# i * 4
	add	$t3, $t3, $a0	# &state->letter_flags[i]
	lw	$t4, 0($t3)
	and	$t4, $t4, $t2	# state->letter_flags[i] & ~(1 << letter_index)
	sw	$t4, 0($t3)

	add	$t1, $t1, 1	# i ++
	blt	$t1, 5, us_loop
	
	jr	$ra
	
us_else:	
	mul	$t0, $v0, 2	# 2 * next_letter
	add	$t0, $t0, $a0	# &state->letters[next_letter] - 20
	sb	$a2, 20($t0)	# state->letters[next_letter].letter_index = letter_index;
	sb	$a1, 21($t0)	# state->letters[next_letter].count = count;
	add	$v0, $v0, 1	# next_letter ++;

	jr	$ra

#########################################	

build_state:	
	bne	$a0, $0, bs_recurse
	sub	$sp, $sp, 4
	sw	$ra, 0($sp)
	
	move	$a0, $a1
	jal	init_state
	
	lw	$ra, 0($sp)
	add	$sp, $sp, 4
	jr	$ra

bs_recurse:	
	sub	$sp, $sp, 28
	sw	$ra, 0($sp)
	sw	$s0, 4($sp)
	sw	$s1, 8($sp)
	sw	$s2, 12($sp)
	sw	$s3, 16($sp)
	sw	$s4, 20($sp)
	sw	$0,  24($sp)	# already_visited

	move	$s0, $a0	# feedback
	move	$s1, $a1	# state

	lw	$a0, 12($a0)	# feedback->prev
	jal	build_state
	
	li	$s3, 0		# next_letter = 0;
	li	$s2, 0		# i = 0

bs_loop:
	add	$t0, $s0, $s2	# &feedback->word[i]
	lb	$t1, 0($t0)	# feedback->word[i]
	sub	$s4, $t1, 97	# letter_index = feedback->word[i] - 'a'
	lb	$t2, 5($t0)	# fback = feedback->feedback[i]
	mul	$t3, $s2, 4	# i * 4
	add	$t3, $s1, $t3	# &state->letter_flags[i]
	li	$t0, 1
	sll	$t4, $t0, $s4	# (1 << letter_index)
	
	bne	$t2, 2, bs_else
	sw	$t4, 0($t3)	# state->letter_flags[i] = (1 << letter_index)
	j	bs_cont
bs_else:	
	nor	$t4, $t4, $0	# ~(1 << letter_index)
	lw	$t5, 0($t3)	# state->letter_flags[i]
	and	$t5, $t5, $t4	# state->letter_flags[i] & ~(1 << letter_index)
	sw	$t5, 0($t3)	# state->letter_flags[i] &= ~(1 << letter_index)
	
bs_cont:	
	li	$t0, 1
	sll	$t0, $t0, $s2	# (1 << i)
	lw	$t1,  24($sp)	# already_visited
	and	$t0, $t1, $t0	# already_visited & (1 << i)
	bne	$t0, $0, bs_end_loop

	move	$a0, $s0	# feedback
	move	$a1, $s2	# i
	move	$a2, $s4	# letter_index
	add	$a3, $sp, 24	# &already_visited
	jal	count_instances_of_letter

	move	$a0, $s1	# state
	move	$a1, $v0	# count
	move	$a2, $s4	# letter_index
	move	$a3, $s3	# next_letter
	jal	update_state
	move 	$s3, $v0	# next_letter = update_state(...)

bs_end_loop:	
	add	$s2, $s2, 1	# i ++
	blt	$s2, 5, bs_loop

	lw	$ra, 0($sp)
	lw	$s0, 4($sp)
	lw	$s1, 8($sp)
	lw	$s2, 12($sp)
	lw	$s3, 16($sp)
	lw	$s4, 20($sp)
	add	$sp, $sp, 28
	jr	$ra


.data
.align 2
g_num_words:	.word 2315
words:
.asciiz	"aback" "abase" "abate" "abbey" "abbot" "abhor" "abide" "abled" "abode" "abort" "about" "above" "abuse"
.asciiz	"abyss" "acorn" "acrid" "actor" "acute" "adage" "adapt" "adept" "admin" "admit" "adobe" "adopt" "adore"
.asciiz	"adorn" "adult" "affix" "afire" "afoot" "afoul" "after" "again" "agape" "agate" "agent" "agile" "aging"
.asciiz	"aglow" "agony" "agora" "agree" "ahead" "aider" "aisle" "alarm" "album" "alert" "algae" "alibi" "alien"
.asciiz "align" "alike" "alive" "allay" "alley" "allot" "allow" "alloy" "aloft" "alone" "along" "aloof" "aloud"
.asciiz	"alpha" "altar" "alter" "amass" "amaze" "amber" "amble" "amend" "amiss" "amity" "among" "ample" "amply"
.asciiz	"amuse" "angel" "anger" "angle" "angry" "angst" "anime" "ankle" "annex" "annoy" "annul" "anode" "antic"
.asciiz	"anvil" "aorta" "apart" "aphid" "aping" "apnea" "apple" "apply" "apron" "aptly" "arbor" "ardor" "arena"
.asciiz	"argue" "arise" "armor" "aroma" "arose" "array" "arrow" "arson" "artsy" "ascot" "ashen" "aside" "askew"
.asciiz	"assay" "asset" "atoll" "atone" "attic" "audio" "audit" "augur" "aunty" "avail" "avert" "avian" "avoid"
.asciiz	"await" "awake" "award" "aware" "awash" "awful" "awoke" "axial" "axiom" "axion" "azure" "bacon" "badge"
.asciiz	"badly" "bagel" "baggy" "baker" "baler" "balmy" "banal" "banjo" "barge" "baron" "basal" "basic" "basil"
.asciiz	"basin" "basis" "baste" "batch" "bathe" "baton" "batty" "bawdy" "bayou" "beach" "beady" "beard" "beast"
.asciiz	"beech" "beefy" "befit" "began" "begat" "beget" "begin" "begun" "being" "belch" "belie" "belle" "belly"
.asciiz "below" "bench" "beret" "berry" "berth" "beset" "betel" "bevel" "bezel" "bible" "bicep" "biddy" "bigot"
.asciiz	"bilge" "billy" "binge" "bingo" "biome" "birch" "birth" "bison" "bitty" "black" "blade" "blame" "bland"
.asciiz	"blank" "blare" "blast" "blaze" "bleak" "bleat" "bleed" "bleep" "blend" "bless" "blimp" "blind" "blink"
.asciiz	"bliss" "blitz" "bloat" "block" "bloke" "blond" "blood" "bloom" "blown" "bluer" "bluff" "blunt" "blurb"
.asciiz	"blurt" "blush" "board" "boast" "bobby" "boney" "bongo" "bonus" "booby" "boost" "booth" "booty" "booze"
.asciiz	"boozy" "borax" "borne" "bosom" "bossy" "botch" "bough" "boule" "bound" "bowel" "boxer" "brace" "braid"
.asciiz	"brain" "brake" "brand" "brash" "brass" "brave" "bravo" "brawl" "brawn" "bread" "break" "breed" "briar"
.asciiz "bribe" "brick" "bride" "brief" "brine" "bring" "brink" "briny" "brisk" "broad" "broil" "broke" "brood"
.asciiz	"brook" "broom" "broth" "brown" "brunt" "brush" "brute" "buddy" "budge" "buggy" "bugle" "build" "built"
.asciiz	"bulge" "bulky" "bully" "bunch" "bunny" "burly" "burnt" "burst" "bused" "bushy" "butch" "butte" "buxom"
.asciiz	"buyer" "bylaw" "cabal" "cabby" "cabin" "cable" "cacao" "cache" "cacti" "caddy" "cadet" "cagey" "cairn"
.asciiz	"camel" "cameo" "canal" "candy" "canny" "canoe" "canon" "caper" "caput" "carat" "cargo" "carol" "carry"
.asciiz	"carve" "caste" "catch" "cater" "catty" "caulk" "cause" "cavil" "cease" "cedar" "cello" "chafe" "chaff"
.asciiz	"chain" "chair" "chalk" "champ" "chant" "chaos" "chard" "charm" "chart" "chase" "chasm" "cheap" "cheat"
.asciiz	"check" "cheek" "cheer" "chess" "chest" "chick" "chide" "chief" "child" "chili" "chill" "chime" "china"
.asciiz	"chirp" "chock" "choir" "choke" "chord" "chore" "chose" "chuck" "chump" "chunk" "churn" "chute" "cider"
.asciiz	"cigar" "cinch" "circa" "civic" "civil" "clack" "claim" "clamp" "clang" "clank" "clash" "clasp" "class"
.asciiz	"clean" "clear" "cleat" "cleft" "clerk" "click" "cliff" "climb" "cling" "clink" "cloak" "clock" "clone"
.asciiz	"close" "cloth" "cloud" "clout" "clove" "clown" "cluck" "clued" "clump" "clung" "coach" "coast" "cobra"
.asciiz	"cocoa" "colon" "color" "comet" "comfy" "comic" "comma" "conch" "condo" "conic" "copse" "coral" "corer"
.asciiz	"corny" "couch" "cough" "could" "count" "coupe" "court" "coven" "cover" "covet" "covey" "cower" "coyly"
.asciiz	"crack" "craft" "cramp" "crane" "crank" "crash" "crass" "crate" "crave" "crawl" "craze" "crazy" "creak"
.asciiz	"cream" "credo" "creed" "creek" "creep" "creme" "crepe" "crept" "cress" "crest" "crick" "cried" "crier"
.asciiz	"crime" "crimp" "crisp" "croak" "crock" "crone" "crony" "crook" "cross" "croup" "crowd" "crown" "crude"
.asciiz	"cruel" "crumb" "crump" "crush" "crust" "crypt" "cubic" "cumin" "curio" "curly" "curry" "curse" "curve"
.asciiz	"curvy" "cutie" "cyber" "cycle" "cynic" "daddy" "daily" "dairy" "daisy" "dally" "dance" "dandy" "datum"
.asciiz	"daunt" "dealt" "death" "debar" "debit" "debug" "debut" "decal" "decay" "decor" "decoy" "decry" "defer"
.asciiz	"deign" "deity" "delay" "delta" "delve" "demon" "demur" "denim" "dense" "depot" "depth" "derby" "deter"
.asciiz	"detox" "deuce" "devil" "diary" "dicey" "digit" "dilly" "dimly" "diner" "dingo" "dingy" "diode" "dirge"
.asciiz	"dirty" "disco" "ditch" "ditto" "ditty" "diver" "dizzy" "dodge" "dodgy" "dogma" "doing" "dolly" "donor"
.asciiz	"donut" "dopey" "doubt" "dough" "dowdy" "dowel" "downy" "dowry" "dozen" "draft" "drain" "drake" "drama"
.asciiz	"drank" "drape" "drawl" "drawn" "dread" "dream" "dress" "dried" "drier" "drift" "drill" "drink" "drive"
.asciiz	"droit" "droll" "drone" "drool" "droop" "dross" "drove" "drown" "druid" "drunk" "dryer" "dryly" "duchy"
.asciiz	"dully" "dummy" "dumpy" "dunce" "dusky" "dusty" "dutch" "duvet" "dwarf" "dwell" "dwelt" "dying" "eager"
.asciiz	"eagle" "early" "earth" "easel" "eaten" "eater" "ebony" "eclat" "edict" "edify" "eerie" "egret" "eight"
.asciiz	"eject" "eking" "elate" "elbow" "elder" "elect" "elegy" "elfin" "elide" "elite" "elope" "elude" "email"
.asciiz	"embed" "ember" "emcee" "empty" "enact" "endow" "enema" "enemy" "enjoy" "ennui" "ensue" "enter" "entry"
.asciiz	"envoy" "epoch" "epoxy" "equal" "equip" "erase" "erect" "erode" "error" "erupt" "essay" "ester" "ether"
.asciiz	"ethic" "ethos" "etude" "evade" "event" "every" "evict" "evoke" "exact" "exalt" "excel" "exert" "exile"
.asciiz	"exist" "expel" "extol" "extra" "exult" "eying" "fable" "facet" "faint" "fairy" "faith" "false" "fancy"
.asciiz	"fanny" "farce" "fatal" "fatty" "fault" "fauna" "favor" "feast" "fecal" "feign" "fella" "felon" "femme"
.asciiz	"femur" "fence" "feral" "ferry" "fetal" "fetch" "fetid" "fetus" "fever" "fewer" "fiber" "fibre" "ficus"
.asciiz	"field" "fiend" "fiery" "fifth" "fifty" "fight" "filer" "filet" "filly" "filmy" "filth" "final" "finch"
.asciiz	"finer" "first" "fishy" "fixer" "fizzy" "fjord" "flack" "flail" "flair" "flake" "flaky" "flame" "flank"
.asciiz	"flare" "flash" "flask" "fleck" "fleet" "flesh" "flick" "flier" "fling" "flint" "flirt" "float" "flock"
.asciiz	"flood" "floor" "flora" "floss" "flour" "flout" "flown" "fluff" "fluid" "fluke" "flume" "flung" "flunk"
.asciiz	"flush" "flute" "flyer" "foamy" "focal" "focus" "foggy" "foist" "folio" "folly" "foray" "force" "forge"
.asciiz	"forgo" "forte" "forth" "forty" "forum" "found" "foyer" "frail" "frame" "frank" "fraud" "freak" "freed"
.asciiz	"freer" "fresh" "friar" "fried" "frill" "frisk" "fritz" "frock" "frond" "front" "frost" "froth" "frown"
.asciiz	"froze" "fruit" "fudge" "fugue" "fully" "fungi" "funky" "funny" "furor" "furry" "fussy" "fuzzy" "gaffe"
.asciiz	"gaily" "gamer" "gamma" "gamut" "gassy" "gaudy" "gauge" "gaunt" "gauze" "gavel" "gawky" "gayer" "gayly"
.asciiz	"gazer" "gecko" "geeky" "geese" "genie" "genre" "ghost" "ghoul" "giant" "giddy" "gipsy" "girly" "girth"
.asciiz	"given" "giver" "glade" "gland" "glare" "glass" "glaze" "gleam" "glean" "glide" "glint" "gloat" "globe"
.asciiz	"gloom" "glory" "gloss" "glove" "glyph" "gnash" "gnome" "godly" "going" "golem" "golly" "gonad" "goner"
.asciiz	"goody" "gooey" "goofy" "goose" "gorge" "gouge" "gourd" "grace" "grade" "graft" "grail" "grain" "grand"
.asciiz	"grant" "grape" "graph" "grasp" "grass" "grate" "grave" "gravy" "graze" "great" "greed" "green" "greet"
.asciiz	"grief" "grill" "grime" "grimy" "grind" "gripe" "groan" "groin" "groom" "grope" "gross" "group" "grout"
.asciiz	"grove" "growl" "grown" "gruel" "gruff" "grunt" "guard" "guava" "guess" "guest" "guide" "guild" "guile"
.asciiz	"guilt" "guise" "gulch" "gully" "gumbo" "gummy" "guppy" "gusto" "gusty" "gypsy" "habit" "hairy" "halve"
.asciiz	"handy" "happy" "hardy" "harem" "harpy" "harry" "harsh" "haste" "hasty" "hatch" "hater" "haunt" "haute"
.asciiz	"haven" "havoc" "hazel" "heady" "heard" "heart" "heath" "heave" "heavy" "hedge" "hefty" "heist" "helix"
.asciiz	"hello" "hence" "heron" "hilly" "hinge" "hippo" "hippy" "hitch" "hoard" "hobby" "hoist" "holly" "homer"
.asciiz	"honey" "honor" "horde" "horny" "horse" "hotel" "hotly" "hound" "house" "hovel" "hover" "howdy" "human"
.asciiz	"humid" "humor" "humph" "humus" "hunch" "hunky" "hurry" "husky" "hussy" "hutch" "hydro" "hyena" "hymen"
.asciiz	"hyper" "icily" "icing" "ideal" "idiom" "idiot" "idler" "idyll" "igloo" "iliac" "image" "imbue" "impel"
.asciiz	"imply" "inane" "inbox" "incur" "index" "inept" "inert" "infer" "ingot" "inlay" "inlet" "inner" "input"
.asciiz	"inter" "intro" "ionic" "irate" "irony" "islet" "issue" "itchy" "ivory" "jaunt" "jazzy" "jelly" "jerky"
.asciiz	"jetty" "jewel" "jiffy" "joint" "joist" "joker" "jolly" "joust" "judge" "juice" "juicy" "jumbo" "jumpy"
.asciiz	"junta" "junto" "juror" "kappa" "karma" "kayak" "kebab" "khaki" "kinky" "kiosk" "kitty" "knack" "knave"
.asciiz	"knead" "kneed" "kneel" "knelt" "knife" "knock" "knoll" "known" "koala" "krill" "label" "labor" "laden"
.asciiz	"ladle" "lager" "lance" "lanky" "lapel" "lapse" "large" "larva" "lasso" "latch" "later" "lathe" "latte"
.asciiz	"laugh" "layer" "leach" "leafy" "leaky" "leant" "leapt" "learn" "lease" "leash" "least" "leave" "ledge"
.asciiz	"leech" "leery" "lefty" "legal" "leggy" "lemon" "lemur" "leper" "level" "lever" "libel" "liege" "light"
.asciiz	"liken" "lilac" "limbo" "limit" "linen" "liner" "lingo" "lipid" "lithe" "liver" "livid" "llama" "loamy"
.asciiz	"loath" "lobby" "local" "locus" "lodge" "lofty" "logic" "login" "loopy" "loose" "lorry" "loser" "louse"
.asciiz	"lousy" "lover" "lower" "lowly" "loyal" "lucid" "lucky" "lumen" "lumpy" "lunar" "lunch" "lunge" "lupus"
.asciiz	"lurch" "lurid" "lusty" "lying" "lymph" "lynch" "lyric" "macaw" "macho" "macro" "madam" "madly" "mafia"
.asciiz	"magic" "magma" "maize" "major" "maker" "mambo" "mamma" "mammy" "manga" "mange" "mango" "mangy" "mania"
.asciiz	"manic" "manly" "manor" "maple" "march" "marry" "marsh" "mason" "masse" "match" "matey" "mauve" "maxim"
.asciiz	"maybe" "mayor" "mealy" "meant" "meaty" "mecca" "medal" "media" "medic" "melee" "melon" "mercy" "merge"
.asciiz	"merit" "merry" "metal" "meter" "metro" "micro" "midge" "midst" "might" "milky" "mimic" "mince" "miner"
.asciiz	"minim" "minor" "minty" "minus" "mirth" "miser" "missy" "mocha" "modal" "model" "modem" "mogul" "moist"
.asciiz	"molar" "moldy" "money" "month" "moody" "moose" "moral" "moron" "morph" "mossy" "motel" "motif" "motor"
.asciiz	"motto" "moult" "mound" "mount" "mourn" "mouse" "mouth" "mover" "movie" "mower" "mucky" "mucus" "muddy"
.asciiz	"mulch" "mummy" "munch" "mural" "murky" "mushy" "music" "musky" "musty" "myrrh" "nadir" "naive" "nanny"
.asciiz	"nasal" "nasty" "natal" "naval" "navel" "needy" "neigh" "nerdy" "nerve" "never" "newer" "newly" "nicer"
.asciiz	"niche" "niece" "night" "ninja" "ninny" "ninth" "noble" "nobly" "noise" "noisy" "nomad" "noose" "north"
.asciiz	"nosey" "notch" "novel" "nudge" "nurse" "nutty" "nylon" "nymph" "oaken" "obese" "occur" "ocean" "octal"
.asciiz	"octet" "odder" "oddly" "offal" "offer" "often" "olden" "older" "olive" "ombre" "omega" "onion" "onset"
.asciiz	"opera" "opine" "opium" "optic" "orbit" "order" "organ" "other" "otter" "ought" "ounce" "outdo" "outer"
.asciiz "outgo" "ovary" "ovate" "overt" "ovine" "ovoid" "owing" "owner" "oxide" "ozone" "paddy" "pagan" "paint"
.asciiz "paler" "palsy" "panel" "panic" "pansy" "papal" "paper" "parer" "parka" "parry" "parse" "party" "pasta"
.asciiz "paste" "pasty" "patch" "patio" "patsy" "patty" "pause" "payee" "payer" "peace" "peach" "pearl" "pecan"
.asciiz "pedal" "penal" "pence" "penne" "penny" "perch" "peril" "perky" "pesky" "pesto" "petal" "petty" "phase"
.asciiz "phone" "phony" "photo" "piano" "picky" "piece" "piety" "piggy" "pilot" "pinch" "piney" "pinky" "pinto"
.asciiz "piper" "pique" "pitch" "pithy" "pivot" "pixel" "pixie" "pizza" "place" "plaid" "plain" "plait" "plane"
.asciiz "plank" "plant" "plate" "plaza" "plead" "pleat" "plied" "plier" "pluck" "plumb" "plume" "plump" "plunk"
.asciiz "plush" "poesy" "point" "poise" "poker" "polar" "polka" "polyp" "pooch" "poppy" "porch" "poser" "posit"
.asciiz "posse" "pouch" "pound" "pouty" "power" "prank" "prawn" "preen" "press" "price" "prick" "pride" "pried"
.asciiz "prime" "primo" "print" "prior" "prism" "privy" "prize" "probe" "prone" "prong" "proof" "prose" "proud"
.asciiz "prove" "prowl" "proxy" "prude" "prune" "psalm" "pubic" "pudgy" "puffy" "pulpy" "pulse" "punch" "pupal"
.asciiz "pupil" "puppy" "puree" "purer" "purge" "purse" "pushy" "putty" "pygmy" "quack" "quail" "quake" "qualm"
.asciiz "quark" "quart" "quash" "quasi" "queen" "queer" "quell" "query" "quest" "queue" "quick" "quiet" "quill"
.asciiz "quilt" "quirk" "quite" "quota" "quote" "quoth" "rabbi" "rabid" "racer" "radar" "radii" "radio" "rainy"
.asciiz "raise" "rajah" "rally" "ralph" "ramen" "ranch" "randy" "range" "rapid" "rarer" "raspy" "ratio" "ratty"
.asciiz "raven" "rayon" "razor" "reach" "react" "ready" "realm" "rearm" "rebar" "rebel" "rebus" "rebut" "recap"
.asciiz "recur" "recut" "reedy" "refer" "refit" "regal" "rehab" "reign" "relax" "relay" "relic" "remit" "renal"
.asciiz "renew" "repay" "repel" "reply" "rerun" "reset" "resin" "retch" "retro" "retry" "reuse" "revel" "revue"
.asciiz "rhino" "rhyme" "rider" "ridge" "rifle" "right" "rigid" "rigor" "rinse" "ripen" "riper" "risen" "riser"
.asciiz "risky" "rival" "river" "rivet" "roach" "roast" "robin" "robot" "rocky" "rodeo" "roger" "rogue" "roomy"
.asciiz "roost" "rotor" "rouge" "rough" "round" "rouse" "route" "rover" "rowdy" "rower" "royal" "ruddy" "ruder"
.asciiz "rugby" "ruler" "rumba" "rumor" "rupee" "rural" "rusty" "sadly" "safer" "saint" "salad" "sally" "salon"
.asciiz "salsa" "salty" "salve" "salvo" "sandy" "saner" "sappy" "sassy" "satin" "satyr" "sauce" "saucy" "sauna"
.asciiz "saute" "savor" "savoy" "savvy" "scald" "scale" "scalp" "scaly" "scamp" "scant" "scare" "scarf" "scary"
.asciiz "scene" "scent" "scion" "scoff" "scold" "scone" "scoop" "scope" "score" "scorn" "scour" "scout" "scowl"
.asciiz "scram" "scrap" "scree" "screw" "scrub" "scrum" "scuba" "sedan" "seedy" "segue" "seize" "semen" "sense"
.asciiz "sepia" "serif" "serum" "serve" "setup" "seven" "sever" "sewer" "shack" "shade" "shady" "shaft" "shake"
.asciiz "shaky" "shale" "shall" "shalt" "shame" "shank" "shape" "shard" "share" "shark" "sharp" "shave" "shawl"
.asciiz "shear" "sheen" "sheep" "sheer" "sheet" "sheik" "shelf" "shell" "shied" "shift" "shine" "shiny" "shire"
.asciiz "shirk" "shirt" "shoal" "shock" "shone" "shook" "shoot" "shore" "shorn" "short" "shout" "shove" "shown"
.asciiz "showy" "shrew" "shrub" "shrug" "shuck" "shunt" "shush" "shyly" "siege" "sieve" "sight" "sigma" "silky"
.asciiz "silly" "since" "sinew" "singe" "siren" "sissy" "sixth" "sixty" "skate" "skier" "skiff" "skill" "skimp"
.asciiz "skirt" "skulk" "skull" "skunk" "slack" "slain" "slang" "slant" "slash" "slate" "slave" "sleek" "sleep"
.asciiz "sleet" "slept" "slice" "slick" "slide" "slime" "slimy" "sling" "slink" "sloop" "slope" "slosh" "sloth"
.asciiz "slump" "slung" "slunk" "slurp" "slush" "slyly" "smack" "small" "smart" "smash" "smear" "smell" "smelt"
.asciiz "smile" "smirk" "smite" "smith" "smock" "smoke" "smoky" "smote" "snack" "snail" "snake" "snaky" "snare"
.asciiz "snarl" "sneak" "sneer" "snide" "sniff" "snipe" "snoop" "snore" "snort" "snout" "snowy" "snuck" "snuff"
.asciiz "soapy" "sober" "soggy" "solar" "solid" "solve" "sonar" "sonic" "sooth" "sooty" "sorry" "sound" "south"
.asciiz "sower" "space" "spade" "spank" "spare" "spark" "spasm" "spawn" "speak" "spear" "speck" "speed" "spell"
.asciiz "spelt" "spend" "spent" "sperm" "spice" "spicy" "spied" "spiel" "spike" "spiky" "spill" "spilt" "spine"
.asciiz "spiny" "spire" "spite" "splat" "split" "spoil" "spoke" "spoof" "spook" "spool" "spoon" "spore" "sport"
.asciiz "spout" "spray" "spree" "sprig" "spunk" "spurn" "spurt" "squad" "squat" "squib" "stack" "staff" "stage"
.asciiz "staid" "stain" "stair" "stake" "stale" "stalk" "stall" "stamp" "stand" "stank" "stare" "stark" "start"
.asciiz "stash" "state" "stave" "stead" "steak" "steal" "steam" "steed" "steel" "steep" "steer" "stein" "stern"
.asciiz "stick" "stiff" "still" "stilt" "sting" "stink" "stint" "stock" "stoic" "stoke" "stole" "stomp" "stone"
.asciiz "stony" "stood" "stool" "stoop" "store" "stork" "storm" "story" "stout" "stove" "strap" "straw" "stray"
.asciiz "strip" "strut" "stuck" "study" "stuff" "stump" "stung" "stunk" "stunt" "style" "suave" "sugar" "suing"
.asciiz "suite" "sulky" "sully" "sumac" "sunny" "super" "surer" "surge" "surly" "sushi" "swami" "swamp" "swarm"
.asciiz "swash" "swath" "swear" "sweat" "sweep" "sweet" "swell" "swept" "swift" "swill" "swine" "swing" "swirl"
.asciiz "swish" "swoon" "swoop" "sword" "swore" "sworn" "swung" "synod" "syrup" "tabby" "table" "taboo" "tacit"
.asciiz "tacky" "taffy" "taint" "taken" "taker" "tally" "talon" "tamer" "tango" "tangy" "taper" "tapir" "tardy"
.asciiz "tarot" "taste" "tasty" "tatty" "taunt" "tawny" "teach" "teary" "tease" "teddy" "teeth" "tempo" "tenet"
.asciiz "tenor" "tense" "tenth" "tepee" "tepid" "terra" "terse" "testy" "thank" "theft" "their" "theme" "there"
.asciiz "these" "theta" "thick" "thief" "thigh" "thing" "think" "third" "thong" "thorn" "those" "three" "threw"
.asciiz "throb" "throw" "thrum" "thumb" "thump" "thyme" "tiara" "tibia" "tidal" "tiger" "tight" "tilde" "timer"
.asciiz "timid" "tipsy" "titan" "tithe" "title" "toast" "today" "toddy" "token" "tonal" "tonga" "tonic" "tooth"
.asciiz "topaz" "topic" "torch" "torso" "torus" "total" "totem" "touch" "tough" "towel" "tower" "toxic" "toxin"
.asciiz "trace" "track" "tract" "trade" "trail" "train" "trait" "tramp" "trash" "trawl" "tread" "treat" "trend"
.asciiz "triad" "trial" "tribe" "trice" "trick" "tried" "tripe" "trite" "troll" "troop" "trope" "trout" "trove"
.asciiz "truce" "truck" "truer" "truly" "trump" "trunk" "truss" "trust" "truth" "tryst" "tubal" "tuber" "tulip"
.asciiz "tulle" "tumor" "tunic" "turbo" "tutor" "twang" "tweak" "tweed" "tweet" "twice" "twine" "twirl" "twist"
.asciiz "twixt" "tying" "udder" "ulcer" "ultra" "umbra" "uncle" "uncut" "under" "undid" "undue" "unfed" "unfit"
.asciiz "unify" "union" "unite" "unity" "unlit" "unmet" "unset" "untie" "until" "unwed" "unzip" "upper" "upset"
.asciiz "urban" "urine" "usage" "usher" "using" "usual" "usurp" "utile" "utter" "vague" "valet" "valid" "valor"
.asciiz "value" "valve" "vapid" "vapor" "vault" "vaunt" "vegan" "venom" "venue" "verge" "verse" "verso" "verve"
.asciiz "vicar" "video" "vigil" "vigor" "villa" "vinyl" "viola" "viper" "viral" "virus" "visit" "visor" "vista"
.asciiz "vital" "vivid" "vixen" "vocal" "vodka" "vogue" "voice" "voila" "vomit" "voter" "vouch" "vowel" "vying"
.asciiz "wacky" "wafer" "wager" "wagon" "waist" "waive" "waltz" "warty" "waste" "watch" "water" "waver" "waxen"
.asciiz "weary" "weave" "wedge" "weedy" "weigh" "weird" "welch" "welsh" "wench" "whack" "whale" "wharf" "wheat"
.asciiz "wheel" "whelp" "where" "which" "whiff" "while" "whine" "whiny" "whirl" "whisk" "white" "whole" "whoop"
.asciiz "whose" "widen" "wider" "widow" "width" "wield" "wight" "willy" "wimpy" "wince" "winch" "windy" "wiser"
.asciiz "wispy" "witch" "witty" "woken" "woman" "women" "woody" "wooer" "wooly" "woozy" "wordy" "world" "worry"
.asciiz "worse" "worst" "worth" "would" "wound" "woven" "wrack" "wrath" "wreak" "wreck" "wrest" "wring" "wrist"
.asciiz "write" "wrong" "wrote" "wrung" "wryly" "yacht" "yearn" "yeast" "yield" "young" "youth" "zebra" "zesty" "zonal"
	
