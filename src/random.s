;
; Random number generation for robotfindskitten clone
; Copyright 2014 Damian Yerrick
;
; Copying and distribution of this file, with or without
; modification, are permitted in any medium without royalty provided
; the copyright notice and this notice are preserved in all source
; code copies.  This file is offered as-is, without any warranty.
;
.include "rfk.inc"

; 0: Deal from the top third or so of the LRU deck (normal)
; >0: Cycle through the LRU deck (for testing)
NKI_INORDER = 0

; This is based on a routine by Greg Cook that implements
; a CRC-16 cycle in constant time, without tables.
; 39 bytes, 66 cycles, AXP clobbered, Y preserved.
; http://www.6502.org/source/integers/crc-more.html
; Setting seed to $FFFF and then taking
; CRC([$01 $02 $03 $04]) should evaluate to $89C3.

.segment "ZEROPAGE"
; Current value of CRC, not necessarily contiguous
CRCLO: .res 1
CRCHI: .res 1

.segment "CODE"

; If using CRC as a PRNG, use this entry point
.proc rand_crc
  lda #$00
.endproc
.proc crc16_update
        EOR CRCHI       ; A contained the data
        STA CRCHI       ; XOR it into high byte
        LSR             ; right shift A 4 bits
        LSR             ; to make top of x^12 term
        LSR             ; ($1...)
        LSR
        TAX             ; save it
        ASL             ; then make top of x^5 term
        EOR CRCLO       ; and XOR that with low byte
        STA CRCLO       ; and save
        TXA             ; restore partial term
        EOR CRCHI       ; and update high byte
        STA CRCHI       ; and save
        ASL             ; left shift three
        ASL             ; the rest of the terms
        ASL             ; have feedback from x^12
        TAX             ; save bottom of x^12
        ASL             ; left shift two more
        ASL             ; watch the carry flag
        EOR CRCHI       ; bottom of x^5 ($..2.)
        STA CRCHI       ; save high byte
        TXA             ; fetch temp value
        ROL             ; bottom of x^12, middle of x^5!
        EOR CRCLO       ; finally update low byte
        LDX CRCHI       ; then swap high and low bytes
        STA CRCHI
        STX CRCLO
        RTS
.endproc

; RFK randomization

.segment "BSS"
.assert NUM_NKIS <= 512, error, "too many NKI messages for the LRU buffer"
.assert SMEAR3 < $80, error, "nkilru assumes 7-bit random depth"
nkilru_buf: .res 1024

.segment "ZEROPAGE"
item_y: .res NUM_ITEMS  ; 0: kitten, 1-15: nki
cursor_y: .res 2
item_x: .res NUM_ITEMS
cursor_x: .res 2
item_color: .res NUM_ITEMS
item_typelo: .res NUM_ITEMS  ; needs to be in zp because 6502 lacks STY a,X

.segment "BSS"
item_typehi: .res NUM_ITEMS  ; bit 7 clear if unseen
item_shape: .res NUM_ITEMS

.segment "CODE"
.proc randomize_item_locs
randypos = 0
randxpos = 1
last_shape = 4

  ; lastshape ranges from $00 to $5F. Some values are slightly more
  ; likely than their neighbors, but another rand_crc call afterward
  ; should mix them adequately.
  jsr rand_crc
  lsr a
  clc
  adc CRCHI
  ror a
  lsr a
  sta last_shape

  ldy #0
itemloop:
reroll_position:
  jsr make_one_position
  sta randxpos
  tya
  tax
  jsr collision_with_first_x
  beq reroll_position
  lda randxpos
  sta item_x,y
  lda randypos
  sta item_y,y
  
  cpy #NUM_ITEMS
  bcs no_shape_needed
  lda #0
  sta item_typehi,y

reroll_shape:
  jsr rand_crc
  and #$3F
  clc
  adc last_shape
  cmp #96
  bcc :+
  sbc #96
:
  sta last_shape
  tya
  tax
  lda last_shape
continue_shapematch_search:
  dex
  bmi shape_is_unique
  cmp item_shape,x
  bne continue_shapematch_search
  beq reroll_shape
