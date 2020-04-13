; -----------------------------------------------------------------------------
; Example: Meta sprite
; -----------------------------------------------------------------------------
; Knight pixelled by Stratto @ http://pixeljoint.com/pixelart/52412.htm
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

	ld	a,$10				; tile number to fill the _SCRN0 with - 16 tiles is used for meta sprite, rest is empty

						; no need to setup hl since _SCRN0 ($9800) and _SCRN1 ($9C00) are part of _VRAM, just continue

	ld	b,8				; bc should be $800 (_SCRN0/1 are 32*32 bytes); c = 0 here, so..
	call	fill

	ld	a,%00011110			; bits: 7-6 = 1st color, 5-4 = 2nd, 3-2 = 3rd and 1-0 = 4th color
						; color values: 00 - light, 01 - gray, 10 - dark gray, 11 - dark
	ld	[rBGP],a			; bg palette
	ld	[rOBP0],a			; obj palettes
	ld	[rOBP1],a

	ld	hl,knight			; tiles used as sprites
	ld	de,_VRAM
	ld	bc,256				; tiles size
	call 	copy

	ld	c,$80				; dma sub will be copied to _HRAM, at $FF80
	ld	b,dma_sub_end-dma_sub_start	; size of dma sub, which is 10 bytes
	ld	hl,dma_sub_start		; dma sub code
.copy
	ld	a,[hl+]
	ld	[c],a
	inc	c
	dec	b
	jr	nz,.copy

	ld	hl,knight_oam_start		; precalculated part of OAM table that contains our meta sprite
	ld	de,_RAM				; OAM table mirror is located at $C000
	ld	bc,knight_oam_end-knight_oam_start
	call 	copy

	ld	a,IEF_VBLANK			; setup vblank interrupt
	ld	[rIE],a

	ld	a,LCDCF_ON | LCDCF_BG8000 | LCDCF_BG9800 | LCDCF_OBJ16 | LCDCF_OBJON | LCDCF_WINOFF | LCDCF_BGON
						; lcd setup: tiles at $8000, map at $9800, 8x16 sprites (enabled), no window, etc.
	ld	[rLCDC],a			; enable lcd

	ei					; enable interrupts

.the_end
	halt					; save battery
;	nop					; nop after halt is mandatory but rgbasm takes care of it :)
	jr	.the_end			; endless loop


vbl:
	call	$FF80
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

dma_sub_start:
	db	$3E,$C0				; 	ld	a,$C0           ; OAM table mirror in RAM at $C000
	db	$E0,$46				; 	ld	[rDMA],a
	db	$3E,$28				; 	ld	a,40		; delay = 160 cycles
                                                ;.copy
	db	$3D				; 	dec	a
	db	$20,$FD				; 	jr	nz,.copy
	db	$C9				; 	ret
dma_sub_end:

;-------------------------------------------------------------------------------

; knight gfx is 32x32 px, so when using 8x8 sprites tile order wouldn't need to be shuffled, they'd be stored one after another:

; 0 1 2 3 
; 4 5 6 7
; 8 9 a b
; c d e f

; but for 8x16 sprites we need to do place the tiles like this:

; 0 4 1 5
; 2 6 3 7
; 8 C 9 D
; A E B F

knight:
	db	$00,$00,$00,$00,$1C,$00,$12,$0C,$09,$06,$09,$06,$08,$07,$04,$03	; 0
	db	$04,$03,$02,$01,$01,$00,$00,$00,$03,$00,$04,$03,$08,$07,$10,$0F	; 4
	db	$00,$00,$07,$00,$18,$07,$26,$1F,$46,$3F,$9E,$7F,$9F,$7F,$1F,$FF	; 1
	db	$1E,$F1,$1F,$F0,$9F,$7E,$9F,$7E,$9F,$7E,$DF,$BF,$FF,$C0,$FF,$D0	; 5
	db	$00,$00,$00,$00,$C1,$00,$63,$C1,$77,$E3,$7F,$F3,$FF,$F7,$F7,$FE	; 2
	db	$DF,$BE,$DE,$3C,$BC,$70,$B8,$70,$AE,$70,$F1,$EE,$F9,$06,$F8,$17	; 6
	db	$00,$00,$00,$00,$C0,$00,$C0,$80,$80,$00,$80,$00,$80,$00,$00,$00	; 3
	db	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$30,$00,$D8,$30	; 7
	db	$10,$0F,$11,$0F,$0F,$00,$0F,$00,$0B,$07,$0B,$07,$0B,$07,$0B,$07	; 8
	db	$0B,$06,$0F,$00,$08,$07,$08,$07,$07,$00,$00,$00,$00,$00,$00,$00	; c
	db	$DF,$AF,$DF,$AE,$D6,$2D,$CC,$33,$D9,$37,$B3,$4E,$A7,$5C,$CE,$3B	; 9
	db	$9E,$77,$FB,$2C,$FF,$80,$FC,$00,$98,$60,$18,$60,$78,$00,$98,$60	; d
	db	$F8,$07,$FF,$C8,$7F,$C8,$EF,$98,$CC,$33,$DC,$E3,$FF,$18,$77,$F8	; a
	db	$77,$F8,$D7,$38,$FF,$00,$7E,$01,$C8,$37,$CF,$30,$F0,$00,$C8,$30	; e
	db	$8C,$78,$76,$8C,$FA,$04,$FB,$06,$7B,$86,$F9,$06,$52,$EC,$C4,$F8	; b
	db	$08,$F0,$90,$60,$20,$C0,$40,$80,$80,$00,$00,$00,$00,$00,$00,$00	; f

x	equ	72				; sprite x coordinate
y	equ	72				; sprite y xoordinate

;                     7        6       5       4      3       2        1        0    
; y, x, chr, atr (priority, v-flip, h-flip, dmg pal, bank, palette, palette, palette)

knight_oam_start:				; knight gfx is 32x32 px (16 tiles) but we use 8x16 sprites, so we need 8 of them
	db	y+00, x+00, $00, %00000000      ; 1st row
	db	y+00, x+08, $02, %00000000
	db	y+00, x+16, $04, %00000000
	db	y+00, x+24, $06, %00000000
	db	y+16, x+00, $08, %00000000	; 2nd row
	db	y+16, x+08, $0a, %00000000
	db	y+16, x+16, $0c, %00000000
	db	y+16, x+24, $0e, %00000000
knight_oam_end:
