; -----------------------------------------------------------------------------
; Example: Game score in Binary Coded Decimal
; -----------------------------------------------------------------------------
; This is alternative approach to score_hex.asm. If you've never heard of BCD
; here's some reading: https://ehaskins.com/2018-01-30%20Z80%20DAA/
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
	ld	de,_SCRN0+$A0			; center it a bit
	ld	b,8				; it has 8 lines
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
	ld	hl,score
	ld	de,_SCRN0+$E7			; this points exactly at map coordinate where score string is stored
	ld	c,3				; score takes 3 bytes, each byte holds 2 digits
.copy						; copy from hram to vram without waiting for access since it's vblank
	ld	a,[hl+]				; get byte
	ld	b,a				; store it for further processing
	and	a,$F0				; leave upper nible, remove lower one
	swap	a				; swap nibbles with places, lower is upper now and upper is lower
	or	$30				; upper nibble is 3, lower keeps its value - we have valid number in ascii notation now
	ld	[de],a				; put it on screen - map actually
	inc	de				; next map entry
	ld	a,b				; restore byte and repeat process above to lower nibble
	and	a,$0F
	or	$30
	ld	[de],a
	inc	de
	dec	c				; repeat 3 times
	jr	nz,.copy

	reti


;-------------------------------------------------------------------------------	
parse_input:
;-------------------------------------------------------------------------------

	call	read_keys			; read joypad

.btn_a
	bit	0,c				; is button a pressed ? (bit must be 1)
	jr	z,.btn_b			; no, check other key (apparently it's 0)
	ld	bc,1				; 1 - thousands and hundreds
	ld	a,$30				; increase score by 3000
	call	increase_score			; read explanation there
	ret

.btn_b
	bit	1,c				; ...
	jr	z,.right
	ld	bc,1
	ld	a,$30				; decrease score by 3000
	call	decrease_score
	ret

.right
	bit	4,b				; b has no debounce check, counter will be increasing while button is pressed
	jr	z,.left
	ld	bc,2				; 2 - tens and ones
	ld	a,$01				; increase score by 1
	call	increase_score
	ret

.left
	bit	5,b
	jr	z,.up
	ld	bc,2
	ld	a,$01				; decrease score by 1
	call	decrease_score
	ret

.up
	bit	6,c
	jr	z,.down
	ld	bc,2				; 2 - tens and ones
	ld	a,$20				; increase score by 20
	call	increase_score
	ret

.down
	bit	7,c
	jr	z,.done
	ld	bc,2
	ld	a,$20				; decrease score by 20
	call	decrease_score

.done
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
increase_score:
;-------------------------------------------------------------------------------
; score consists of 3 bytes, each byte holds two digits in bcd format ie. 00 - 99

; bc - points to a pair of digits in score
;      0 - hundreds of thousands and tens of thousands, 1 - thousands and hundreds, 2 - tens and ones

; a  - value of register (upper/lower byte) decides which digit gets increased, use bcd values only ie. $01, $20, $09, etc.

; hl - score offset in ram

	ld	hl,score			; get offset
	add	hl,bc				; move to a pair of digits to be updated
	inc	c				; recycle pointer to a counter of pair of digits left

	add	a,[hl]				; add selected pair of digits to value
	daa					; keep result as bcd
	ld	[hl-],a				; store it and move to another pair of digits
	ret	nc				; carry flag is set when overflow occurs (ie. $99 + $20 = $19), we need to update other pairs then

.recurse
	dec	c				; counter keeps track of pair of digits we're dealing with
	ret	z
	ld	a,b				; b = 0 here, we save 1 byte and 4 cycles by not using ld b,0
	adc	a,[hl]				; carry flag is set so 1 will be added to adjacent pair of digits
	daa					; keep result as bcd
	ld	[hl-],a				; store it
	call	c,.recurse			; if there's overflow go to another pair of digits (update the rest of the score)
	ret

;-------------------------------------------------------------------------------
decrease_score:
;-------------------------------------------------------------------------------
; clone of increase_score that does subtraction, look at the comments above

	ld	hl,score
	add	hl,bc
	inc	c

	ld	b,a
	ld	a,[hl]
	sub	a,b
	daa
	ld	[hl-],a
	ret	nc
	ld	b,0

.recurse
	dec	c
	ret	z
	ld	a,[hl]
	sbc	a,b
	daa
	ld	[hl-],a
	call	c,.recurse
	ret
	

;-------------------------------------------------------------------------------

font:
        INCBIN	"font_8x8.chr"			; converted with https://github.com/gitendo/bmp2cgb

text:
	DB	"       Score:       "
	DB	"                    "
	DB	"       00000        "
	DB	"                    "
	DB	"  Press UP or DOWN, "
	DB	"   LEFT or RIGHT,   "
	DB	"      A or B        "
	DB	"  to update score.  "

;-------------------------------------------------------------------------------


	SECTION	"Variables",HRAM

score:		DS	3			; score in bcd format, ranges from 000000 to 999999, should be enough for most games ;)
current:	DS	1			; usually you read keys state and store it into variable for further processing
previous:	DS	1			; this is previous keys state used by debouncing part of read_keys function
