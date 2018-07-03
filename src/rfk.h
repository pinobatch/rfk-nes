.ifndef RFK_H
.define RFK_H

FIELD_W = 48
FIELD_H = 24

.macro lday arg
  .local argvalue
  .if (.match (.left (1, {arg}), #))
    argvalue = .right(.tcount({arg})-1, {arg})
    lda #>argvalue
    .if .const(argvalue) && (>argvalue = <argvalue)
      tay
    .else
      ldy #<argvalue
    .endif
  .else
    argvalue = arg
    lda arg+1
    ldy arg
  .endif
.endmacro

.macro stay arg
  .local argvalue
  argvalue = arg
  sta arg+1
  sty arg
.endmacro

; main.s
.global OAM
.globalzp nmis
.globalzp cursor_y, cursor_x, cursor_dir, found_kittens

; bg.s
.global load_field_graphics, load_item_shapes
.global make_found_kittens_update

; pads.s
.globalzp cur_keys, new_keys, das_keys, das_timer
.global read_pads, autorepeat

; title.s
LF = 10
.global display_instructions, uctions1_txt

; ppuclear.s
.global ppu_clear_nt, ppu_zero_nt, ppu_clear_oam, ppu_screen_on

; random.s
; one kitten plus however many other items
; this counts kitten but not robots
NUM_ITEMS = 48
.globalzp CRCHI, CRCLO
.globalzp item_x, item_y, item_color, item_shape,  item_typelo
.global item_typehi
.global rand_crc, randomize_item_locs, collision_check
.global nkilru_init, nkilru_get, nkilru_shuffle, nkilru_buf

; vwf_draw.s
.global vwfPutTile, vwfPuts, vwfPuts0, vwfStrWidth, vwfStrWidth0
.global clearLineImg, copyLineImg, lineImgBuf
.global chrWidths

; nki.s
.globalzp nkireq, nkidst
.global NUM_NKIS, nki_descriptions, nki_replacements
.global nkidisp_init, nkidisp_prepare, nkidisp_copy

; bcd.s
.global bcd8bit

.endif
