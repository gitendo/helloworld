; -----------------------------------------------------------------------------
; Example: Sprite collision example
; -----------------------------------------------------------------------------
; More examples by tmk @ https://github.com/gitendo/helloworld
; -----------------------------------------------------------------------------

	INCLUDE "hardware.inc"			; system defines

        SECTION "VBL",ROM0[$0040]		; vblank interrupt handler
	jp	vbl

	SECTION	"Start",ROM0[$100]		; start vector, followed by header data applied by rgbfix.exe
	nop
	jp	start

        SECTION "Example",ROM0[$150]		; code starts here

OAM_MIRROR	equ	$C000			; oam table mirror will be stored in RAM at $C000

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
	ld	[rOBP0],a			; obj palette for "enemy" sprites
	ld	a,%00111001			; and inverted for "hero" sprite
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

	ld	hl,oam_stub			; predefined values for 4 sprites used in this example
	ld	de,OAM_MIRROR			; sprites table in RAM
	ld	bc,16				; 4 sprites, each entry needs 4 bytes
	call	copy

	ld	hl,dir_stub			; predefined values for moving/speed directions (y, x) for each sprite
	ld	de,directions			; proper table in RAM
	ld	bc,4*2
	call	copy

	ld	a,IEF_VBLANK			; set up vblank interrupt
	ld	[rIE],a

	ld	a,LCDCF_ON | LCDCF_BG8000 | LCDCF_BG9800 | LCDCF_OBJ8 | LCDCF_OBJON | LCDCF_WINOFF | LCDCF_BGON
						; lcd setup: tiles at $8000, map at $9800, 8x8 sprites (enabled), no window, etc.
	ld	[rLCDC],a			; enable lcd

	ei					; enable interrupts

.loop
	halt					; save battery
;	nop					; nop after halt is mandatory but rgbasm takes care of it :)

	ldh	a,[frame]                       ; make sure functions below are executed every second frame
	and	a                               ; this is to faciliate seeing when collision happens and can be omitted
	jr	nz,.loop

	call	move_sprites			; move sprites around
	call	check_boundaries		; make sure they stay on the screen
	call	check_collision			; check if they collide and animate when that happens

	jr	.loop				; endless loop


;-------------------------------------------------------------------------------
vbl:
;-------------------------------------------------------------------------------
	push	af
	call	$FF80				; copy OAM_MIRROR table using DMA
	ldh	a,[frame]			; vbl is executed 60 times per second
	xor	1				; xoring frame variable causes it to have value of 1 every second frame
	ld	[frame],a			; this is used in main loop to slow sprites update - 30 fps instead of 60 fps
	pop	af
	reti


;-------------------------------------------------------------------------------
move_sprites:
;-------------------------------------------------------------------------------
	ld	de,OAM_MIRROR			; sprites table
	ld	hl,directions			; movement directions (y, x)
	ld	c,4				; number of sprites to move
.move
	ld	a,[de]				; get sprite y position
	add	a,[hl]				; depending on movement direction value increase or decrease it to move sprite up or down
	ld	[de],a				; store updated y position
	inc	e				; move to sprite x position
	inc	l				; move to x movement direction 
	ld	a,[de]				; get sprite x position
	add	a,[hl]				; depending on movement direction value increase or decrease it to move sprite left or right
	ld	[de],a				; store updated x position
	ld	a,3				; move to another sprite y position
	add	a,e
	ld	e,a
	inc	l				; move to another y movement direction 
	dec	c				; do another sprite
	jr	nz,.move
	ret


;-------------------------------------------------------------------------------
check_boundaries:
;-------------------------------------------------------------------------------
	ld	hl,OAM_MIRROR			; sprites table
	ld	de,directions			; movement directions (y, x) for each sprite
	ld	c,4				; number of sprites to check
