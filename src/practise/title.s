.include "common.inc"

; # Main menu screen code
;
; This contains all the code used for the practise rom.
;
; It is included from the "boot" files.
;

.p02
.linecont +
.include "ascii.s"

; import some pointers from the smb rom
.import GL_ENTER
.import GetAreaDataAddrs
.import LoadAreaPointer
.import PlayerEndWorld
.import NonMaskableInterrupt

; Temporary WRAM space
.segment "SRAM"
WRAMSaveHeader: .byte $00, $00, $00, $00, $00
HeldButtons: .byte $00
ReleasedButtons: .byte $00
LastReadButtons: .byte $00
PressedButtons: .byte $00
CachedChangeAreaTimer: .byte $00
LevelEnding: .byte $00
IsPlaying: .byte $00
EnteringFromMenu: .byte $00
PendingScoreDrawPosition: .byte $00
CachedITC: .byte $00
PREVIOUS_BANK: .byte $00

MathDigits:
MathFrameruleDigitStart:
  .byte $00, $00, $00, $00, $00 ; selected framerule
MathFrameruleDigitEnd:
MathInGameFrameruleDigitStart:
  .byte $00, $00, $00, $00, $00 ; ingame framerule
MathInGameFrameruleDigitEnd:

; $7E00-$7FFF - relocated bank switching code
RelocatedCodeLocation = $7E00

WorldCount: .byte 8
LevelCount: .byte 4

.segment "PRACTISE"
.import GL_ENTER

.export TitleNMI
BGDATA:
.incbin "menu.bin"

; attributes
.byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
.byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
.byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
.byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
.byte $FF, $FF, $FF, $FF, $FF, $00, $00, $00
.byte $00, $00, $00, $00, $00, $00, $00, $00
.byte $00, $00, $00, $05, $05, $05, $00, $00
.byte $00, $00, $00, $00, $00, $00, $00, $00

MenuPalette:
.byte $0F, $30, $10, $00
.byte $0F, $11, $01, $02
.byte $0F, $30, $10, $00
.byte $0F, $30, $2D, $30

.byte $0F, $30, $11, $01
.byte $0F, $11, $11, $11
.byte $0F, $0F, $10, $0F
.byte $0F, $0F, $10, $0F
MenuPaletteEnd:

; ================================================================
;  Full reset of title screen
; ----------------------------------------------------------------
TitleResetInner:
    ldx #$00                           ; disable ppu
    stx PPUCTRL                  ;
    stx PPUMASK                  ;
    jsr InitializeMemory               ; clear memory
    jsr ForceClearWRAM                 ; clear all wram state
    lda #8                             ; set starting framerule
    sta MathFrameruleDigitStart        ;
:   lda PPUSTATUS                     ; wait for vblank
    bpl :-                             ;
HotReset2:                             ;
    ldx #$00                           ; disable ppu again (this is called when resetting to the menu)
    stx PPUCTRL                  ;
    stx PPUMASK                  ;
    ldx #$FF                           ; clear stack
    txs                                ;
:   lda PPUSTATUS                     ; wait for vblank
    bpl :-                             ;
    jsr ReadJoypads                    ; read controller to prevent a held button at startup from registering
    jsr PrepareScreen                  ; load in palette and background
    jsr MenuReset                      ; reset main menu
    lda #0                             ; clear scroll registers
    sta PPUSCROLL                 ;
    sta PPUSCROLL                 ;
    lda #%10011000                     ; enable ppu
    sta Mirror_PPUCTRL           ;
    sta PPUCTRL                  ;
:   jmp :-                             ; infinite loop until NMI
; ================================================================

; ================================================================
;  Hot reset back to the title screen
; ----------------------------------------------------------------
HotReset:
    lda #0                             ; kill any playing sounds
    sta SND_MASTERCTRL_REG             ;
    jsr InitializeMemory               ; clear memory
    jmp HotReset2                      ; then jump to the shared reset code
; ================================================================

; ================================================================
;  Handle NMI interrupts while in the title screen
; ----------------------------------------------------------------
TitleNMI:
    lda Mirror_PPUCTRL           ; disable nmi
    and #%01111111                     ;
    sta Mirror_PPUCTRL           ; and update ppu state
    sta PPUCTRL                  ;
    bit PPUSTATUS                     ; flip ppu status
    jsr WriteVRAMBufferToScreen        ; write any pending vram updates
    lda #0                             ; disable playing state
    sta IsPlaying                      ;
    sta PPUSCROLL                 ; clear scroll registers
    sta PPUSCROLL                 ;
    lda #$02                           ; copy sprites
    sta $4014                        ;
    jsr ReadJoypads                    ; read controller state
    jsr MenuNMI                        ; and run menu code
    lda #%00011010                     ; set ppu mask state for menu
    sta PPUMASK                  ;
    lda Mirror_PPUCTRL           ; get ppu mirror state
    ora #%10000000                     ; and reactivate nmi
    sta Mirror_PPUCTRL           ; update ppu state
    sta PPUCTRL                  ;
    rti                                ; and we are done for the frame

