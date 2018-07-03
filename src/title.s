.include "nes.h"
.include "rfk.h"
.include "mbyt.h"

NUM_PAGES = 5
.segment "CODE"

.proc display_instructions
  lda #>uctions1_txt
  ldy #<uctions1_txt
  ldx #KEY_A|KEY_START
.endproc
;;
; @param A high byte of nul-terminated text to display
; @param Y low byte
; @param X bitmask of which player 1 keys will close it
.proc display_txt_file
planedsthi = cursor_y  ; for each plane
planedstlo = cursor_x
ntdst = item_typelo+0
txtaddrlo = item_typelo+2
txtaddrhi = item_typelo+3
chrplane = item_typelo+4
bytes_used = item_typelo+5
exitkeys = item_typelo+6
  sty txtaddrlo
  sta txtaddrhi
  stx exitkeys
  lda #VBLANK_NMI
  sta PPUCTRL
  ldx #$00
  stx PPUMASK

  lda #$3F
  sta PPUADDR
  stx PPUADDR
:
  lda instructions_palette,x
  sta PPUDATA
  inx
  cpx #$10
  bcc :-

  ldx #$20
  jsr ppu_zero_nt
  ldx #$00
  jsr ppu_zero_nt

  ; Load the attributes for the text side
  lda #$23
  sta PPUADDR
  lda #$C8
  sta PPUADDR
  ldx #0
attrloop:
  lda #$00
  sta PPUDATA
  sta PPUDATA
  sta PPUDATA
  lda #%11111010
  and #%11001100  ; left half zero, right half xx
  sta PPUDATA
  lda #%11111010
  sta PPUDATA
  sta PPUDATA
  sta PPUDATA
  sta PPUDATA
  inx
  cpx #6
  bcc attrloop

  ; Start writing the text itself
  lda #$06
  sta planedsthi+1
  sta planedsthi+0
  lda #$08
  sta planedstlo+1
  lda #$00
  sta planedstlo+0
  lda #$20
  sta ntdst+1
  lda #$8E
  sta ntdst+0

load_todo_loop:
  jsr clearLineImg
  ldy txtaddrlo
  lda txtaddrhi
  ldx #0
  jsr vwfPuts
  sty txtaddrlo
  sta txtaddrhi

  ; Save the number of bytes used
  txa
  clc
  adc #7
  and #<-8
  sta bytes_used
  beq nowrite

  ; Copy tiles to the pattern table
  lda ntdst
  ldx #0
  and #$40
  beq :+
  inx
:
  stx chrplane

  lda planedsthi,x
  ldy planedstlo,x
  jsr copyLineImg
  lda #VBLANK_NMI
  sta PPUCTRL

  ; Write used tiles to the nametable
  lda bytes_used
  lsr a
  lsr a
  lsr a
  tax
  ldy chrplane
  lda planedsthi,y
  lsr a
  ora planedstlo,y
  ror a
  ror a
  ror a
  ror a
  tay
  lda ntdst+1
  sta 1
  lda ntdst
  sta 0
  lda #1
  jsr draw_1d_rect_to_bg

  ; Move data pointer to next tile
  ldx chrplane
  lda bytes_used
  asl a
  bcc :+
  inc planedsthi,x
  clc
:
  adc planedstlo,x
  bcc :+
  inc planedsthi,x
:
  sta planedstlo,x

nowrite:

  lda ntdst
  clc
  adc #32
  sta ntdst
  bcc :+
  inc ntdst+1
:
  lda ntdst+1
  cmp #$23
  bcc :+
  lda ntdst+0
  bmi load_todo_done
:
  jmp load_todo_loop
load_todo_done:

loop:
  lda nmis
:
  cmp nmis
  beq :-
  ldx #0
  ldy #0
  lda #VBLANK_NMI
  clc
  jsr ppu_screen_on
  jsr read_pads
;  jsr update_sound
  lda nmis
  sta CRCLO
  eor #$FF
  sta CRCHI
  lda new_keys
  and exitkeys
  beq loop
  rts
.endproc

;;
; @param Y starting tile number
; @param X width
; @param A height
; @param $00-$01 destination in nametable
.proc draw_1d_rect_to_bg
dstlo = 0
dsthi = 1
rows_left = 2
width = 3
  sta rows_left
  stx width
rowloop:
  lda dsthi
  sta PPUADDR
  lda dstlo
  sta PPUADDR
  clc
  adc #32
  sta dstlo
  bcc :+
  inc dsthi
:
  ldx width
tileloop:
  sty PPUDATA
  iny
  dex
  bne tileloop
  dec rows_left
  bne rowloop
  rts
.endproc

;;
; Clears 1024 bytes of video memory to 0.
; @param X high byte of starting address
.proc ppu_zero_nt
  lda #$00
  tay
  jmp ppu_clear_nt
.endproc

.segment "RODATA"
.import __RODATA_LOAD__, __RODATA_SIZE__, __CODE_LOAD__, __CODE_SIZE__
ROMSIZE = __CODE_SIZE__ + __RODATA_SIZE__ + 6
ROMPCT = (1000 * ROMSIZE + 16384) / 32768
; I started this project on Sun 2014-07-07 (base: 16258)
; but took a 100 day break to give forum.nesdev.com users
; time to evaluate Scoth42's implementation.
BUILDDAY = (.TIME / 86400) - 16358
instructions_palette:
  mbyt "FFFFFFFF FFFFFFFF FF10FF10 FFFF1010"
.if 0
titleguy_pb53:
  ; 64x80 pixel character
  .incbin "obj/nes/titleguy.chr.pb53"
.endif
uctions1_txt:
  .byte .sprintf("robotfindskitten 0.%d.", BUILDDAY)
  .byte '0'|<(NUM_NKIS / 100 .MOD 10)
  .byte '0'|<(NUM_NKIS / 10 .MOD 10)
  .byte '0'|<(NUM_NKIS .MOD 10),LF
  .incbin "uctions1.txt"
  .byte 0