shape_is_unique:
  sta item_shape,y

  ; Colors need not be unique, but they do need to be 9-11 or 13-15
  jsr rand_crc
  lsr a
  clc
  adc CRCHI  ; 0-384
  and #$C0   ; 0-384 in steps of 64
  rol a
  rol a
  rol a      ; 0-5
  cmp #3     ; 0-2 or 3-5+C
  adc #9     ; 9-11 or 13-15
  sta item_color,y

no_shape_needed:
  iny
  cpy #NUM_ITEMS + 2
  bcc itemloop
  rts
.endproc


;;
; Check for collision
; @param 0: Y coordinate
; @param 1: X coordinate
; @return Z: set iff collision; X: item collided with or negative if wall
.proc collision_check
ypos = 0
xpos = 1
  lda ypos
  cmp #FIELD_H
  bcs hit_wall
  lda xpos
  cmp #FIELD_W
  bcc not_hit_wall
hit_wall:
  ldx #$FF  
  cpx #$FF
  rts
not_hit_wall:
  ldx #NUM_ITEMS+2
.endproc
.proc collision_with_first_x
ypos = 0
xpos = 1
  dex
  bmi done
  lda xpos
  cmp item_x,x
  bne collision_with_first_x
  lda ypos
  cmp item_y,x
  bne collision_with_first_x
done:
  rts
.endproc

.proc make_one_position
ypos = 0
accumlo = 1
accumhi = 2
accumbank = 3

  ; Two rounds of crc16 will generate a 16-bit value
  jsr rand_crc
  jsr rand_crc
  lda CRCLO
  sta accumlo
  lda CRCHI
  sta accumhi
  jsr timesthree
  ldx #3
  jsr times2tox
  sta ypos
  jsr timesthree
  ldx #4
times2tox:
  asl accumlo
  rol accumhi
  rol a
  dex
  bne times2tox
  rts

timesthree:
  lda #0
  sta accumbank
  ldx accumhi
  lda accumlo
  asl accumlo
  rol accumhi
  rol accumbank
  adc accumlo
  sta accumlo
  txa
  adc accumhi
  sta accumhi
  lda accumbank
  adc #0
  rts
.endproc

; The number of descriptions that correspond to NKIs, as opposed
; to the first two which are always kitten and robot respectively
NUM_REAL_NKIS = (NUM_NKIS - 2)

; SMEAR3 is one less than the power of two between one-fourth and
; one-half of NUM_REAL_NKIS.  This is used to pluck bits off the
; RNG as an index into the LRU state.
.if NKI_INORDER
  SMEAR3 = 0
.else
  SMEAR1 = (NUM_REAL_NKIS >> 2) | (NUM_REAL_NKIS >> 3)
  SMEAR2 = SMEAR1 | (SMEAR1 >> 2)
  SMEAR3 = SMEAR2 | (SMEAR2 >> 4)
.endif

.segment "CODE"
;;
; Loads the addresses of all NKI texts into the LRU buffer.
.proc nkilru_init
nkisleftlo = 0
nkislefthi = 1
dstptrlo = 2
dstptrhi = 3
srcptrlo = 4
srcptrhi = 5
  lday #-NUM_NKIS
  stay nkisleftlo
  lday #nkilru_buf
  stay dstptrlo
  lday #nki_descriptions
  stay srcptrlo
  ldy #0
loop:
  ; Copy the address of the current string to NKI buffer.
  ldy #0
  lda srcptrlo
  sta (dstptrlo),y
  lda srcptrhi
  iny
  sta (dstptrlo),y
  dey
  lda #2
  clc
  adc dstptrlo
  sta dstptrlo
  bcc :+
  inc dstptrhi
:
  ; Seek to the next NUL terminator.
find_nul_loop:
  lda (srcptrlo),y
  beq found_nul
  iny
  bne find_nul_loop
found_nul:
  tya
  sec
  adc srcptrlo
  sta srcptrlo
  bcc :+
  inc srcptrhi
:
  inc nkisleftlo
  bne loop
  inc nkislefthi
  bne loop
  rts
.endproc

