; This is a demo program that is used to test the Process Switching

	org 0x10

	xchg bx, bx
	mov eax, 1
	mov ebx, 1

	push dword 5
	; Create a new Process
	mov bx, K_PROCESS_CREATE

	mov ax, cs
	mov cx, .filename
	mov dx, 0x1
	int 0x40

	; Jump to it
	xchg bx, bx
	mov bx, K_PROCESS_SWITCH
	int 0x40

	xchg bx, bx
	pop ebx

	; No exit for now

.filename: db "DEMO    COM"

%include "../include/mos.inc"
