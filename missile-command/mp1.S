# mp1.S - missile-command version
# Good luck, and have fun!

.data
	
    # Constants for accessing the fields of a struct missile, 
    # struct missile is defined in rtc.h and mp1.h

	NEXT 	  = 0
	X	  = 4
	Y	  = 8
	VX	  = 12
	VY	  = 16
	DEST_X	  = 20
	DEST_Y	  = 24
	EXPLODED  = 28
	C	  = 32

    # Character to draw for an explosion - '@'

	EXPLOSION = 64


# Data shared between this file and rtc.c helper functions

# This '.globl' directive makes these symbols visible externally
.globl mp1_missile_list, base_alive, mp1_score


mp1_missile_list:	.long 0x0	# Head of list pointer. set to 0
base_alive:		.long 0x0	# Array of 3 bytes, plus a padding byte set to 
mp1_score:		.long 0x0	# Player's current score set to 0


# Data private to this  file

base_pic:     	    .string "/^^^\\"	# Picture of a live base
dead_base_pic: 	    .string "xxxxx"	# Picture of a dead base
crosshairs_x:		.long 0x0	# X-position of the crosshairs
crosshairs_y:		.long 0x0	# Y-position of the crosshairs

.text

# upper 16 bits = current position
# lower 16 bits = new position
# new_x = x + vx
# new_y = y + vy
# void mp1_poke(void);
# You can use this function to write to video memory.
#
# Interface: Register-based arguments (not C-style)
#    Inputs: %cl  - The byte you wish to write
#            %eax - Offset from the start of video memory that you wish
#                   to write to
#   Outputs: Text-mode video screen is written to at location %eax with
#            the byte in %cl
# Registers: Clobbers EDX

mp1_poke:
		movl    vmem_base_addr(,1),%edx
		movb    %cl,(%edx,%eax,1)
		ret

#   ----------------- Exported functions ---------------------

# void mp1_rtc_tasklet(unsigned long garbage);
# Performs three tasks:
#	(1) updates the list of missiles (implement this in update_missiles,
#           below, and call it from here).
#	(2) Redraw the bases - they may have been overwritten with missiles
#	(3) Redraw the crosshairs - it may have been overwritten with missiles
# Inputs   : none
# Outputs  : none
# Registers: Standard C calling convention

.globl mp1_rtc_tasklet

# initialize curr pointer for linked list
mp1_rtc_tasklet:
		# iterate through missile linked list
		pushl %ebp # save old fram pointer
		movl %esp, %ebp # point to new frame
		pushl %ebx # temp for comparing bounds value
		pushl %esi 
		pushl %edi

	initial_loop:
		movl mp1_missile_list, %ebx
		cmpl $0, %ebx
		je update_missile
		movl exploded(%ebx), %esi
		cmpl $0, %esi
		je initial_loop 
		# otherwise update x and y position
		addl vx(%ebx), x(%ebx) 
		addl vy(%ebx), y(%ebx)

		#erase from screen
		movl $0, %eax

		movl x(%ebx), %edx
		movl y(%ebx), %ecx
		shrl $16, %edx
		shrl $16, %ecx
		imull $160, %edx
		imull $2, %ecx

		addl %ecx, %eax
		addl %edx, %eax

		movb $0x20, %cl
		push %edx
		call mp1_poke
		pop %edx

		jmp initial_loop

	update_missile:
		movl mp1_missile_list, %ebx # reset head pointer

		# 1. check if values of x and y are out of range
		movl x(%ebx), %edx
		shrl $16, %edx
		cmpl $0, %edx
		jb mp1_missile_remove
		cmpl $79, %edx
		ja mp1_missile_remove

		movl y(%ebx), %ecx
		shrl $16, %ecx
		cmpl $0, %ecx
		jb mp1_missile_remove
		cmpl $24, %ecx
		ja mp1_missile_remove

		# 2. check if reach destination
		cmpl %edx, dest_x(%ebx)
		jne check_explosion
		cmpl %ecx, DEST_Y(%ebx)
		je push_missile_explode

		check_explosion:
			cmpl $0, exploded(%ebx)
			je redraw_cities

		push_missile_explode:
			push %ebx
			call missile_explode
			pop %ebx

			cmpl $0, %eax
			je dec_exploded

			push %ebx
			call mp1_notify_user
			pop %ebx

		dec_exploded:
			sub $1, exploded(%ebx)

			cmpl $0, %ebx
			ja draw_to_screen

			push %ebx
			call mp1_missile_remove
			pop %ebx

		draw_to_screen:
			movl $0, %eax
			movl x(%ebx), %edx
			movl y(%ebx), %ecx
			shrl $16, %edx
			shrl $16, %ecx
			imull $160, %edx
			imull $2, %ecx

			addl %ecx, %eax
			addl %edx, %eax

			movb $64, %cl
			push %edx
			call mp1_poke
			pop %edx

		# still need to make update missile iterative 


		# iterate through base alive
		# check if byte > 0
		# draw alive city
		# otherwise draw dead city
		
		redraw_cities:
			movzbl base_alive, %ebx # grabs top most bit
			cmpl $0, %ebx

			ja alive1
			leal dead_base_pic, %edi

			jmp draw_city_1
			alive1:
				leal base_pic, %esi
			

			draw_city_1:
				movl $18, %edi  # x character

			loop1:
				cmpl $22, %edi
				jmp loop2
				imull $2, %edi
				movl $3840, %eax
				addl %edi, %eax
				movl (%esi), %ecx
				push %edx
				shrl $1, %edi
				addl $1, %edi
				addl $1, %esi
				jmp loop1

			movzbl 1(base_alive), %ebx
			cmpl $0, %ebx
			ja alive2
			leal dead_base_pic, %edi

			jmp draw_city_2
			alive2:
				leal base_pic, %esi

			movl $38, %edi

			loop2:
				cmpl $42, %edi
				jmp loop2
				imull $2, %edi
				movl $3840, %eax
				addl %edi, %eax
				movl (%esi), %ecx
				push %edx
				shrl $1, %edi
				addl $1, %edi
				addl $1, %esi
				jmp loop2

			movzbl 2(base_alive), %ebx
			cmpl $0, %ebx
			ja alive3
			leal dead_base_pic, %edi

			jmp draw_city_3
			alive3:
				leal base_pic, %esi

			movl $58, %edi
			
			loop3:
				cmpl $62, %edi
				jmp loop2
				imull $2, %edi
				movl $3840, %eax
				addl %edi, %eax
				movl (%esi), %ecx
				push %edx
				shrl $1, %edi
				addl $1, %edi
				addl $1, %esi
				jmp loop3

		# redraw crosshairs
			imull $160, crosshairs_y, %ebx
			imull $2, crosshairs_x, %esi

			addl %ebx, %eax
			addl %esi, %eax

			movb $0x2A, %cl


			push %edx
			call mp1_poke
			pop %edx

		pop %edi
		pop %esi
		pop %ebx
		leave
		ret

