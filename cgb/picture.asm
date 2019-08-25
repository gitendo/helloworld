; display color picture composed of 247 unique tiles, 8 palettes by tmk @ https://github.com/gitendo/
; Yus Bird goes Gameboy Color pixeled by ptoing @ http://pixeljoint.com/pixelart/55124.htm

	INCLUDE "hardware.inc"			; system defines

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
	ld	[rVBK],a
	ld	[rSVBK],a
	ld	[rRP],a

	ld	hl,_RAM                         ; clear ram (fill with a which is 0 here)
	ld	bc,$2000-2			; watch out for stack ;)
	call	fill

	ld	hl,_HRAM			; clear hram
	ld	c,$80				; a = 0, b = 0 here, so let's save a byte and 4 cycles (ld c,$80 - 2/8 vs ld bc,$80 - 3/12)
	call	fill
						; no point in clearing vram, we'll overwrite it with picture data anyway
						; lcdc is already disabled so we have 'easy' access to vram

	ld	hl,picture_chr			; picture data
	ld	de,_VRAM			; place it between $8000-8FFF (tiles are numbered here from 0 to 255)
	ld	bc,3952				; gbhorror.chr file size
	call 	copy

	ld	hl,picture_map			; picture map (160x144px padded = 32*18)
	ld	de,_SCRN0			; place it at $9800
	ld	bc,576				; gbcyus.map file size
	call	copy

	ld	a,1				; switch to vram bank 1
	ld	[rVBK],a			; this is where we place attribute map

	ld	hl,picture_atr			; picture attributes
	ld	de,_SCRN0			; place it at $9800 just like map
	ld	bc,576				; gbcyus.atr file size
	call	copy

	xor	a				; switch back to vram bank 0
	ld	[rVBK],a

	ld	hl,picture_pal			; picture palette
	ld	b,64				; gbcyus.pal file size
						; 1 palette has 4 colors, 1 color takes 2 bytes, so 8 palettes = 64 bytes
	call	set_bg_pal

	
	ld	a,LCDCF_ON | LCDCF_BG8000 | LCDCF_BG9800 | LCDCF_OBJ8 | LCDCF_OBJOFF | LCDCF_WINOFF | LCDCF_BGON
						; lcd setup: tiles at $8000, map at $9800, 8x8 sprites (disabled), no window, etc.
	ld	[rLCDC],a			; enable lcd

.the_end
	halt					; save battery
;	nop					; nop after halt is mandatory but rgbasm takes care of it :)
	jr	.the_end			; endless loop


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
set_bg_pal:
;-------------------------------------------------------------------------------
	ld	a,%10000000			; bit 7 - enable palette auto increment
						; bits 5,4,3 - palette number (0-7)
						; bits 2,1 - color number (0-3)
	ld	[rBCPS],a			; we start from color #0 in palette #0 and let the hardware to auto increment those values while we copy palette data
.copy
	ld	a,[hl+]				; this is really basic = slow way of doing things
	ldh	[rBCPD],a
	dec	b
	jr	nz,.copy
	ret

;-------------------------------------------------------------------------------

picture_chr:					; bmp2cgb -e0 gbcyus.bmp
        INCBIN	"gbcyus.chr"
picture_map:
	INCBIN	"gbcyus.map"
picture_atr:
	INCBIN	"gbcyus.atr"
picture_pal:
	INCBIN	"gbcyus.pal"
