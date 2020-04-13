; -----------------------------------------------------------------------------
; Example: Window
; -----------------------------------------------------------------------------
; [gameboy demake] pick up that can! pixeled by b236 @ http://pixeljoint.com/pixelart/129407.htm
; Press select to enable/disable window and use d-pad to change its coordinates.
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

	xor	a				; reset important registers
	ld	[rIF],a
	ld	[rLCDC],a
	ld	[rSTAT],a
	ld	[rSCX],a
	ld	[rSCY],a
	ld	[rWX],a
	ld	[rWY],a
	ld	[rIE],a

	ld	hl,_RAM                         ; clear ram (fill with a which is 0 here)
	ld	bc,$2000-2			; watch out for stack ;)
	call	fill

	ld	hl,_HRAM			; clear hram
	ld	c,$80				; a = 0, b = 0 here, so let's save a byte and 4 cycles (ld c,$80 - 2/8 vs ld bc,$80 - 3/12)
	call	fill
						; no point in clearing vram, we'll overwrite it with picture data anyway
						; lcdc is already disabled so we have 'easy' access to vram

	ld	hl,tiles			; picture tiles
	ld	de,_VRAM			; place it between $8000-8FFF (tiles are numbered here from 0 to 255)
	ld	bc,3040				; hlgbmcp.chr file size
	call 	copy

	ld	hl,bg_map			; main picture map (padded to 32 columns, so we can easily copy it)
	ld	de,_SCRN0			; store it at $9800
	ld	bc,576				; hlgbmcp_bg.map file size
	call	copy

	ld	hl,window_map			; dialog window map (also padded)
	ld	de,_SCRN1			; store it at $9C00
	ld	bc,576				; hlgbmcp_win.map file size
	call	copy

	ld	a,%00011011			; bits: 7-6 = 1st color, 5-4 = 2nd, 3-2 = 3rd and 1-0 = 4th color
						; color values: 00 - light, 01 - gray, 10 - dark gray, 11 - dark
	ld	[rBGP],a			; bg palette
	ld	[rOBP0],a			; obj palettes (not used in this example)
	ld	[rOBP1],a
	
	ld	a,7				; window x coordinate 
	ldh	[x],a				; 
	ld	a,112				; window y coordinate 
	ldh	[y],a				; 

	ld	a,IEF_VBLANK			; vblank interrupt
	ld	[rIE],a				; setup

	ld	a,LCDCF_ON | LCDCF_BG8000 | LCDCF_BG9800 | LCDCF_WIN9C00 | LCDCF_OBJ8 | LCDCF_OBJOFF | LCDCF_WINOFF | LCDCF_BGON
						; lcd setup: tiles at $8000, map at $9800, 8x8 sprites (disabled), window (disabled), etc.
	ld	[rLCDC],a			; enable lcd

	ei					; enable interrupts

.the_end
	halt					; save battery
;	nop					; nop after halt is mandatory but rgbasm takes care of it :)
	call	read_keys			; read joypad
	jr	.the_end			; endless loop


vbl:						; vblank interrupt - executed every frame when LY=144

						; please notice that b still contains [previous] key state
						; and c holds [current] one which is debounce free, 
						; there're no other functions in main loop so we don't have to reload them
.select
	bit	2,c				; check if select was pressed
	jr	z,.right
	ldh	a,[rLCDC]			; contains lcd setup
	xor	LCDCF_WINON			; if window is enabled it will be disabled and otherwise
	ldh	[rLCDC],a			; update lcd with window status
.right
	bit	4,b
	jr	z,.left
	ld	hl,x				; increase window x coordinate
	inc	[hl]
.left
	bit	5,b
	jr	z,.up
	ld	hl,x				; decrease window x coordinate
	dec	[hl]
.up
	bit	6,b
	jr	z,.down
	ld	hl,y				; decrease window y coordinate
	dec	[hl]
.down
	bit	7,b
	jr	z,.quit
	ld	hl,y				; increase window y coordinate
	inc	[hl]
.quit
	ldh	a,[x]				; rWX: 0 - 166 is valid
	ld	[rWX],a
	ldh	a,[y]				; rWY: 0 - 143 is valid
	ld	[rWY],a
						; rWX=7, rWY=0 locates the window at top left corner, completly covering background
	reti					; return from interrupt


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

tiles:						; bmp2cgb -x -y -z -e26 hlgbmcp.bmp 
        INCBIN	"hlgbmcp.chr"
bg_map:
	INCBIN	"hlgbmcp_bg.map"
window_map:
	INCBIN	"hlgbmcp_win.map"

;-------------------------------------------------------------------------------

	SECTION	"Variables",HRAM

current:	DS	1			; usually you read keys state and store it into variable for further processing
previous:	DS	1			; this is previous keys state used by debouncing part of read_keys function
x		DS	1
y		DS	1