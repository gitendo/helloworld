; -----------------------------------------------------------------------------
; Example: Display picture composed of 355 unique tiles
; -----------------------------------------------------------------------------
; [gameboy demake] the secret of donkey kong island pixeled by tomic @ http://pixeljoint.com/pixelart/28278.htm
; More examples by tmk @ https://github.com/gitendo/helloworld
; -----------------------------------------------------------------------------

	INCLUDE "hardware.inc"			; system defines

        SECTION "VBL",ROM0[$0040]		; vblank interrupt handler
	jp	vbl

        SECTION "LCDC",ROM0[$0048]		; lcdc interrupt handler
	jp	lcdc


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
	ld	[rLYC],a
	ld	[rIE],a

	ld	hl,_RAM                         ; clear ram (fill with a which is 0 here)
	ld	bc,$2000-2			; watch out for stack ;)
	call	fill

	ld	hl,_HRAM			; clear hram
	ld	c,$80				; a = 0, b = 0 here, so let's save a byte and 4 cycles (ld c,$80 - 2/8 vs ld bc,$80 - 3/12)
	call	fill
						; no point in clearing vram, we'll overwrite it with picture data anyway
						; lcdc is already disabled so we have 'easy' access to vram

	ld	hl,picture_top_chr		; upper part takes 255 tiles
	ld	de,_VRAM			; place it between $8000-8FFF (tiles are numbered here from 0 to 255)
	ld	bc,4080				; tsodki1.chr file size
	call 	copy

	ld	hl,picture_bottom_chr		; bottom part takes 100 tiles
	ld	de,_VRAM+$1000			; place it between $8800-97FF (tiles are numbered here from -128 to 127)
	ld	bc,1600				; tsodki2.chr file size
	call 	copy

	ld	hl,picture_top_map		; picture's map upper part (padded to 32 columns, so we can easily copy it)
	ld	de,_SCRN0			; tile map at $9800
	ld	bc,416				; tsodki1.map file size
	call	copy

	ld	hl,picture_bottom_map		; picture's map bottom part (also padded)
						; de = _SCRN0+416, so we continue right after upper part
	ld	bc,160				; tsodki2.map file size
	call	copy

	ld	a,%00011011			; bits: 7-6 = 1st color, 5-4 = 2nd, 3-2 = 3rd and 1-0 = 4th color
						; color values: 00 - light, 01 - gray, 10 - dark gray, 11 - dark
	ld	[rBGP],a			; bg palette
	ld	[rOBP0],a			; obj palettes (not used in this example)
	ld	[rOBP1],a
	
	ld	a,104				; this is where upper part of picture ends and bottom starts, we'll switch map base here
	ld	[rLYC],a			; line at which lcdc interrupt will be fired
	ld	a,STATF_LYC			; important!
	ld	[rSTAT],a                       ; bit 6 needs to be set to make lcdc interrupt work

	ld	a,IEF_VBLANK | IEF_LCDC		; vblank and lcdc interrupts
	ld	[rIE],a				; setup

	ld	a,LCDCF_ON | LCDCF_BG8000 | LCDCF_BG9800 | LCDCF_OBJ8 | LCDCF_OBJOFF | LCDCF_WINOFF | LCDCF_BGON
						; lcd setup: tiles at $8000, map at $9800, 8x8 sprites (disabled), no window, etc.
	ld	[rLCDC],a			; enable lcd

	ei					; enable interrupts

.the_end
	halt					; save battery
;	nop					; nop after halt is mandatory but rgbasm takes care of it :)
	jr	.the_end			; endless loop


lcdc:						; lcdc interrupt - executed every frame when LY=104 (end of picture's upper part)
	ld	hl,rLCDC			; contains lcd setup
	res	4,[hl]				; change map location to $9C00, currently it's $9800
	reti

vbl:						; vblank interrupt - executed every frame when LY=144
	ld	hl,rLCDC			; contains lcd setup
	set	4,[hl]				; restore map location to $9800, currently it's $9C00
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

picture_top_chr:				; bmp2cgb -e255 tsodki1.bmp (there's no x,y,x/y duplicates)
        INCBIN	"tsodki1.chr"
picture_top_map:
	INCBIN	"tsodki1.map"
picture_bottom_chr:				; bmp2cgb -e255 tsodki1.bmp (there's no x,y,x/y duplicates)
        INCBIN	"tsodki2.chr"
picture_bottom_map:
	INCBIN	"tsodki2.map"
