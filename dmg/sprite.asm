; -----------------------------------------------------------------------------
; Example: Single, d-pad moveable sprite
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

	ld	hl,_VRAM			; clear vram
	ld	b,$18				; a = 0, bc should be $1800; c = 0 here, so..
	call	fill

	ld	a,2				; tile number to fill the _SCRN0 with - tiles 0, 1 are used for sprite, rest is empty

						; no need to setup hl since _SCRN0 ($9800) and _SCRN1 ($9C00) are part of _VRAM, just continue

	ld	b,8				; bc should be $800 (_SCRN0/1 are 32*32 bytes); c = 0 here, so..
	call	fill

	ld	a,%01101100			; bits: 7-6 = 1st color, 5-4 = 2nd, 3-2 = 3rd and 1-0 = 4th color
						; color values: 00 - light, 01 - gray, 10 - dark gray, 11 - dark
	ld	[rBGP],a			; bg palette
	ld	[rOBP0],a			; obj palettes
	ld	[rOBP1],a

	ld	hl,heart			; tiles used as sprites
	ld	de,_VRAM
	ld	bc,32				; two tiles, 16 bytes each
	call 	copy

	ld	c,$80				; dma sub will be copied to _HRAM, at $FF80
	ld	b,dma_sub_end-dma_sub_start	; size of dma sub, which is 10 bytes
	ld	hl,dma_sub_start		; dma sub code to be copied
.copy
	ld	a,[hl+]
	ld	[c],a
	inc	c
	dec	b
	jr	nz,.copy

	ld	a,80				; OAM table mirror is located at $C000, let's set up 1st sprite
	ld	[$C000],a			; y coordinate
	ld	a,84
	ld	[$C001],a			; x coordinate
						; sprite will use tile 0 and no attributes, we already zeroed whole RAM so no need to do it again

	ld	a,IEF_VBLANK			; set up vblank interrupt
	ld	[rIE],a

	ld	a,LCDCF_ON | LCDCF_BG8000 | LCDCF_BG9800 | LCDCF_OBJ8 | LCDCF_OBJON | LCDCF_WINOFF | LCDCF_BGON
						; lcd setup: tiles at $8000, map at $9800, 8x8 sprites (enabled), no window, etc.
	ld	[rLCDC],a			; enable lcd

	ei					; enable interrupts

.loop
	halt					; save battery
;	nop					; nop after halt is mandatory but rgbasm takes care of it :)

	call	read_keys			; read joypad
	ld	hl,$C000
.btn_a
	bit	0,b				; is button a pressed ? (bit must be 1)
	jr	z,.btn_b			; no, check other key (apparently it's 0)
	ld	l,2				; hl = $C002 which is 1st sprite in OAM table mirror, located at $C000
	xor	a				; change sprite to tile 0
	ld	[hl],a
.btn_b
	bit	1,b				; ...
	jr	z,.right
	ld	l,2
	ld	a,1				; change sprite to tile 1
	ld	[hl],a
.right
	bit	4,b
	jr	z,.left
	ld	l,1				; x coordinate
	inc	[hl]				; increase
.left
	bit	5,b
	jr	z,.up
	ld	l,1				; x coordinate
	dec	[hl]				; decrease
.up
	bit	6,b
	jr	z,.down
	ld	l,0				; y coordinate
	dec	[hl]				; decrease
.down
	bit	7,b
	jr	z,.loop
	ld	l,0				; y coordinate
	inc	[hl]				; increase

	jr	.loop				; endless loop


vbl:
	call	$FF80				; copy OAM mirror table using DMA
	reti

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
dma_sub_start:
;-------------------------------------------------------------------------------
	db	$3E,$C0				; 	ld	a,$C0           ; OAM table mirror in RAM at $C000 (high byte)
	db	$E0,$46				; 	ld	[rDMA],a
	db	$3E,$28				; 	ld	a,40		; delay = 160 cycles
                                                ;.copy
	db	$3D				; 	dec	a
	db	$20,$FD				; 	jr	nz,.copy
	db	$C9				; 	ret
dma_sub_end:

;-------------------------------------------------------------------------------

heart:
	db	$00,$6C,$6C,$92,$3C,$82,$7C,$C2,$7C,$82,$38,$44,$10,$28,$00,$10	; 1st heart tile 
	db	$6C,$6C,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$7C,$7C,$38,$38,$10,$10	; 2nd heart tile


;-------------------------------------------------------------------------------


	SECTION	"Variables",HRAM[$FF8A]		; $FF80 - $FF89 is taken by dma_sub function

current:	DS	1			; usually you read keys state and store it into variable for further processing
previous:	DS	1			; this is previous keys state used by debouncing part of read_keys function
