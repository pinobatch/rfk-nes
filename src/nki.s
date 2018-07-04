.include "rfk.inc"
.include "mbyt.inc"

; BPE (Byte Pair Encoding) or DTE (Digram Tree Encoding)
; Code units $00-$7F map to literal ASCII characters.
; Code units $80-$FF map to pairs of code units.  The second
; is added to a stack, and the first is interpreted as above.

BPEBUFLEN = 80
NKI_MAXLINES = 3
.segment "BSS"
; This is used for byte pair encoding, the compression used for
; NKI text
bpebuf: .res BPEBUFLEN
bpetable = nki_replacements

.segment "CODE"
.proc bpe_decode
srcaddr = $00
  stay srcaddr
.endproc
.proc bpe_decode0
srcaddr = $00

  ; Copy the compressed data to the END of bpebuf.
  ; First calculate compressed data length
  ldy #0
strlenloop:
  lda (srcaddr),y
  beq have_strlen
  iny
  bne strlenloop
have_strlen:
  cpy #BPEBUFLEN
  bcc :+
  ldy #BPEBUFLEN
:
  ldx #BPEBUFLEN

  ; Now copy backward
poolypoc:
  dey
  dex
  lda (srcaddr),y
  sta bpebuf,x
  cpy #0
  bne poolypoc

  ; at this point, Y = 0, pointing to the decompressed data,
  ; and X points to the remaining compressed data
decomploop:
  lda bpebuf,x
decomp_code:
  bmi handle_bytepair
  sta bpebuf,y
  iny
  inx
  cpx #BPEBUFLEN
  bcc decomploop
  lda #0
  sta bpebuf,y
  rts

handle_bytepair:
  ; For a bytepair, stack the second byte on the compressed data
  ; and reprocess the first byte
  sty srcaddr
  asl a
  tay
  lda bpetable+1,y
  sta bpebuf,x
  dex
  lda bpetable,y
  ldy srcaddr
  ora #$00
  jmp decomp_code
.endproc

; test case not used in actual game
.if 0
.proc bpe_test
  lday #bpestr1
  jsr bpe_decode
  rts
.endproc
.pushseg
.segment "RODATA"
; This is supposed to spell "The fat cat sat on the mat."
bpetable:
  .byte $81,' ','a','t',$83,' ','h','e'
bpestr1:
  .byte "T",$82,"f",$80,"c",$80,"s",$80,"on t",$82,"m",$81,".",0
.popseg
.endif

; QUEUE MANAGEMENT ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


.segment "ZEROPAGE"

; offset into bpebuf of the beginning of the next line
nkisrc: .res 1

; high byte of CHR RAM address of the next line of NKI description.
; $x0-$x7: nothing
; $08: preparing LRU or DTE for a player
; $09-$0B: writing line 1, 2, or 3 of description
; $0C-$0F: same, but for player 2
nkidst: .res 1

; To request displaying the NKI for item n on player x's side,
; set nkireq[x] to n.
nkireq: .res 2
; A request will not start if nkireq[x] == nkicur[x], to avoid
; flicker during autorepeat.
nkicur: .res 2

.segment "CODE"

.proc nkidisp_init
  ; $FF in nkireq/cur: no item #
  ; $FF in nkidst: idle
  ldy #4
  lda #$FF
:
  sta nkidst,y
  dey
  bpl :-
  
  rts
.endproc

.proc nkidisp_prepare
  lda nkidst
  bmi is_idle
  cmp #$0D  ; $0D: finished drawing "2 kittens found" line
            ; ($4D means P2's NKI is decompressed and word wrapped)
  beq lastlinedone
  and #$03  ; $0C, $10: Finished drawing 3 lines of text
  beq lastlinedone
  
  ; A request is in progress. Draw it one line at a time.
  lda nkidst
  and #$1F
  sta nkidst

  ; prepare one line of text
  jsr clearLineImg
  lda #<bpebuf
  clc
  adc nkisrc
  tay
  lda #>bpebuf
  adc #0
zerobyte = * - 1
  ldx #8
  jsr vwfPuts
  ; now AAYY
  sec
  tya
  sbc #<bpebuf
  sta nkisrc
  
  rts

lastlinedone:
  lda #$FF
  sta nkidst
  ; And now we're idle.  Fall through.

is_idle:
  ; If idle right now, search for a request.  A request occurs when
  ; nkireq (the last touched NKI) differs from nkicur (the showing
  ; one).
  ldx #1
find_request_loop:
  lda nkireq,x
  cmp nkicur,x
  bne found_request
  dex
  bpl find_request_loop
  rts
found_request:

  ; Has the NKI corresponding to this request been chosen yet?
  ; If so, choose one and leave the request pending.
  tay
  bpl not_null  ; 80-ff: erase
  sta nkicur,x
  lday #zerobyte
  jmp display_bpe_ay
not_null:

  bne not_kitten  ; 0: kitten
  sta nkicur,x  ; ack request
  lday nkilru_buf
display_bpe_ay:
  stay 0
  jmp display_bpe
not_kitten:

  cmp #NUM_ITEMS  ; > NUM_ITEMS: robot
  bcc not_robot
  sta nkicur,x  ; ack request
  lday nkilru_buf+2
  bcs display_bpe_ay
not_robot:

  lda item_typehi,y  ; 0 < y < NUM_ITEMS: NKI
  bpl not_known_nki
  sty nkicur,x  ; ack request
  sta 1
  lda item_typelo,y
  sta 0
  jmp display_bpe
not_known_nki:  ; Unidentified NKI #Y
  sty 8
  jsr nkilru_get
  ldx 8
  sta item_typehi,x
  sty item_typelo,x
  ; Do not acknowledge request because it'll get filled next frame
  rts
.endproc

;;
; Starts displaying an ASCII or DTE string on a status window.
; @param $00 address of text
; @param X status side to display on (0: left, 1: right)
.proc display_bpe
  lda startaddr,x
  sta nkidst
  lda #0
  sta nkisrc
  jsr bpe_decode0
  jmp word_wrap
.pushseg
.segment "RODATA"
startaddr: .byte $48, $4C
.popseg
.endproc

.proc nkidisp_copy
  ; 00-1F: write tile data there
  ; 20-7F: increment address but do nothing else
  ; 80-FF: don't increment address
  lda nkidst
  bmi nothing
  inc nkidst
  cmp #$20
  bcc has_data_to_copy
nothing:
  rts
has_data_to_copy:
  ldy #$08
  jmp copyLineImg
.endproc
  

; WORD WRAPPING ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

WRAP_WIDTH = 112

.segment "CODE"
;;
; Finds the most text that will fit in 112 pixels.
.proc word_wrap
total_pixels = 0  ; pen position
last_space_offset = 1  ; '\n' will be inserted at this offset
last_space_pixels = 2  ; total_pixels after inserting last space

  ldy #0
  sty total_pixels
  sty last_space_offset
  sty last_space_pixels
charloop:
  lda bpebuf,y
  beq done
  sec
  sbc #' '
  clc
  beq isspace
  tax
  lda vwfChrWidths,x
  adc total_pixels
  sta total_pixels
  cmp #WRAP_WIDTH
  bcc nextchar
  sec 
  sbc last_space_pixels
  sta total_pixels
  ldx last_space_offset
  lda #LF
  sta bpebuf,x
nextchar:
  iny
  cpy #BPEBUFLEN
  bcc charloop
done:
  rts
isspace:
  lda vwfChrWidths
  adc total_pixels
  sta total_pixels
  sta last_space_pixels
  sty last_space_offset
  jmp nextchar
.endproc

