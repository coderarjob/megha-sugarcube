; Basic Structures and Macros that will be used in the Kernel and also in
; application development.

%ifndef _KERNEL_INC_
	%define _KERNEL_INC_

	K_MAX_NOTIFICATION_COUNT EQU 10

	%macro PROC 1
		%1.Offset resw 1
		%1.Segmnet resw 1
		%1 EQU %1.Offset
	%endmacro

	struc K_NOTIFICATION_ITEM
		.Message resw 1
		.isBlocked resw 1
		PROC .Routine
	endstruc

	struc K_SYS_Q_ITEM
		.Message resw 1
		.Arg0 resw 1
		.Arg1 resw 1
	endstruc

%endif
