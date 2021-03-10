; -----------------------------------------------------------------------------
; Example: ClockBoy - timer based clock
; -----------------------------------------------------------------------------
; Turn your GameBoy into clock by utilizing timer interrupt!
; Font comes from ZX Spectrum - https://en.wikipedia.org/wiki/ZX_Spectrum_character_set
; More examples by tmk @ https://github.com/gitendo/helloworld
; -----------------------------------------------------------------------------

	INCLUDE "hardware.inc"			; system defines

        SECTION "VBL",ROM0[$0040]		; vblank interrupt handler
	jp	vbl

        SECTION "TMR",ROM0[$0050]		; timer interrupt handler
	jp	tmr

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

	ld	hl,text				; clock menu text
	ld	de,_SCRN0+$80			; center it a bit
	ld	b,9				; it has 9 lines
	call	copy_text

	ld	a,$12				; set clock to 12:00:00:000
	ld	[hours],a
						; things are going to be more complicated here :)
						; timer consists of 3 registers:
						; - rTIMA (timer counter) which is automatically incremented at given intervals and when it overflows interrupt is generated
						; - rTMA (timer modulo), when rTIMA overflows rTMA value is reloaded into rTIMA so it always starts counting from that value
						; - rTAC (timer controller), enables / disables timer and allows to select frequency rTIMA is incremented with
						;	- there're 4 options: 4096 Hz, 16384 Hz, 65536 Hz and 262144 Hz but since Hz doesn't tell us much so we convert
						;	  them to count up pulses by dividing gameboy clock with them, ie. 4194304 Hz / 4096 Hz = 1024
						;
						; we know that gameboy clock speed is 4194304 Hz, 1 Hz means one cycle per second, so it does 4194304 clock cycles per second
						; our equation looks like this: 1024 * 256 (maximum rTMA value) * x = 4194304
						; so x = 16 therfore with timer frequency of 4096 Hz our interrupt will be triggered 16 times per second
						; we could also use some other rTMA value to trigger it more often or just change frequency, that really depends on scenario

	xor	a				; proper way of setting up timer
	ld	[rTMA],a			; we go for 256 increments after which interrupt is called
	ld	a,TACF_4KHZ			; 1st set up frequency / count up pulses
	ld	[rTAC],a
	or	TACF_START			; then enable timer
	ld	[rTAC],a

	ld	a,IEF_VBLANK | IEF_TIMER	; use vblank and timer interrupts
	ld	[rIE],a				; set up
	
	ld	a,LCDCF_ON | LCDCF_BG8000 | LCDCF_BG9800 | LCDCF_OBJ8 | LCDCF_OBJOFF | LCDCF_WINOFF | LCDCF_BGON
						; lcd setup: tiles at $8000, map at $9800, 8x8 sprites (disabled), no window, etc.
	ld	[rLCDC],a			; enable lcd

	ei					; enable interrupts

.loop
	halt					; save battery
;	nop					; nop after halt is mandatory but rgbasm takes care of it :)
	call	parse_input			; read joypad and handle pause mode
	jr	.loop				; endless loop


;-------------------------------------------------------------------------------	
vbl:						; update screen
;-------------------------------------------------------------------------------	

	push	af				; make sure to preserve original values when there's other code in main loop
	push	bc                              ; without it glitches are bound to happen
	push	de
	push	hl

	ld	hl,time
	ld	de,_SCRN0+$E4			; this points exactly at map coordinate where clock digits are stored
	ld	c,4				; clock takes 4 bytes and 1 nibble, each byte holds 2 digits
