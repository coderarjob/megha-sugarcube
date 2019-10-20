
; Megha Operating System (MOS) Kernel 
; Version: 0.1 (180819)
;
;--------------------------------------------------------------------------
; The responsibilitiess of kernel includes:
;--------------------------------------------------------------------------
;
; * Process/Resident Program management: Start processes, kill them, keep 
;                    track of their health etc.
; * Provide system calls: File system, Timer, Process management.
; * Dynamic Memory management: Allocation and deallocation of memory as needed
;                              by external processes.
; * Interrupt handlers: IRQ0 etc.
; * Handling and despatch of messages
; * Baisic error reporting from the system calls and the drivers.
;--------------------------------------------------------------------------
; MAIN BODY
;--------------------------------------------------------------------------
; In MOS, all the moduels and programs is loaded at offset 0x64. The memory
; above this (0 to 0x63) is for future use.

	ORG 0x64
_init:
	retf

