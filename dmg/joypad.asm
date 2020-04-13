; -----------------------------------------------------------------------------
; Example: Reading joypad state
; -----------------------------------------------------------------------------
; Font comes from ZX Spectrum - https://en.wikipedia.org/wiki/ZX_Spectrum_character_set
; More examples by tmk @ https://github.com/gitendo/helloworld
; -----------------------------------------------------------------------------

	INCLUDE "hardware.inc"			; system defines

        SECTION "VBL",ROM0[$0040]		; vblank interrupt handler
	jp	vbl

	SECTION	"Start",ROM0[$100]		; start vector, followed by header data applied by rgbfix.exe
	nop
	jp	start

        SECTION "Example",ROM0[$150]		; code starts here

start:
	di					; disable interrupts
	ld	sp,$E000			; setup stack

.wait_vbl					; wait for vblank to properly disable lcd
	ld	a,[rLY]	
	cp	$90
	jr	nz,.wait_vbl

	xor	a
	ld	[rIF],a				; reset important registers
	ld	[rLCDC],a
	ld	[rSTAT],a
	ld	[rSCX],a
	ld	[rSCY],a
	ld	[rLYC],a
	ld	[rIE],a

	ld	hl,_RAM                         ; clear ram (fill with a which is 0 here)
	ld	bc,$2000-2			; watch out for stack ;)
	call	fill

	ld	hl,_HRAM			; clear hram
	ld	c,$80				; a = 0, b = 0 here, so let's save a byte and 4 cycles (ld c,$80 - 2/8 vs ld bc,$80 - 3/12)
	call	fill

	ld	hl,_VRAM			; clear vram, lcdc is disabled so you have 'easy' access
	ld	b,$18				; a = 0, bc should be $1800; c = 0 here, so..
	call	fill

	ld	a,$20				; ascii code for 'space' character

						; no need to setup hl since _SCRN0 ($9800) and _SCRN1 ($9C00) are part of _VRAM, just continue

	ld	b,8				; bc should be $800 (_SCRN0/1 are 32*32 bytes); c = 0 here, so..
	call	fill

	ld	a,%10010011			; bits: 7-6 = 1st color, 5-4 = 2nd, 3-2 = 3rd and 1-0 = 4th color
						; color values: 00 - light, 01 - gray, 10 - dark gray, 11 - dark
	ld	[rBGP],a			; bg palette
	ld	[rOBP0],a			; obj palettes (not used in this example)
	ld	[rOBP1],a

	ld	hl,font				; font data
	ld	de,_VRAM+$200			; place it here to get ascii mapping ('space' code is $20, tile size $10)
	ld	bc,1776				; font_8x8.chr file size
	call 	copy

	ld	hl,text				; menu text
	ld	de,_SCRN0+$60			; center it a bit
	ld	b,11
	call	copy_text

	ld	a,IEF_VBLANK			; vblank interrupt
	ld	[rIE],a				; setup
	
	ld	a,LCDCF_ON | LCDCF_BG8000 | LCDCF_BG9800 | LCDCF_OBJ8 | LCDCF_OBJOFF | LCDCF_WINOFF | LCDCF_BGON
						; lcd setup: tiles at $8000, map at $9800, 8x8 sprites (disabled), no window, etc.
	ld	[rLCDC],a			; enable lcd

	ei					; enable interrupts

.loop
	call	parse_input			; read joypad and update inputs array that holds individual keys status
	halt					; save battery
;	nop					; nop after halt is mandatory but rgbasm takes care of it :)


	jr	.loop				; endless loop


vbl:						; update screen
	ld	hl,_SCRN0+$C5			; this points exactly at vram character between square brackets in 'Down' entry
	ld	bc,32				; next line, hl + bc will point to another entry

	ldh	a,[btn_dn]			; use ldh instead of ld to copy value from hram, it's one byte shorter and 8 cycles faster
	ld	[hl],a                          ; since it's vblank we have easy access to vram, update 1st entry
	add	hl,bc				; and go to another

	ldh	a,[btn_up]			; repeat 7 times ...
	ld	[hl],a
	add	hl,bc	

	ldh	a,[btn_lt]
	ld	[hl],a
	add	hl,bc	

	ldh	a,[btn_rt]
	ld	[hl],a
	add	hl,bc	

	ldh	a,[btn_st]
	ld	[hl],a
	add	hl,bc	

	ldh	a,[btn_sl]
	ld	[hl],a
	add	hl,bc	

	ldh	a,[btn_b]
	ld	[hl],a
	add	hl,bc	

	ldh	a,[btn_a]
	ld	[hl],a

	reti


;-------------------------------------------------------------------------------	
parse_input:
;-------------------------------------------------------------------------------

	ld	a,"-"				; button not pressed, you could write $2D instead
	ld	hl,inputs			; 8 byte array that holds individual keys status
	ld	c,8
.clear
	ld	[hl+],a				; mark all keys as not pressed
	dec	c
	jr	nz,.clear

	call	read_keys			; read joypad

	ld	a,"+"				; button pressed, you could write $2B instead
	dec	l				; hl points here to next byte after inputs array, move it back to point on btn_a
