 ; Dino Device 2 VWF by Normmatt

.gba				; Set the architecture to GBA
.open "rom/output.gba",0x08000000		; Open input.gba for output.
					; 0x08000000 will be used as the
					; header size
					
.macro adr,destReg,Address
here:
	.if (here & 2) != 0
		add destReg, r15, (Address-here)-2
	.else
		add destReg, r15, (Address-here)
	.endif
.endmacro

.org 0x0800D3F6
	bl NewLine

.org 0x0800D44C
	bl putChar
	b 0x0800D3D2

.org 0x0800D462
	bl EndTextBox

.org 0x083D0000 ; should be free space to put code
.definelabel Copy1BppCharacter,0x0800BD70


; r0 - character
; r1 - buffer?
putChar:
	PUSH    {R4-R7,LR}
	ADD     SP, #-0x24
	ADD     R4, R1, #0
	LSL     R0, R0, #0x10
	LSR     R0, R0, #0x10   ; Current Character
	LDRB    R1, [R4,#0xF]   ; CharColor
	LDRB    R2, [R4,#0x10]  ; bgColor
	LDRB    R3, [R4,#0x11]  ; shadowColor
	ADD     R5, SP, #4
	STR     R5, [SP]
	
	mov     r6, r0 ;store character for a second
	mov     r7, r2 ;store bg color
    BL      Copy1BppCharacter
	
	;mov r2, #5	; r2 = width, replace this with lookup table
	ldr r2, =WidthTable
	ldrb r2, [r2,r6]
	
	LDRH    R0, [R4,#0xC]
	LSL     R0, R0, #5
	LDR     R3, [R4,#4]
	ADD     R3, R3, R0
	
	mov     r0, #0x20
	add 	r4, r3, R0
	
	ldr r6, [overflow]
	ldrb r1, [r6]
	mov r5, r1	; r5 = current overflow
	add r1, r1, r2	; r1 will be new overflow, r2 is spare after this
	cmp r1, #8
	ble NoNewTile	; if overflow >8 move to next tile
    mov r2, #8
	sub r1, r1, r2
	; clear next tile
	mov r0, r4
	
	ldr r2, [mask]
	mul r2, r7 ; times 0x11111111 by the bg color pallete index
	str r2, [r0, #0]
	str r2, [r0, #4]
	str r2, [r0, #8]
	str r2, [r0, #12]
	str r2, [r0, #16]
	str r2, [r0, #20]
	str r2, [r0, #24]
	str r2, [r0, #28]
	
	; original code to increment stuff
	mov		r2, sp
	mov		r0, #0x38
	add		r2, r2, r0
	LDR     R0, [r2]
	ADD     R0, #2          ; inc tilemap address
	STR     R0, [r2]
	
	LDRH    R0, [R2,#0xC]
	ADD     R0, #1          ; int tile number
	STRH    R0, [R2,#0xC]


NoNewTile:
	strb r1, [r6]

	lsl r5, r5, 2	; *4, for 4bpp
	mov r6, #0x20	; i feel like this code should be somewhere else
	sub r6, r6, r5	; r6 is to shift the existing background

	mov r0, sp
	add r0, #4
	;r0 = font, r3 = VRAM, r4 = overflow tile, r5 will be shift

	bl PrintHalfChar

UpdateMapTile:
	mov		r4, sp
	mov		r0, #0x38
	add		r4, r4, r0
	
	LDR     R2, [R4]
	LDRB    R0, [R4,#0xE]
	LSL     R0, R0, #0xC
	LDRH    R1, [R4,#0xC]
	ORR     R0, R1
	STRH    R0, [R2]

	
putChar_Exit:
	ADD  	SP,#0x24
	POP     {R4-R7,PC}
	
PrintHalfChar:
	mov r7, 0	; r7 = loop counter

PrintHalfChar_loop:
	ldr r1, [r0,r7] ; sp = character data
	ldr r2, [r3,r7]
	lsl r1,r5
	lsl r2,r6	; shift out part of background to be overwritten
	lsr r2,r6	
	orr r1,r2
	str r1, [r3,r7]

	ldr r1, [r0,r7] ; now do overflow tile
	ldr r2, [r4,r7]
	lsr r1,r6	; swap shifts (i think this will work)
	lsr r2,r5
	lsl r2,r5	
	orr r1,r2
	str r1, [r4,r7]

	add r7,r7,4	; each row = 4 bytes
	cmp r7, #0x20	; are 8 rows printed?
	bne PrintHalfChar_loop
	bx r14

ResetOverflow:
	; reset overflow
	mov r0, #0
	ldr r1, [overflow]
	str r0, [r1]
	bx lr
	
 ;Reset overflow on new textbox call
NewTextBox:
	bl ResetOverflow	
	ldr r0, [NewTextBox_returnAdr]
	bx r0
	
 ;Reset overflow on end textbox call	
EndTextBox:
	bl ResetOverflow
	POP     {R0}
	BX      R0

	;ldr r0, [EndTextBox_returnAdr]
	;bx r0
	
 ;Reset overflow on wait for timer
WaitForTimer:
	bl ResetOverflow
	ldr r0, [WaitForTimer_returnAdr]
	bx r0
	
 ;Handle New Line
 ;r0 and r1 are free
NewLine:
	; reset overflow
	mov r0, #0
	ldr r1, [overflow]
	str r0, [r1]
	
	; original code to increment stuff
	LDRH    R0, [R5,#0xA]
	ADD     R0, #1
	bx lr
    
.align 4
EndTextBox_returnAdr:   .word 0x0800D34A+1
WaitForTimer_returnAdr: .word 0x08016100+1 ;is this even in this game?
NewTextBox_returnAdr:   .word 0x08016106+1 ;is this even in this game?
NewLine_returnAdr:      .word 0x0800D340+1
overflow:  .word 0x03000000  ; my notes say this is free
mask:      .word 0x11111111  ; mask
.pool

WidthTable:
.incbin asm/bin/menuWidthTable.bin

.close

 ; make sure to leave an empty line at the end
