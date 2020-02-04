
; Tests the exit system call

	org 0x10

	xchg bx, bx
	nop
	nop
	mov ax, 1
	mov bx, K_PROCESS_EXIT
	int 0x40
	xchg bx, bx
	nop
	nop

%include "../include/mos.inc"