.btn_a
	bit	0,b				; is button a pressed ? (bit must be 1)
	jr	z,.btn_b			; no, check other key (apparently it's 0)
	ldh	[btn_a],a			; it is, mark it as +
.btn_b
	bit	1,b				; ...
	jr	z,.select
	ldh	[btn_b],a
.select
	bit	2,b
	jr	z,.start
	ldh	[btn_sl],a
.start
	bit	3,b
	jr	z,.right
	ldh	[btn_st],a
.right
	bit	4,b
	jr	z,.left
	ldh	[btn_rt],a
.left
	bit	5,b
	jr	z,.up
	ldh	[btn_lt],a
.up
	bit	6,b
	jr	z,.down
	ldh	[btn_up],a
.down
	bit	7,b
	ret	z
	ldh	[btn_dn],a

	ret


;-------------------------------------------------------------------------------	
copy:
;-------------------------------------------------------------------------------
; hl - source address
; de - destination
; bc - size

	inc	b
	inc	c
	jr	.skip
.copy
	ld	a,[hl+]
	ld	[de],a
	inc	de
.skip
	dec	c
	jr	nz,.copy
	dec	b
	jr	nz,.copy
	ret


;-------------------------------------------------------------------------------	
copy_text:
;-------------------------------------------------------------------------------
; hl - text to display
; de - _SCRN0 or _SCRN1
; b  - rows
; c  - columns

.next_row
	ld	c,20
.row
	ld	a,[hl+]				; fetch one byte from text array and increase hl to point to another one
	ld	[de],a				; store it at _SCRN0
	inc	de				; unfortunately there's no [de+]
	dec	c				; one byte done
	jr	nz,.row				; next byte, copy untill c=0

	ld	a,e				; our row = 20 which is what you can see on the screen
	add	a,12				; the part you don't see = 12, so we need to add it
	jr	nc,.skip			; to make sure the next row is copied at right offset
	inc	d                               ; nc flag is set when a+12 > 255
.skip
	ld	e,a

	dec	b				; next row, copy untill b=0
	jr	nz,.next_row
	ret


;-------------------------------------------------------------------------------
fill:
;-------------------------------------------------------------------------------
; a - byte to fill with
; hl - destination address
; bc - size of area to fill

	inc	b
	inc	c
	jr	.skip
.fill
	ld	[hl+],a
.skip
	dec	c
	jr	nz,.fill
	dec	b
	jr	nz,.fill
	ret


;-------------------------------------------------------------------------------
read_keys:
;-------------------------------------------------------------------------------
; this function returns two different values in b and c registers:
; b - returns raw state (pressing key triggers given action continuously as long as it's pressed - it does not prevent bouncing)
; c - returns debounced state (pressing key triggers given action only once - key must be released and pressed again)

        ld      a,$20				; read P15 - returns a, b, select, start
        ldh     [rP1],a        
        ldh     a,[rP1]				; mandatory
        ldh     a,[rP1]
	cpl					; rP1 returns not pressed keys as 1 and pressed as 0, invert it to make result more readable
        and     $0f				; lower nibble has a, b, select, start state
	swap	a				
	ld	b,a

        ld      a,$10				; read P14 - returns up, down, left, right
        ldh     [rP1],a
        ldh     a,[rP1]				; mandatory
        ldh     a,[rP1]
        ldh     a,[rP1]
        ldh     a,[rP1]
        ldh     a,[rP1]
        ldh     a,[rP1]
	cpl					; rP1 returns not pressed keys as 1 and pressed as 0, invert it to make result more readable
        and     $0f				; lower nibble has up, down, left, right state
	or	b				; combine P15 and P14 states in one byte
        ld      b,a				; store it

	ldh	a,[previous]			; this is when important part begins, load previous P15 & P14 state
	xor	b				; result will be 0 if it's the same as current read
	and	b				; keep buttons that were pressed during this read only
	ldh	[current],a			; store final result in variable and register
	ld	c,a
	ld	a,b				; current P15 & P14 state will be previous in next read
	ldh	[previous],a

	ld	a,$30				; reset rP1
        ldh     [rP1],a

	ret


;-------------------------------------------------------------------------------

font:
        INCBIN	"font_8x8.chr"			; converted with https://github.com/gitendo/bmp2cgb

text:
	DB	"   Joypad state:    "
	DB	"                    "
	DB	"                    "
	DB	"    [-] - Down      "
	DB	"    [-] - Up        "
	DB	"    [-] - Left      "
	DB	"    [-] - Right     "
	DB	"    [-] - Start     "
	DB	"    [-] - Select    "
	DB	"    [-] - B         "
	DB	"    [-] - A         "

;-------------------------------------------------------------------------------


	SECTION	"Variables",HRAM

current:	DS	1			; usually you read keys state and store it into variable for further processing
previous:	DS	1			; this is previous keys state used by debouncing part of read_keys function
inputs:						; array of buttons
btn_dn:		DS	1
btn_up:		DS	1
btn_lt:		DS	1
btn_rt:		DS	1
btn_st:		DS	1
btn_sl:		DS	1
btn_b:		DS	1
btn_a:		DS	1