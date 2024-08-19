
.include "common.inc"
.include "object.inc"


.segment "OBJECT"

;--------------------------------

InitGoomba:
      lda #$00
      sta Enemy_State,x
      jsr InitNormalEnemy  ;set appropriate horizontal speed
      jmp SmallBBox        ;set $09 as bounding box control, set other values
