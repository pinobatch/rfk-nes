.include "nes.h"
.include "rfk.h"
.include "mbyt.h"
.import vwfChrWidths

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
  jsr clearLineImg
planeloop:
  ldy #NUM_ITEMS-1
loop:
  lda item_color,y
  and bitplane
  beq dontdraw
  tya
  asl a
  asl a
  asl a
  and #$7F  ; each line is 128 pixels long
  sta tilex

  ; Convert item shape ID to a glyph number
  lda item_shape,y
  clc
  adc #'!'  ; range: $21-$80
  
  ; Replace forbidden characters (too similar, too small) with
  ; other characters from $81 on up
  ldx #num_forbidden_chars
forbidden_check:
  cmp forbidden_chars-1,x
  bne :+
  txa
  ora #$80
  bmi forbidden_done
:
  dex
  bne forbidden_check
forbidden_done:
  ; Center the glyph in the 8x8 cell based on its pen advance
  tax
  lda #8
  sec
  sbc vwfChrWidths-' ',x
  lsr a
  clc
  adc tilex
  sta tilex

  ; Retrieve the glyph
  txa
  ldx tilex
  sty ysave
  jsr vwfPutTile
  ldy ysave
dontdraw:
  tya
  and #$0F
  bne dontcopy
  tya
  pha

  ; Send the chosen glyphs starting at CHR RAM tile $10
  lsr a
  lsr a
  lsr a
  lsr a
  adc #$01  ; first row at $010x, second at $020x
  ldy bitplane
  dey
  beq :+
  ldy #$08  ; first plane at $xxx0, second at $xxx8
:
  jsr copyLineImg
  jsr clearLineImg
  pla
  tay
dontcopy:
  dey
  bpl loop
  lsr bitplane
  bne planeloop 
  
  ; Get the robot glyph in tile $0F, color 2
  jsr clearLineImg  ; clear bitplane 0
  lday #$0000
  jsr copyLineImg
  lda #'#'  ; heart glyph in tile $0F
  ldx #($0F << 3) + 1
  jsr vwfPutTile
  lda #$82  ; heart glyph in tile $0E
  ldx #$0E << 3
  jsr vwfPutTile
  lday #$0008
  jmp copyLineImg
.pushseg
.segment "RODATA"
forbidden_chars:  ; These get reassigned to sequential glyphs $81+
  .byte '#'  ; skip robot glyph
  .byte ','  ; too similar to apostrophe
  .byte '.'  ; too small to see in some cases
  .byte '|'  ; too similar to capital I
  .byte '_'  ; too similar to hyphen
num_forbidden_chars = * - forbidden_chars
.popseg
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


