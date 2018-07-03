.include "nes.h"
.include "rfk.h"
.include "mbyt.h"
.import chrWidths

.segment "CODE"

.proc load_field_graphics
  ; load palette
  lda #VBLANK_NMI
  sta PPUCTRL
  asl a
  sta PPUMASK
  ldx #$3F
  stx PPUADDR
  ldx #$15
  stx PPUADDR
  tax
:
  lda initial_palette,x
  sta PPUDATA
  inx
  cpx #$0F
  bcc :-

  ; Clear status bar
  ldx #$08  ; $80-$BF: tiles for left status
  jsr ppu_zero_nt
  ldx #$0C  ; $C0-$FF: tiles for right status
  jsr ppu_zero_nt
  ldx #$20
  jsr ppu_zero_nt

  ; Load status areas into nametable
  lda #$20
  sta PPUADDR
  asl a  ; A=$40
  sta PPUADDR
  asl a  ; C=0, A=$80
:
  jsr dohalfrow
  adc #$40
  jsr dohalfrow
  adc #<($10-$40)
  cmp #$C0
  bcc :-

  ; Dividing line at bottom of status bar
  jsr clearLineImg
  lda #7
  clc
:
  tax
  lda #$FF
  sta lineImgBuf,x
  txa
  adc #8
  bpl :-
  lda #$0B
  ldy #$00
  jsr copyLineImg
  lda #$0F
  ldy #$00
  jsr copyLineImg

  ; program title above the status
  jsr clearLineImg
  ldx #8  ; overscan: 8 on left and right, 16 on top and bottom
  lday #uctions1_txt
  jsr vwfPuts
  lday #$0808
  jsr copyLineImg
  jsr make_found_kittens_update
  lday #$0C08
  jsr copyLineImg
  jmp nkidisp_init

dohalfrow:
  ldy #16
  tax
:
  stx PPUDATA
  inx
  dey
  bne :-
  rts
.endproc

.proc load_item_shapes
ysave = 0
bitplane = 1
tilenum = 6
tilex = 7
  lda #2
  sta bitplane
planeloop:
  jsr clearLineImg
  ldy #NUM_ITEMS-1
loop:
  lda item_color,y
  and bitplane
  beq dontdraw
  tya
  asl a
  asl a
  sta tilex

  ; Convert item shape ID to a glyph number
  lda item_shape,y
  clc
  adc #'!'
  cmp #'#'  ; Skip robot glyph
  bne :+
  lda #$81
:
  cmp #'|'  ; vertical bar looks too much like capital i
  bne :+
  lda #$84
:
  ; If the pen advance of this glyph is less than or equal to 4,
  ; move it a pixel to the right to center it better
  tax
  lda #4
  cmp chrWidths-' ',x
  rol tilex

  ; Retrieve the glyph
  txa
  ldx tilex
  sty ysave
  jsr vwfPutTile
  ldy ysave
dontdraw:
  dey
  bpl loop

  ; Send the chosen glyphs to CHR RAM tiles $10-$1F
  ; plane 2 at $08, plane 01 at $00
  lda #$01
  ldy bitplane
  dey
  beq :+
  ldy #$08
:
  jsr copyLineImg
  lsr bitplane
  bne planeloop 
  
  ; Get the robot glyph in tile $0F, color 2
  jsr clearLineImg  ; clear bitplane 0
  lday #$0000
  jsr copyLineImg
  lda #'#'  ; heart glyph in tile $0F
  ldx #$0F << 3
  jsr vwfPutTile
  lda #$82  ; heart glyph in tile $0E
  ldx #$0E << 3
  jsr vwfPutTile
  lday #$0008
  jmp copyLineImg
.endproc

;;
; Draws the players' scores.
.proc make_found_kittens_update
  jsr clearLineImg
  lday #found_msg
  ldx found_kittens+0
  cpx #1
  bne not_singular
  lday #found1_msg
not_singular:
  ldx #18
  jsr vwfPuts

  lda found_kittens+1
  beq no_2p_kittens
  ldx #92
  jsr vwf_bcd8bit
no_2p_kittens:
  lda found_kittens+0
  ldx #10
  ; fall through
.endproc
.proc vwf_bcd8bit
highdigits = 0
xpos = 1
  stx xpos
  jsr bcd8bit
  ora #'0'
  jsr vwfPutTile
  ldy highdigits
  beq nohighdigits
  jsr onedigit
  lda highdigits
  lsr a
  lsr a
  lsr a
  lsr a
  beq nohighdigits
  tay
  
onedigit:  ; Move left 5px then draw low nibble of Y as digit
  lda xpos
  sec
  sbc #5
  sta xpos
  tax
  tya
  and #$0F
  ora #'0'
  jmp vwfPutTile

nohighdigits:
  rts
.endproc

.segment "RODATA"
initial_palette:
  ;     obj1     obj2     obj3   BDbg0
  mbyt "101010 FF122426 FF282A2C FF001020"
found_msg:
  .byte "kittens found",0
found1_msg:
  .byte "kitten found",0


