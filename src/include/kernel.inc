; Basic Structures and Macros that will be used in the Kernel and also in
; application development.

%ifndef _KERNEL_INC_
	%define _KERNEL_INC_

	MSG_NONE:		EQU 0
	MSG_KB_DOWN:	EQU 1
	MSG_KB_UP:		EQU 2

	ERR_NOTI_FULL:	EQU 10

	struc K_NOTIFICATION_ITEM
		.Message resw 1
		PROC .Routine
	endstruc

	struc K_MSG_Q_ITEM
		.Message resw 1
		.Arg0 resw 1
		.Arg1 resw 1
	endstruc

%endif