# int mp1_ioctl(unsigned long arg, unsigned int cmd)
# The dispatch function for the MP1 ioctls - should use the cmd argument
# and a jumptable to execute one of the specific ioctls implemented below.
# Inputs   : unsigned long arg - parameter to the mp1_ioctl_....
#          : unsigned int cmd  - specifies which mp1_ioctl_... function 
#          :                     to execute
# Outputs  : Returns an integer - depends on which ioctl() function is called
# Registers: Standard C calling convention

.globl mp1_ioctl
mp1_ioctl:
		movl 8(%esp), %ebx
		cmpl $4, %ebx
		ja mp1_ioctl_invalid
		cmpl $0, %ebx
		jb mp1_ioctl_invalid
		jmp *jumptable(, %ebx, 4)
		ret



# ----------------- Functions private to this file -------------------

# 1. check if x and y are within range
# 2. check if reach destination or currently exploding
# 3. check if moving towards destination
/*update_missiles:
		ret

# x < 0 or x > 79 
# y < 0 or y > 24
# call remove missile function

out_of_range:
		# pushl %ebp # curr pointer
		# movl %mp1_missile_list, %ebp
		# pushl %ebx # temp for comparing bounds value
		# pushl %esi 
		# pushl %edi

		# movl x(%ebp), %ebx
		# cmpl $0, %ebx
		# jump if ebx less than 0
		# cmpl $79, %ebx
		# jump if ebx greater than 79
		# movl y(%ebp), %ebx
		# cmpl $0, %ebx
		# jump if ebx < 0
		# cmpl $24, %ebx
		# jump if ebx > 24
		ret

remove:
		# call mp1_missile_remove

		# popl %edi
		# popl %esi
		# popl %ebx
		# leave
		ret

# if x == dest_x and y == DEST_Y
# or explosion duration_counter == 0
reach_or_explod:
		ret

mov_to_dest:
		ret


# do I erase from screen here?
# remove from linked list
# free struct missile using mp1_free
mp1_missile_remove:
		ret

# check greater than 3, jump to invalid 
# check less than 0, jump to invalid
# otherwise jump to cmd *4 */
		

jumptable: 
.long mp1_ioctl_startgame, mp1_ioctl_addmissile, mp1_ioctl_movexhairs, mp1_ioctl_getstatus, mp1_ioctl_endgame

mp1_ioctl_startgame:
# what am i initilaizing??? mp1_missile_list, base_alive, mp1_score
		pushl %ebp # save old fram pointer
		movl %esp, %ebp # point to new frame
		pushl %ebx # temp for comparing bounds value
		pushl %esi 
		pushl %edi

		movl $0, mp1_missile_list
		movl $0x10101000, base_alive
		movl $0, mp1_score