.copy						; copy from hram to vram without waiting for access since it's vblank
	ld	a,[hl+]				; get byte
	ld	b,a				; store it for further processing
	and	a,$F0				; leave upper nible, remove lower one
	swap	a				; swap nibbles with places, lower is upper now and upper is lower
	or	$30				; upper nibble is 3, lower keeps its value - we have valid number in ascii notation now
	ld	[de],a				; put it on the screen - map actually
	inc	de				; next map entry
	ld	a,b				; restore byte and repeat process above to lower nibble
	and	a,$0F
	or	$30
	ld	[de],a
	inc	de
	inc	de
	dec	c				; repeat 3 times
	jr	nz,.copy
	dec	de				; next map entry
	ld	a,[hl]				; here's last nibble that contains single milliseconds, lower one is not needed
	and	a,$F0				; process as above
	swap	a
	or	$30
	ld	[de],a

	pop	hl				; restore original values and return
	pop	de
	pop	bc
	pop	af
	reti

;-------------------------------------------------------------------------------	
tmr:                                            ; timer (i leave it unrolled so it's hopefully easier to read / understand)
;-------------------------------------------------------------------------------	

	push	af				; make sure to preserve original values since timer will be called also when main loop code is executed
	push	bc                              ; without it glitches are bound to happen
	push	hl

	ld	a,$25				; interrupt is executed 16 times per second, 1000 ms / 16 = 62,5 ms - this is decimal point value so we need to _be clever_ here
	ld	hl,milliseconds+1		; we use 3 nibbles for integers and 1 nibble for fractional part to store milliseconds, 4 nibbles = 2 bytes in total ($0625)
	add	a,[hl]				; let's add lower byte ($25)
	daa					; convert to bcd format
	ld	[hl-],a				; store and move hl to upper byte
	ld	b,a				; keep result in b
	ld	a,$06				; now the same with upper byte ($06)
	adc	a,[hl]				; add with carry here to increase upper byte when lower overflows
	daa					; convert to bcd format
	ld	[hl-],a				; store and move hl to seconds
	cp	b				; a = b when 1000 milliseconds have passed, they both will be 0 then (0 -> 62,5 -> 125 -> 187,5 -> (...) -> 937,5 -> 0)
	jr	nz,.done			; no need to update seconds yet

	ld	a,[hl]				; load seconds
	inc	a				; increase by 1
	daa					; convert to bcd format
	ld	[hl],a				; and store
	cp	$60				; 60 seconds passed?
	jr	nz,.done			; not yet
	xor	a				; reset seconds
	ld	[hl-],a				; update and move hl to minutes

	ld	a,[hl]				; same as above but minutes this time, a lot of duplicated code here that could be fit into smaller procedure
	inc	a
	daa
	ld	[hl],a
	cp	$60
	jr	nz,.done
	xor	a
	ld	[hl-],a

	ld	a,[hl]				; and again, hours this time
	inc	a
	daa
	ld	[hl],a
	cp	$24				; 24h ftw!
	jr	nz,.done
	xor	a
	ld	[hl],a

.done
	pop	hl				; restore original values and return
	pop	bc
	pop	af
	reti	


;-------------------------------------------------------------------------------	
parse_input:
;-------------------------------------------------------------------------------

	call	read_keys			; read joypad

.start
	bit	3,c				; key code is in c, see if start was pressed
	jr	z,.done                         ; not pressed

	ld	a,[rIE]				; get interrupt setup
	xor	IEF_TIMER			; turn timer on / off
	ld	[rIE],a				; update interrupt setup

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

font:
        INCBIN	"font_8x8.chr"			; converted with https://github.com/gitendo/bmp2cgb

text:
	DB	"      ClockBoy      "
	DB	"                    "
	DB	"                    "
	DB	"    00:00:00:000    "
	DB	"                    "
	DB	"                    "
	DB	"   Press Start to   "
	DB	"  pause the timer.  "
	DB	"                    "

;-------------------------------------------------------------------------------

	SECTION	"Variables",HRAM

time:
hours:		DS	1			; time in bcd format
minutes:	DS	1
seconds:	DS	1
milliseconds:	DS	2
current:	DS	1			; usually you read keys state and store it into variable for further processing
previous:	DS	1			; this is previous keys state used by debouncing part of read_keys function
