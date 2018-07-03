.include "nes.h"
.include "rfk.h"

OAM = $0200

.segment "ZEROPAGE"
cur_keys: .res 2
new_keys: .res 2
das_keys: .res 2
das_timer: .res 2
found_kittens: .res 2
nmis:  .res 1
oam_used: .res 1
winner: .res 1
winner_time: .res 1

.segment "CODE"
.proc nmi
  inc nmis
.endproc
.proc irq
  rti
.endproc
.proc reset
  sei
  cld
  ldx #$FF
  txs
  inx
  stx PPUCTRL
  stx PPUMASK
  stx $4010   ; dmc irq off
  stx SNDCHN  ; audio off
  lda #$40
  sta P2      ; apu frame irq off
  bit PPUSTATUS  ; ack any pending nmi
  ; wait for end of first frame
:
  bit PPUSTATUS
  bpl :-

  ; TO DO here: init a whole bunch of other $#!+ like LRU
  ; first
  lda #0
  sta found_kittens+0
  sta found_kittens+1

  ; PPU should be warmed up by the start of the second frame, so
  ; wait for the end of the second frame to make sure
:
  bit PPUSTATUS
  bpl :-

  jsr nkilru_init
  jsr display_instructions
  jsr nkilru_shuffle

restart:
  lda nmis  ; Mix play time into PRNG entropy pool each game
  ora #$80  ; but CRC can't ever be 0
  eor CRCHI
  sta CRCHI
  jsr load_field_graphics
  jsr randomize_item_locs
  jsr load_item_shapes
  lda #$FF
  sta winner
  sta winner_time

gameloop:
  jsr read_pads
  ldx #1
  jsr move_player
  ldx #0
  stx oam_used
  jsr move_player

  jsr draw_item_sprites
  ldx oam_used
  jsr ppu_clear_oam
  jsr nkidisp_prepare
  jsr game_vsync
  ldx winner
  bmi gameloop
  inc found_kittens,x

successloop:
  jsr read_pads
  jsr nkidisp_prepare

  ; Reflect having incremented the number of found kittens.
  ; This cannot be done immediately upon entry to successloop
  ; because the kitten's description is still being displayed.
  lda winner_time
  cmp #224
  bne :+
  jsr make_found_kittens_update
  lda #$0C
  sta nkidst
:

  ldx #0
  stx oam_used
  jsr draw_success_sprites
  jsr draw_item_sprites
  ldx oam_used
  jsr ppu_clear_oam
  jsr game_vsync
  lda winner_time
  beq :+
  dec winner_time
  bne successloop
:
  lda new_keys
  ora new_keys+1
  and #KEY_START|KEY_A
  beq successloop
  jmp restart
.endproc

.proc game_vsync
  ; 10.5 Quitting
  ; A+B+Select+Start on controller 1 to reset the game
  lda cur_keys+0
  eor #$FF
  and #KEY_A|KEY_B|KEY_SELECT|KEY_START
  bne :+
  jmp ($FFFC)
:

  lda nmis
:
  cmp nmis
  beq :-
  lda #>OAM
  sta OAM_DMA
  jsr nkidisp_copy
  ldx #0
  ldy #0
  lda #VBLANK_NMI|BG_0000|OBJ_0000
  sec
  jmp ppu_screen_on
.endproc

.proc move_player
ypos = 0
xpos = 1
  jsr autorepeat
  lda cursor_y,x
  sta ypos
  lda cursor_x,x
  sta xpos
  txa
  tay
  lda new_keys,x

  ; try one key at a time
  lsr a
  bcc notRight
  inc xpos
  bcs try_writeback
notRight:
  lsr a
  bcc notLeft
  dec xpos
  bcs try_writeback
notLeft:
  lsr a
  bcc notDown
  inc ypos
  bcs try_writeback
notDown:
  lsr a
  bcc notUp
  dec ypos

try_writeback:
  jsr collision_check
  beq no_writeback
  lda xpos
  sta cursor_x,y
  lda ypos
  sta cursor_y,y
  rts
no_writeback:
  stx nkireq,y
  cpx #0
  bne no_winner
  sty winner
notUp:
no_winner:
  rts
.endproc

.proc draw_success_sprites
xbase = 0
xdisp = 1
  lda winner_time
  lsr a
  lsr a
  lsr a
  sta xdisp
  ldx winner
  lda winner_xbase,x
  sta xbase
  ldx oam_used

  ; Y coordinates
  lda #31
  ldy xdisp
  beq :+
  lda #255
:
  sta OAM,x  ; heart
  lda #39
  sta OAM+4,x  ; robot
  sta OAM+8,x  ; kitten
  
  lda #$0E  ; heart
  sta OAM+1,x
  lda #$0F  ; robot
  sta OAM+5,x
  lda #$10  ; kitten
  sta OAM+9,x

  lda #2
  sta OAM+2,x  ; heart
  lda #1
  sta OAM+6,x  ; robot
  lda item_color+0
  lsr a
  lsr a
  sta OAM+10,x  ; kitten
  
  lda xbase
  sta OAM+3,x  ; heart
  sec
  sbc xdisp
  sta OAM+7,x  ; robot
  lda xbase
  clc
  adc #5
  adc xdisp
  sta OAM+11,x  ; kitten
  
  txa
  clc
  adc #12
  sta oam_used
  rts
.pushseg
.segment "RODATA"
winner_xbase:
  .byte 64, 192
.popseg
.endproc

.proc draw_item_sprites
  ldx oam_used
  ldy #NUM_ITEMS+1  ; TO DO: NUM_ITEMS for 1 player or +1 for 2 player
loop:
  ; X = item x * 5 + 8
  lda item_x,y
  asl a
  asl a
  adc item_x,y
  adc #8
  sta OAM+3,x
  ; Y = item y * 7 + 48 - 1
  lda item_y,y
  asl a
  asl a
  asl a
  adc #48
  sbc item_y,y
  sta OAM+0,x
  ; Tile number = $0F for robot or $10-$1F for items
  tya
  cmp #NUM_ITEMS
  bcc :+
  lda #$FE
:
  adc #$10
  sta OAM+1,x

  ; Palette is bits 3-2 of item color
  lda item_color,y
  cpy #NUM_ITEMS
  bcc :+
  lda #4  ; robot is gray
:
  lsr a
  lsr a
  sta OAM+2,x

  inx
  inx
  inx
  inx
  dey
  bpl loop
  stx oam_used
  rts
.endproc

.segment "INESHDR"
  .byte "NES",$1A,$02,$00,$00,$00
.segment "VECTORS"
  .addr nmi, reset, irq