# set xhair
		movl $40, crosshairs_x
		movl $12, crosshairs_y

		 

		pop %edi
		pop %esi
		pop %ebx
		leave
		ret

mp1_ioctl_addmissile:
		pushl %ebp # save old fram pointer
		movl %esp, %ebp # point to new frame
		pushl %ebx # temp for comparing bounds value
		pushl %esi 
		pushl %edi
		# copy_from_user
		push $33 # size of memory allocation 
		call mp1_malloc
		addl $4, %esp # update stack pointer
		cmpl $0, %eax # if failed to allocate space
		je mp1_ioctl_invalid

		push $33
		push %ebx # grab arg from ioctl
		push %eax
		call mp1_copy_from_user
		# deallocate memory
		addl $12, %esp

		cmpl $33, %eax
		jne mp1_ioctl_invalid

		movl mp1_missile_list, %esi
		movl %eax, mp1_missile_list
		movl %esi, NEXT(mp1_missile_list)

		movl %0, eax
		pop %edi
		pop %esi
		pop %ebx
		leave
		ret

mp1_ioctl_movexhairs:
		pushl %ebp # save old fram pointer
		movl %esp, %ebp # point to new frame
		pushl %ebx # temp for comparing bounds value
		pushl %esi 
		pushl %edi 

		movl $0, %eax
		imull $160, crosshairs_y, %ebx
		imull $2, crosshairs_x, %esi

		addl %ebx, %eax
		addl %esi, %eax

		movb $0x20, %cl

		call mp1_poke

		movl 8(%ebp), %ebx
		movl 8(%ebp), %esi

		sall $16, %ebx
		sarl $16, %ebx
		# andl $0x0000FFFF, %ebx # bitmasking for x
		# andl $0xFFFF0000, %esi # bitmasking for y
		sarl $16, %esi # shift right by is this 16 decimal or hex?

		add crosshairs_x, %ebx
		cmpl $79, %ebx
		jb valid_lowx
		movl $79, %ebx

	valid_lowx:
		cmpl $0, %ebx
		ja valid_x
		movl $0, %ebx
		
	valid_x: 
		movl %ebx, crosshairs_x

		add crosshairs_y, %esi
		cmpl $24, %esi
		jb valid_lowy
		movl $24, %esi

	valid_lowy:
		cmpl $0, %esi
		ja valid_y
		movl $0, %esi

	valid_y:
		movl %esi, crosshairs_y
		movl $0, %eax

		imull $160, crosshairs_y, %ebx
		imull $2, crosshairs_x, %esi

		addl %ebx, %eax
		addl %esi, %eax

		movb $0x2A, %cl


		push %edx
		call mp1_poke
		pop %edx

		pop %edi
		pop %esi
		pop %ebx

		
		leave
		ret


mp1_ioctl_getstatus:
		pushl %ebp # save old fram pointer
		movl %esp, %ebp # point to new frame
		pushl %ebx # temp for comparing bounds value
		pushl %esi 
		pushl %edi 

		movl 4(%esp), %ebx # grabs unsigned long x_hair_delta_packed
		xorl %ecx, %ecx
		mov mp1_score, %cx # stores mp1 score in lower 16 bits, might be cl

		movl base_alive, %esi
		andl 0xFF000000, %esi
		cmpl $0, %esi # if it is greater than 0, base alive
		jbe add_17
		orl 0x00040000, %ecx
		
	add_17:	
		movl base_alive, %esi
		andl 0x00FF0000, %esi
		cmpl $0, %esi # if it is greater than 0, base alive
		jbe add_16
		orl 0x00020000, %ecx

	add_16:

		movl base_alive, %esi
		andl 0x0000FF00, %esi
		cmpl $0, %esi
		jbe copy
		orl 0x00010000, %ecx

	copy:
		orl $0, %ecx # adds 16 bit to unsigned long
		# copy_to_user: unsigned long mp1_copy_to_user (void *to, const void *from, unsigned long n)
		push $4
		push %ecx
		push %ebx
		call mp1_copy_to_user
		
		pop %edi
		pop %esi
		pop %ebx

		leave 
		ret

mp1_ioctl_endgame:
		pushl %ebp # save old fram pointer
		movl %esp, %ebp # point to new frame
		pushl %ebx # temp for comparing bounds value
		pushl %esi 
		pushl %edi 

		movl mp1_missile_list, %ebx

	loop:
		movl next(%ebx), %esi
		cmpl $0, %ebx
		je done
		pushl %ebx
		call mp1_free
		movl %esi, %ebx
		jmp loop
		# free if it isnt 
		# move to next 
		# loop back to top

	done:
		pop %edi
		pop %esi
		pop %ebx

		leave
		ret

mp1_ioctl_invalid:
	movl $-1, %eax

finish:
# pop, leave, ret
		# popl %edi
		# popl %esi
		# popl %ebx
		leave
		ret
