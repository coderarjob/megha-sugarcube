; DOS application to test circular queue

; The Queue structute
struc Q
	.length:	resb 2
	.width:		resb 2	; We only needed a byte, but a word is easier to work
						; with. Also some instructions like IMUL is more
						; flexible with word or double word.
	.head:		resb 2
	.tail:		resb 2
	.buffer:	resb 1 
endstruc
			
;	org 0x100
;
;	; 1st item
;	mov ax, ds
;	mov bx, word1
;	mov cx, ds
;	mov dx, word_queue
;	call queue_put
;
;	; 2nd item
;	lea bx, [word1 + 3]
;	call queue_put
;
;	; 1st dequeue
;	mov ax, ds
;	mov bx, word2
;	call queue_get
;
;	; 2nd dequeue
;	mov ax, ds
;	mov bx, word2
;	call queue_get		
;
;	; Exit DOS
;	mov ah, 0x4c
;	int 0x21
;
;word1: db "abc","def"
;word2: resb 3

; Gets one element from the top of the queue
; Input:
;	AX:BX 	- Pointer to data. WIDTH bytes will be copied from the queue.
;	CX:DX	- Pointer to queue.
; Output:
;	AX		- Number of bytes copied. 0 if queue empty.
queue_get:
; Algorithm:
; {
;	if (Q.head == Q.tail)
;		return EMPTY
;	Q.head = Q.head + 1 mod Q.length
;	return Q.buffer[Q.head]
; }

	push bx
	push di
	push dx
	push si
	push cx
	push ds
	push es
		
		; We need to have the data segments in proper registers
		mov es, ax		; Data Segmnet of destination.
		mov di, bx		; Address of the destination.

		mov ds, cx		; Data Segment of the queue.
		mov bx, dx		; Address of the queue.


		; Check if head == tail
		mov ax, [bx + Q.head]
		cmp ax, [bx + Q.tail]
		je .empty

		; head <> tail, we increment head and get the value.
		xor dx, dx
		inc ax
		div word [bx + Q.length]		; The new index is in DX

		; Read Q.buffer[DX * WIDTH] 
		mov si, dx						; DX cannot be used in LEA
		imul si, [bx + Q.width]
		lea si, [bx + Q.buffer + si] 	; Address to location in buffer.

		; Copy WIDTH bytes from DS:SI (Queue) to ES:DI (Destination pointer)
		mov cx, [bx + Q.width]		; Number of bytes in Queue item.
		rep movsb

		mov [bx + Q.head], dx		 ; Update head location

		; Success!! Read WIDTH into AX. 
		mov ax, [bx + Q.width]		 
		jmp .end
.empty:
	xor ax, ax
.end:
	pop es
	pop ds
	pop cx
	pop di
	pop dx
	pop di
	pop bx
	ret

; Put a value at the end of the queue
; Input:
;	AX:BX 	- Pointer to data. 
;			  WIDTH bytes will be copied to the queue buffer.
;	CX:DX 	- Pointer to queue
; Output:
;	AX		- Number of bytes copied. 0 if queue is full.
queue_put:
; Algorithm:
; {
;	if ((Q.tail + 1) mod Q.length) == Q.head
;		return FULL
;	Q.tail = (Q.tail + 1) mod Q.length
;	Q.buffer[Q.tail] = value
; }
	push dx
	push bx
	push di
	push si
	push cx
	push ds
	push es

		; Put Data Segment into proper registers
		mov ds, ax		; Data Segment of the queue item.
		mov si, bx		; Address of the queue item.

		mov es, cx		; Data Segment of the queue.
		mov bx, dx		; Address of the queue. DX cannot be part of 
						; Effective addressing.

		; Check if we can increment the TAIL.
		; That is if there is no room we will not add to the queue.
		xor dx, dx
		mov ax, [es:bx + Q.tail]
		inc ax
		div word [es:bx + Q.length]	; The new index in the Queue buffer is in
									; DX (the remainder)
		
		cmp dx, [es:bx + Q.head]
		je .full

		; There is room so we add to the queue.
		; Calculate the destination index in the buffer (new Tail value)

		mov di, dx					; DX cannot be used in effective addressing.
		imul di, [es:bx + Q.width]	; Each if the item in buffer is WIDTH bytes.
		lea di, [es:bx + Q.buffer + di]

		; Copy WIDTH bytes from DS:SI (Queue item) to ES:DI (Queue buffer)
		mov cx, [es:bx + Q.width]	
		rep movsb

		mov [es:bx + Q.tail], dx	; Update tail value

		; Success!! Read WIDTH into AX. WIDTH is 1 byte in size
		mov ax, [es:bx + Q.width]	
		jmp .end
.full:

	xor ax, ax
.end:
	pop es
	pop ds
	pop cx
	pop si
	pop di
	pop bx
	pop dx
	ret

; Queue instance
;word_queue:
;	.length:	dw 2
;	.width:		dw 3	
;	.head:		dw 0
;	.tail:		dw 0
;	.buffer:	resb 20
