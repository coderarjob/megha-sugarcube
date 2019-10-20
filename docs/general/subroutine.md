## A study of the how to call subroutines without any side effects

Explicit call of the function
----------
we have to send arguments using AX, ES:BX, 
so if these registers were used to store some
other information, then they must be backed up 
and restored later after the call

```
; Inputs:
;	AX    - color of the text
; 	ES:BX - locaiton of the text that will be printed.
print:
	; does something to print text on the 
	; screen
	ret



	push ax
	push es
	push bx

	mov ax, 0x900
	mov es, ax
	mov bx, 0x100
	mov ax, BLACK
	call print

	pop bx
	pop es
	pop ax
```

Implicit call using macros
----------
we will take the explicit way and make a macro
that will force this pushing and poping as a pattern

```
%macro print 3
	pusha
	
	; following code is the same as the explicit version
	mov ax, %2
	mov es, ax
	mov bx, %3
	mov ax, %1
	call _print
	popa	
%endmacro

print WHITE, 0x900, 0x100
```
SUMMARY
--------
The inplicit way has the advantage to make the code more repliable and adhear
to the standard of pushing and popping.
What is bad is that this form of macro takes the developer farther from the
function that they are calling. 

CONCLUSION
----------
Macros can be provided by some helper script
but the OS kernel functions are going to be normal subroutines, that take
arguments from the registers. The first Argument will be in AX, and the second
in BX and so on. There ofcouse can be 6 arguments this way. When ever location
is specified a segment register will always be used.

WHY STACK CAN/CANNOT BE USED
------------------------
I first thought that stack cannot be used to pass arguments to kernel 
subroutines because the kernel and the user program can reside in different 
segments. This however is not true; when the user calls a subroutine in a
different segment, the stack registers is not changed. So the callee and caller
can pass data via stack.

