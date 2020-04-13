; -----------------------------------------------------------------------------
; Example: Background scroll (clockwise)
; -----------------------------------------------------------------------------
; Optical Illusion pixeled by Phexion @ http://pixeljoint.com/pixelart/81815.htm
; More examples by tmk @ https://github.com/gitendo/helloworld
; -----------------------------------------------------------------------------

	INCLUDE "hardware.inc"			; system defines

        SECTION "V-Blank",ROM0[$0040]		; vblank interrupt handler
	jp	vblank

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

	ld	hl,picture_chr			; picture data
	ld	de,_VRAM			; place it between $8000-8FFF (tiles are numbered here from 0 to 255)
	ld	bc,3872				; opti.chr file size
	call 	copy

	ld	hl,picture_map			; picture map (256x256px = 32*32) takes whole _SCRN0
	ld	de,_SCRN0			; place it at $9800
	ld	bc,3872				; opti.map file size
	call	copy

	ld	a,%00011011			; bits: 7-6 = 1st color, 5-4 = 2nd, 3-2 = 3rd and 1-0 = 4th color
						; color values: 00 - light, 01 - gray, 10 - dark gray, 11 - dark
	ld	[rBGP],a			; bg palette
	ld	[rOBP0],a			; obj palettes (not used in this example)
	ld	[rOBP1],a

	ld	a,IEF_VBLANK			; vblank interrupt
	ld	[rIE],a				; setup
	
	ld	a,LCDCF_ON | LCDCF_BG8000 | LCDCF_BG9800 | LCDCF_OBJ8 | LCDCF_OBJOFF | LCDCF_WINOFF | LCDCF_BGON
						; lcd setup: tiles at $8000, map at $9800, 8x8 sprites (disabled), no window, etc.
	ld	[rLCDC],a			; enable lcd

	ei					; enable interrupts

.the_end
	halt					; save battery
;	nop					; nop after halt is mandatory but rgbasm takes care of it :)
	jr	.the_end			; endless loop


vblank:
	ldh	a,[delay]			; fetch delay value, it's 0 after hram initialization
	xor	1				; (0 xor 1 = 1) then (1 xor 1 = 0) - this makes code bellow to be called every second frame
	ldh	[delay],a			; store delay value
	and	a				; check if a = 0
	jr	z,.scroll			; execute scroll part if so
	reti

.scroll
	ldh	a,[direction]			; first load direction value
.right
	cp	0				; move right if it's 0
	jr	nz,.down			; not 'right', check another direction
	ldh	a,[rSCX]			; increase scroll x
	inc	a
	ldh	[rSCX],a
	cp	96				; boundary (256 - 160)
	jr	nz,.r_done			; we haven't reached it yet
	ld	a,1				; boundary reached, change direction to 'down'
	ldh	[direction],a
.r_done
	reti

.down
	cp	1				; move down if it's 1
	jr	nz,.left			; not 'down', check another direction
	ldh	a,[rSCY]			; increase scroll y
	inc	a
	ldh	[rSCY],a
	cp	112				; boundary (256 - 144)
	jr	nz,.d_done			; we haven't reached it yet
	ld	a,2				; boundary reached, change direction to 'left'
	ldh	[direction],a
.d_done
	reti

.left
	cp	2				; move left if it's 2
	jr	nz,.up				; not 'left', check another direction
	ldh	a,[rSCX]			; decrease scroll x
	dec	a
	ldh	[rSCX],a
	and	a				; let's see if we reached starting point = 0
	jr	nz,.l_done                      ; nope
	ld	a,3				; true, change direction to 'up'
	ldh	[direction],a
.l_done

	reti

.up						; no point in checking direction here sinc it's last possibility
	ldh	a,[rSCY]			; decrease scroll y
	dec	a
	ldh	[rSCY],a
	and	a				; let's see if we reached starting point = 0
	jr	nz,.u_done                      ; nope
	xor	a				; true, change direction to 'right'
	ldh	[direction],a
.u_done
	reti


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

picture_chr:					; bmp2cgb -x -y -z opti.bmp
        INCBIN	"opti.chr"
picture_map:
	INCBIN	"opti.map"


	SECTION	"Variables",HRAM

delay:
	ds	1
direction:
	ds	1