SHUFFLE_SMEAR = (SMEAR3 << 1) | 1
;;
; A modified Fisher-Yates shuffle to get most of the NKIs out
; of order before the first simulation.  Instead of swapping
; with one of the next (n - i) elements, it swaps with one of
; the next 2^floor(log2(n)) elements, wrapping around.
; This involves no division.
.proc nkilru_shuffle
srcptrlo = 0
srcptrhi = 1
dstptrlo = 2
dstptrhi = 3
nkisleftlo = 4
nkislefthi = 5
rndchosen = 6
  lday #-NUM_REAL_NKIS
  stay nkisleftlo
  lday #(nkilru_buf + 4)
  stay srcptrlo
loop:
  jsr rand_crc
  and #<SHUFFLE_SMEAR
  sta rndchosen

  ; Get a pointer to item[i + r]
  ; here we use Y as MSB, the reverse of usual practice,
  ; to make it easier to catch a double carry
  ldy srcptrhi
  asl a
  bcc :+
  iny
  clc
:
  adc srcptrlo
  sta dstptrlo
  tya
  adc #0  ; this clears the carry so long as y wasn't $FF (and it wasn't)
  sta dstptrhi

  ; if (i - NUM_NKIS) + r >= 0, subtract NUM_REAL_NKIS
  lda rndchosen
  adc nkisleftlo
  lda #0
  adc nkislefthi
  bcc not_wraparound
  lda dstptrlo
  sbc #<(NUM_REAL_NKIS * 2)
  sta dstptrlo
  lda dstptrhi
  sbc #>(NUM_REAL_NKIS * 2)
  sta dstptrhi
not_wraparound:

  ; now perform the swap
  ldy #1
swaploop:
  lda (dstptrlo),y
  tax
  lda (srcptrlo),y
  sta (dstptrlo),y
  txa
  sta (srcptrlo),y
  dey
  bpl swaploop

  lda srcptrlo  ; ++srcptr
  clc
  adc #2
  sta srcptrlo
  bcc :+
  inc srcptrhi
:
  inc nkisleftlo
  bne loop
  inc nkislefthi
  bne loop
  rts
.endproc

;;
; Chooses one NKI text from the LRU buffer and shifts the following
; texts down by one.
.proc nkilru_get
chosenptrlo = 0
chosenptrhi = 1
dstptrlo = 2
dstptrhi = 3
srcptrlo = 4
srcptrhi = 5
nkisleftlo = 6
nkislefthi = 7

  .assert nkilru_buf < $2000, error, "nkilru assumes bss in RAM"
  jsr rand_crc
  and #<(SMEAR3 << 1)
  sta nkisleftlo  ; this is an offset into the LRU table
  
  ; Seek in the array of NKI description pointers
  clc
  adc #<(nkilru_buf + 4)
  sta dstptrlo
  ldy #0
  tya
  adc #>(nkilru_buf + 4)
  sta dstptrhi
  sta srcptrhi

  ; at this point carry is guaranteed clear because nkilru_buf
  ; is in RAM below $FEFC
  lda dstptrlo
  adc #2
  sta srcptrlo
  bcc :+
  inc srcptrhi
  clc
:
  ; calculate how many bytes to copy: nkisleft = -n
  lda nkisleftlo
  adc #<((1 - NUM_REAL_NKIS) * 2)
  sta nkisleftlo
  tya
  adc #>((1 - NUM_REAL_NKIS) * 2)
  sta nkislefthi

  ; Save the chosen NKI description's address to put it back
  ; at the end of the queue (and to return it)
  lda (dstptrlo),y
  sta chosenptrlo
  iny
  lda (dstptrlo),y
  sta chosenptrhi
  dey
copyloop:
  lda (srcptrlo),y
  sta (dstptrlo),y
  iny
  bne :+
  inc dstptrhi
  inc srcptrhi
:
  inc nkisleftlo
  bne copyloop
  inc nkislefthi
  bne copyloop

  ; And write the chosen description at the end
  lda chosenptrlo
  sta (dstptrlo),y
  iny
  lda chosenptrhi
  sta (dstptrlo),y
  ldy chosenptrlo
  rts
.endproc