.check_top
	ld	a,[hl+]				; get sprite y position
	cp	16				; top boundary
	jr	nz,.check_bottom		; not reached yet
	ld	a,1				; top reached, change direction to positive number to move sprite down
	ld	[de],a				; update y direction
	jr	.check_left			; no reason to check bottom boundary, do left
.check_bottom
	cp	152				; bottom boundary
	jr	nz,.check_left			; not reached yet
	ld	a,-1				; bottom reached, change direction to negative number to move sprite up
	ld	[de],a				; update y direction
.check_left
	inc	e				; move to x movement direction
	ld	a,[hl+]				; get sprite x position
	cp	8				; left boundary
	jr	nz,.check_right			; not reached yet
	ld	a,1				; left reached, change direction to positive number to move sprite right
	ld	[de],a				; update x direction
	jr	.next				; no reason to check right boundary, do next
.check_right
	cp	160				; right boundary
	jr	nz,.next			; not reached yet
	ld	a,-1				; right reached, change direction to negative number to move sprite left
	ld	[de],a				; update x direction
.next
	inc	e				; move to y direction (next pair)
	inc	l				; move to next sprite (skip tile and attribute bytes)
	inc	l
	dec	c				; do another sprite
	jr	nz,.check_top
	ret	
	

;-------------------------------------------------------------------------------
check_collision:
;-------------------------------------------------------------------------------
	ld	hl,OAM_MIRROR			; sprites table
	ld	c,3				; 1 "hero" sprite and 3 "enemy" sprites, for sake of simplicity we don't check collision between "enemy" sprites

	ld	a,[hl+]				; get "hero" sprite y position
	and	$F8				; strip 3 lower bits to get row where sprite is located (sprites in this example are 8x8 px)
	ld	d,a				; store it in d
	ld	a,[hl+]				; get "hero" sprite x position
	and	$F8				; strip 3 lower bits to get column where sprite is located
	ld	e,a				; store it in e
	inc	l				; move to next sprite
	inc	l
.next
	ld	b,0				; b holds tile number (0 - normal tile, 1 - collision tile) to perform animation during collision
	ld	a,[hl+]				; get "enemy" sprite y position
	and	$F8				; strip 3 lower bits to get row where sprite is located
	cp	d				; compare with "hero" sprite y position
	jr	nz,.l1				; skip if not equal
	ld	a,[hl+]				; get "enemy" sprite x position
	and	$F8				; strip 3 lower bits to get column where sprite is located
	cp	e				; compare with "hero" sprite x position
	jr	nz,.l2				; skip if not equal
	inc	b				; collision detected
	jr	.l2				; update tile
.l1
	inc	l				; move to tile byte of "enemy" sprite
.l2
	ld	a,b				; 0 - normal tile, 1 - collision tile
	ld	[hl+],a				; update "enemy" sprite tile
	inc	l				; move to next sprite data
	dec	c				; check another sprite
	jr	nz,.next
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
 	ld	a,$C0				; OAM table mirror in RAM at $C000 (high byte)
 	ld	[rDMA],a
 	ld	a,40				; delay = 160 cycles
.copy
 	dec	a
 	jr	nz,.copy
 	ret
dma_sub_end:

;-------------------------------------------------------------------------------


oam_stub:					; let's setup 4 sprites
	db	84,84,0,16
	db	84,84,0,0
	db	84,84,0,0
	db	84,84,0,0

dir_stub:					; (y, x) -1 = move up / left, 1 = move down / right
	db	-1, -1
	db	-1, 1
	db	1, -1
	db	1, 1

heart:
	db	$00,$6C,$6C,$92,$3C,$82,$7C,$C2,$7C,$82,$38,$44,$10,$28,$00,$10	; 1st heart tile 
	db	$6C,$6C,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$7C,$7C,$38,$38,$10,$10	; 2nd heart tile


;-------------------------------------------------------------------------------

	SECTION	"Variables",HRAM[$FF8A]		; $FF80 - $FF89 is taken by dma_sub function

directions:
	ds	4*2				; dir_stub will be copied here
frame:
	ds	1