; ================================================================
;  Sets up the all the fixed graphics for the title screen
; ----------------------------------------------------------------
PrepareScreen:
    lda #$3F                           ; move ppu to palette memory
    sta PPUADDR                    ;
    lda #$00                           ;
    sta PPUADDR                    ;
    ldx #0                             ;
:   lda MenuPalette,x                  ; and copy the menu palette
    sta PPUDATA                       ;
    inx                                ;
    cpx #(MenuPaletteEnd-MenuPalette)  ;
    bne :-                             ;
    lda #$20                           ; move ppu to nametable 0
    sta PPUADDR                    ;
    ldx #0                             ;
    stx PPUADDR                    ;
:   lda BGDATA+$000,x                  ; and copy every page of menu data
    sta PPUDATA                       ;
    inx                                ;
    bne :-                             ;
:   lda BGDATA+$100,x                  ;
    sta PPUDATA                       ;
    inx                                ;
    bne :-                             ;
:   lda BGDATA+$200,x                  ;
    sta PPUDATA                       ;
    inx                                ;
    bne :-                             ;
:   lda BGDATA+$300,x                  ;
    sta PPUDATA                       ;
    inx                                ;
    bne :-                             ;
    rts                                ;
; ================================================================

; ================================================================
;  Clear RAM and temporary WRAM
; ----------------------------------------------------------------
InitializeMemory:
    lda #0                             ; clear A and X
    ldx #0                             ;
:   sta $0000,x                        ; clear relevant memory addresses
    sta $0200,x                        ;
    sta $0300,x                        ;
    sta $0400,x                        ;
    sta $0500,x                        ;
    sta $0600,x                        ;
    sta $0700,x                        ;
    sta $6000,x                        ;
    inx                                ; and loop for 256 bytes
    bne :-                             ;
    rts                                ;
; ================================================================

; ================================================================
;  Reinitialize WRAM if needed
; ----------------------------------------------------------------
InitializeWRAM:
    ldx #ROMSaveHeaderLen              ; get length of the magic wram header
:   lda ROMSaveHeader,x                ; check every byte of the header
    cmp WRAMSaveHeader,x               ; does it match?
    bne ForceClearWRAM                 ; no - clear wram
    dex                                ; yes - check next byte
    bpl :-                             ;
    rts                                ;
; ================================================================

; ================================================================
;  Clear WRAM state
; ----------------------------------------------------------------
ForceClearWRAM:
    @Ptr = $0
    lda #$60                           ; set starting address to $6000
    sta @Ptr+1                         ;
    ldy #0                             ;
    sty @Ptr+0                         ;
    ldx #$80                           ; and mark ending address at $8000
    lda #$00                           ; clear A
:   sta (@Ptr),y                       ; clear one byte of WRAM
    iny                                ; and advance
    bne :-                             ; for 256 bytes
    inc @Ptr+1                         ; then advance to the next page
    cpx @Ptr+1                         ; check if we are at the ending page
    bne :-                             ; no - keep clearing data
    ldx #ROMSaveHeaderLen              ; otherwise copy the magic wram header
:   lda ROMSaveHeader,x                ;
    sta WRAMSaveHeader,x               ;
    dex                                ;
    bpl :-                             ;
    rts                                ;
; ================================================================


; ===========================================================================
;  Attempt to find the level selected on th emenu screen
; ---------------------------------------------------------------------------
BANK_AdvanceToLevel:
    @AreaNumber = $0
    ldx #0                              ;
    stx @AreaNumber                     ; clear temp area number
    stx AreaNumber                      ; clear area number
    ldx LevelNumber                     ; get how many levels to advance
    beq @LevelFound                     ; if we're on the first level, we're done
@NextArea:                              ;
    inc AreaNumber                      ; advance area pointer
    lda PlayerEntranceCtrl              ; get what kind of entry this level has
    and #%00000100                      ; check if it's a controllable area
    beq @AreaOK                         ; yes - advance to next level
    inc @AreaNumber                     ; yes - increment temp area number
    bvc @NextArea                       ; and check next area
@AreaOK:                                ;
    dex                                 ; decrement number of levels we need to advance
    bne @NextArea                       ; and keep running if we haven't reached our level
@LevelFound:                            ;
    clc                                 ;
    lda LevelNumber                     ; get level we are starting on
    adc @AreaNumber                     ; and add how many areas we needed to skip
    sta AreaNumber                      ; and store that as the area number
    lda #0                              ; clear sound
    sta SND_DELTA_REG+1                 ;
    jsr LoadAreaPointer                 ; reload pointers for this area
    jsr GetAreaDataAddrs                ;
    lda #$a5                            ;
    jmp GL_ENTER                        ; then start the game
; ===========================================================================
; ================================================================

; include all of the relevant title files
.include "practise.s"
.include "menu.s"
.include "utils.s"
.include "rng.s"
.include "../memory.s"

; magic save header for WRAM
ROMSaveHeader:
.byte $03, $20, $07, $21, $03
ROMSaveHeaderEnd:
ROMSaveHeaderLen = ROMSaveHeaderEnd-ROMSaveHeader
