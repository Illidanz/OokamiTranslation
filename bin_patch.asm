.nds

;Detect what game the patch is being applied to
.if readascii("data/repack/header.bin", 0xc, 0x6) == "YU5J2J"
  FIRST_GAME   equ 0x1
  SECOND_GAME  equ 0x0
  ARM_FILE     equ "data/repack/arm9.bin"
  SUB_PATH     equ "/data/opsub.dat"
  ;Position in the ARM9 file for the custom code
  ARM_POS      equ 0x020997ac
  ARM_AREA     equ 0x7bf
  ;Position in RAM for the digit8 file used for injection
  INJECT_START equ 0x02121e60
  ;Position in RAM for the end of the file
  INJECT_END   equ 0x02121f70
  ;Different position with Heap Shrink enabled (default) on nds-bootstrap
  INJECT_END2  equ 0x02123774
  ;Free portion of RAM to load the opening sub graphics
  SUB_RAM      equ 0x020a9000
  SUB_OP_SIZE  equ 0x9A00
  ;Bottom screen BG VRAM + 1 tile of space (0x800)
  SUB_VRAM     equ 0x06204800
  ;Position for the Special Message subs
  SUB_VRAM2    equ 0x06214800
  ;Function to load a file in RAM
  RAM_FUNC     equ 0x0205464c
.else
  FIRST_GAME   equ 0x0
  SECOND_GAME  equ 0x1
  ARM_FILE     equ "data/repack/arm9_dec.bin"
  SUB_PATH     equ "data/opsub.dat"
  SPECIAL_PATH equ "data/special1.dat"
  ED_PATH      equ "ev_main/main_sub_staffroll"
  ARM_POS      equ 0x020c8178
  ARM_AREA     equ 0x491
  INJECT_START equ 0x02196320
  INJECT_END   equ 0x02196430
  INJECT_PTR   equ 0x020dec4c
  SUB_RAM      equ 0x023a7140
  SUB_VRAM     equ 0x06214800
  RAM_FUNC     equ 0x0204c144
.endif

;Plug the redirects code at the end of the digit8 font
.open "data/repack/data/font/digit8.NFTR",INJECT_START
  .org INJECT_END
  .include "data/redirects.asm"
  .align
.close

.open ARM_FILE,0x02000000
.org ARM_POS
.area ARM_AREA
  ;Copy the relevant info from the font file
  FONT_DATA:
  .import "data/font_data.bin",0,0x5f
  .align
  .if SECOND_GAME
    CURRENT_VWF:
    .dw 0x0
  .endif

  ;Add WVF support to script dialogs
  VWF:
  push {lr}
  .if FIRST_GAME
    ;Read the current character and set r0 to the VWF value
    ldrb r1,[r6,0xe5]
    ldr r2,=FONT_DATA
    sub r1,r1,0x20
    add r1,r1,r2
    ldrb r1,[r1]
    add r0,r0,r1
  .else
    ;r4 = character
    ;r3 = position in the string
    ;r12 = return x position
    push {r0-r1}
    ;For sjis, we just add a fixed width
    cmp r4,0x80
    movge r1,0xc
    bge @@skipascii
    ;Add the character width
    ldr r0,=FONT_DATA
    add r0,r0,r4
    sub r0,r0,0x20
    ldrb r1,[r0]
    @@skipascii:
    ;Load the current x position from RAM
    ldr r0,=CURRENT_VWF
    ldr r12,[r0]
    ;Reset it if this is the first character of the line
    cmp r3,0x0
    moveq r12,0x0
    ;Save the new value in RAM
    add r12,r12,r1
    str r12,[r0]
    ;Return the value minus the current character
    sub r12,r1
    ;Return
    pop {r0-r1}
  .endif
  pop {pc}
  .pool

  .if FIRST_GAME
    ;Center the choices text. This is originally calculated by
    ;multiplying the max line length by a constant
    CENTERING:
    push {lr}
    ;r1 = Result
    ;r9 = Pointer to the string
    push {r0,r2,r3,r9}
    ldr r0,=FONT_DATA
    mov r1,0x0
    mov r3,0x0
    ;Loop the choice characters
    @@loop:
    ;Read the character
    ldrb r2,[r9],0x1
    ;Finish when reaching 0
    cmp r2,0x0
    beq @@end
    ;Handle newlines
    cmp r2,0x0a
    cmpne r2,0x0d
    beq @@newline
    ;Handle shift-jis
    ;>=0xe0
    cmp r2,0xe0
    addge r3,r3,0xc
    addge r9,r9,0x1
    bge @@loop
    ;>0xa0
    cmp r2,0xa0
    addgt r3,r3,0x6
    bgt @@loop
    ;>=0x81
    cmp r2,0x81
    addge r3,r3,0xc
    addge r9,r9,0x1
    bge @@loop
    ;Add the character width
    sub r2,r2,0x20
    add r2,r0,r2
    ldrb r2,[r2]
    add r3,r3,r2
    b @@loop
    @@newline:
    cmp r3,r1
    movgt r1,r3
    mov r3,0x0
    b @@loop
    @@end:
    ;Get the max value
    cmp r3,r1
    movgt r1,r3
    ;Divide by 2
    lsr r1,r1,0x1
    pop {r0,r2,r3,r9}
    pop {pc}
    .pool
  .endif

  .if FIRST_GAME
    ;Center the speaker name.
    ;This function originally just counts the character (/2 for ASCII)
    CENTERING_NAME:
    push {lr}
    ;r0 = Result and pointer to the string
    push {r1,r2,r3}
    ldr r1,=FONT_DATA
    mov r3,r0
    mov r0,0x0
    ;Loop the name characters
    @@loop:
    ;Read the character
    ldrb r2,[r3],0x1
    ;Finish when reaching 0
    cmp r2,0x0
    beq @@end
    ;Handle shift-jis
    ;>=0xe0
    cmp r2,0xe0
    addge r0,r0,0xc
    addge r3,r3,0x1
    bge @@loop
    ;>0xa0
    cmp r2,0xa0
    addgt r0,r0,0x6
    bgt @@loop
    ;>=0x81
    cmp r2,0x81
    addge r0,r0,0xc
    addge r3,r3,0x1
    bge @@loop
    ;Add the character width
    sub r2,r2,0x20
    add r2,r1,r2
    ldrb r2,[r2]
    add r0,r0,r2
    b @@loop
    @@end:
    ;Divide by 6: ((x * 0xaaab) >> 0x10) >> 0x2
    ldr r1,=0xaaab
    mul r0,r0,r1
    lsr r0,r0,0x10
    lsr r0,r0,0x2
    pop {r1,r2,r3}
    pop {pc}
    .pool
  .endif

  ;File containing the the opening sub graphics
  SUB_FILE:
  .asciiz SUB_PATH
  .if SECOND_GAME
    SPECIAL_FILE:
    .asciiz SPECIAL_PATH
  .endif
  .align
  ;Current frame for audio subtitles
  AUDIO_FRAME:
  .dh 0x0
  .align

  ;Load the subtitles file in ram
  SUBTITLE:
  push {lr,r0-r4}
  ;Load the file
  .if FIRST_GAME
    ;This functions loads the file r1 into r0+0xc, but only up
    ;to 0xa78 bytes, so we temporarily modify that max size
    SUB_SIZE equ 0x02054690
    ldr r0,=SUB_SIZE
    ldr r1,=0xfffff
    str r1,[r0]
    ;Load the file
    ldr r0,=SUB_RAM
    sub r0,r0,0xc
    ldr r1,=SUB_FILE
    bl RAM_FUNC
    ;Restore the size pointer
    ldr r0,=SUB_SIZE
    ldr r1,=0xa78
    str r1,[r0]
    ;Check if we need to enable the BG
    ldr r0,=AUDIO_FRAME
    ldrh r0,[r0]
    cmp r0,0x0
    beq @@ret
  .else
    ;Check what file we need to load
    ldr r0,=AUDIO_FRAME
    ldrh r0,[r0]
    cmp r0,0x0
    ldreq r1,=SUB_FILE
    beq @@loadfile
    ldr r1,=SPECIAL_FILE
    add r0,r0,0x30
    strb r0,[r1,0xc]
    @@loadfile:
    ;Load the file
    ldr r0,=SUB_RAM
    bl RAM_FUNC
  .endif
  ;Enable BG1 (2nd bit)
  ldr r0,=0x4001001
  ldrb r1,[r0]
  orr r1,r1,0x2
  strb r1,[r0]
  ;Set BG1 values (High priority, 8bit, tiles=5, map=2)
  add r0,r0,0x9
  mov r1,0x0294
  strh r1,[r0]
  ;Reset BG1 scrolling, needed if the video plays again
  ;after being idle in the main menu
  add r0,r0,0xc
  mov r1,0x0
  strh r1,[r0]
  ;Set the map
  ldr r0,=0x6201000
  mov r1,0x0
  @@mapLoop:
  strh r1,[r0],0x2
  add r1,0x1
  cmp r1,0x60
  bne @@mapLoop
  ;Set VRAM H to LCD
  ldr r0,=0x04000248
  mov r1,0x80
  strb r1,[r0]
  .if FIRST_GAME
    ldr r0,=0x0689a002
    ldr r1,=0x63df
    strh r1,[r0]
  .else
    ;Copy the palette
    ldr r0,=0x06898004
    ldr r1,=0x0689a004
    mov r2,0xa
    @@palLoop:
    ldr r4,[r0],0x4
    str r4,[r1],0x4
    sub r2,r2,0x1
    cmp r2,0x0
    bne @@palLoop
  .endif
  ;Set VRAM H back to ext palette
  ldr r0,=0x04000248
  mov r1,0x82
  strb r1,[r0]
  ;Go back to normal execution
  @@ret:
  pop {r0-r4}
  .if FIRST_GAME
    add r0,r6,0x1000
  .else
    mov r4,r0
  .endif
  pop {pc}
  .pool

  ;Draw or clear the subtitles at the current frame
  SUBTITLE_FRAME:
  push {lr,r0-r3}
  ;Check if we need to do something in the current frame (r1)
  ldr r0,=SUB_RAM
  .if FIRST_GAME
    ldr r2,=AUDIO_FRAME
    ldrh r2,[r2]
    cmp r2,0x0
    addne r0,r0,SUB_OP_SIZE
  .endif
  ldr r2,[r0]
  ldr r3,[r0,r2]
  cmp r3,0x0
  beq @@end
  cmp r1,r3
  blt @@end
  ;Push the rest of the registers and get current offset/clear
  push {r4-r11}
  add r2,r2,0x4
  ldr r3,[r0,r2]
  ;Increase the sub counter
  add r2,r2,0x4
  str r2,[r0]
  ;Setup registers
  .if FIRST_GAME
    ldr r1,=AUDIO_FRAME
    ldrh r1,[r1]
    cmp r1,0x0
    ldreq r1,=SUB_VRAM
    ldrne r1,=SUB_VRAM2
  .else
    ldr r1,=SUB_VRAM
  .endif
  add r0,r0,r3
  ;Check the compression series
  ;If r3 1, this is a repeating series with one single tile repeated r2 times
  ;Otherwise, there are r2 different tiles
  @@series:
  ldrh r3,[r0],0x2
  ldrh r2,[r0],0x2
  cmp r2,0x0
  beq @@seriesEnd
  ;Multiply by 2 since 8 words are copied at a time and a tile is 16 words
  lsl r3,r3,0x1
  lsl r2,r2,0x1
  ;Copy 8 words at a time
  @@loop:
  ldmia r0!,{r4-r11}
  stmia r1!,{r4-r11}
  sub r2,r2,0x1
  cmp r2,0x0
  beq @@series
  ;Go back to the loop if this isn't a repating series
  cmp r3,0x0
  beq @@loop
  ;Otherwise, check if it needs to go back one tile in RAM and write it again
  sub r3,r3,0x1
  cmp r3,0x0
  moveq r3,0x2
  subeq r0,r0,0x40
  b @@loop
  ;Pop the registers
  @@seriesEnd:
  pop {r4-r11}
  ;Go back to normal execution
  @@end:
  pop {r0-r3}
  .if FIRST_GAME
    ldr r0,[r10,0x8]
  .else
    add r1,r1,0x1
  .endif
  pop {pc}
  .pool

  GOSSIP:
  beq GOSSIP_ZERO
  cmp r0,0x1f
  bne GOSSIP_LOOP
  push {r2}
  .if FIRST_GAME
    ;Check that REDIRECT_START contains "NDSC" before it
    ldr r0,=REDIRECT_START
    ldr r0,[r0,-0x4]
    ldr r2,=0x4353444e ;"CSDN"
    cmp r0,r2
    ldreq r2,=REDIRECT_START
    ldrne r2,=INJECT_END2
  .else
    ldr r2,=INJECT_PTR
    ldr r2,[r2]
    add r2,r2,4 + INJECT_END - INJECT_START
  .endif
  ;Set r1 to REDIRECT_START + redirectn*2
  ldrb r0,[r1,0x0]
  lsl r0,r0,0x1
  mov r1,r2
  ;ldr r1,[r1]
  add r1,r1,r0
  ;Set r1 to the redirected string
  ldrh r0,[r1]
  mov r1,r2
  add r1,r1,r0
  ;Set r0 to the next character and increase r1 by 1
  ldrb r0,[r1,0x0]
  add r1,r1,0x1
  pop {r2}
  ;Write it to [r13+0xc]
  str r1,[r13,0xc]
  ;Go back to normal execution
  b GOSSIP_LOOP
  .pool

  .if SECOND_GAME
  GOSSIP_FIRST:
  beq GOSSIP_FIRST_ZERO
  ldrsb r7,[sp,0x40]
  cmp r0,0x1f
  bne GOSSIP_LOOP
  cmp r0,0x0
  b GOSSIP
  .endif

  ;Add subtitles for the special message
  SPECIAL_NAME:
  .if FIRST_GAME
    .asciiz "HOR_SYS_420.ahx"
  .else
    .db 0x0
    .asciiz "EVE_SYS_460"
    .asciiz "HOR_SYS_490"
    .asciiz "JUN_SYS_010_freetalk"
    .asciiz "LKA_SYS_480"
    .asciiz "NRA_SYS_460"
    ED_NAME:
    .asciiz ED_PATH
    .align
    SPECIAL_STARTING:
    .dw 0
  .endif
  .align

  SPECIAL:
  .if FIRST_GAME
    push {lr,r0-r2,r4}
    ;Compare r3 with HOR_SYS_420.ahx
    ldr r0,=SPECIAL_NAME
    mov r1,0x0
    @@loop:
    ldrb r2,[r0,r1]
    ldrb r4,[r3,r1]
    cmp r2,r4
    bne @@end
    cmp r2,0x0
    beq @@found
    add r1,r1,0x1
    b @@loop
    ;Matched, load the subtitle file in ram
    @@found:
    ldr r0,=AUDIO_FRAME
    mov r1,0x1
    strh r1,[r0]
    bl SUBTITLE
    ;Restore the stack and jump to the original function call
    @@end:
    pop {lr,r0-r2,r4}
    b 0x2069774
  .else
    push {lr,r0-r5}
    mov r3,r2
    ldr r0,=SPECIAL_NAME
    mov r5,0x0
    ;Increase r5 and read r0 until 0 to get to the next name
    @@nextone:
    mov r1,0x0
    add r5,r5,0x1
    cmp r5,0x5
    bgt @@end
    @@loopzero:
    ldrb r2,[r0]
    add r0,r0,0x1
    cmp r2,0x0
    bne @@loopzero
    @@loop:
    ldrb r2,[r0,r1]
    ldrb r4,[r3,r1]
    cmp r2,r4
    bne @@nextone
    cmp r2,0x0
    beq @@found
    add r1,r1,0x1
    b @@loop
    @@found:
    ldr r0,=AUDIO_FRAME
    strh r5,[r0]
    ldr r0,=SPECIAL_STARTING
    mov r1,0x1
    str r1,[r0]
    bl SUBTITLE
    @@end:
    pop {lr,r0-r5}
    b 0x02012a64
  .endif
  .pool

  SPECIAL_FRAME:
  push {lr,r0-r1}
  .if SECOND_GAME
    ldr r0,=SPECIAL_STARTING
    mov r1,0x0
    str r1,[r0]
  .endif
  ;Check if the special message is playing
  ldr r0,=AUDIO_FRAME
  ldrh r1,[r0]
  cmp r1,0x0
  beq @@ret
  ;Increase the frame and call the frame function
  add r1,r1,0x1
  strh r1,[r0]
  bl SUBTITLE_FRAME
  @@ret:
  pop {lr,r0-r1}
  .if FIRST_GAME
    b 0x0205818c
  .else
    b 0x0205f45c
  .endif
  .pool

  SPECIAL_STOP:
  push {r0-r1}
  ;Check if the special message is playing
  .if SECOND_GAME
    ldr r0,=SPECIAL_STARTING
    ldr r1,[r0]
    cmp r1,0x1
    beq @@ret
  .endif
  ldr r0,=AUDIO_FRAME
  ldrh r1,[r0]
  cmp r1,0x0
  beq @@ret
  ;Set audio frame to 0
  mov r1,0x0
  strh r1,[r0]
  ;Disable BG1 (2nd bit)
  ldr r0,=0x4001001
  ldrb r1,[r0]
  and r1,r1,0xfd
  strb r1,[r0]
  @@ret:
  pop {r0-r1}
  .if FIRST_GAME
    b 0x020664d4
  .else
    b 0x0206daf8
  .endif
  .pool

  .if SECOND_GAME
  SPECIAL_CONTROL:
    push {lr,r2}
    ldr r2,=AUDIO_FRAME
    ldrh r2,[r2]
    cmp r2,0x0
    streq r0,[r1]
    pop {pc,r2}
    .pool

  STRLEN:
    push {r2-r3}
    mov r1,0x0
    mov r2,0x0
    ldr r3,=FONT_DATA
    @@loop:
    ldrsb r1,[r0]
    cmp r1,0x0
    beq @@ret
    add r0,r0,0x1
    add r1,r3,r1
    sub r1,r1,0x20
    ldrb r1,[r1]
    add r2,r2,r1
    b @@loop
    @@ret:
    mov r0,r2
    pop {r2-r3}
    bx lr
    .pool
  .endif
.endarea

.if SECOND_GAME
.org 0x020c8648
  .area 0x130
  ED_PLAYING:
  .dw 0

  ED:
  mov r2,r0
  push {lr,r0-r4}
  ldr r1,=ED_NAME
  ;Compare r0 with r1
  @@loop:
  ldrb r2,[r0],0x1
  ldrb r3,[r1],0x1
  cmp r2,r3
  bne @@end
  cmp r2,0x0
  bne @@loop
  @@found:
  ldr r0,=ED_PLAYING
  mov r1,0x1
  str r1,[r0]
  @@end:
  pop {pc,r0-r4}

  ED_FRAME:
  mov r0,0x0
  push {lr,r0-r2}
  ;Wait 0x40 frames before calling SUBTITLE
  ldr r0,=ED_PLAYING
  ldr r1,[r0]
  cmp r1,0x0
  beq @@ret
  cmp r1,0x40
  add r1,r1,0x1
  str r1,[r0]
  blt @@ret
  bgt @@callframe
  ldr r0,=AUDIO_FRAME
  mov r1,0x6
  strh r1,[r0]
  bl SUBTITLE
  ldr r0,=AUDIO_FRAME
  mov r1,0x40
  ldrh r1,[r0]
  @@callframe:
  ;Increase the frame and call the frame function
  ldr r0,=AUDIO_FRAME
  ldrh r1,[r0]
  add r1,r1,0x1
  strh r1,[r0]
  bl SUBTITLE_FRAME
  ;Check if it finished playing
  ldr r0,=SUB_RAM
  ldr r1,[r0]
  ldr r2,[r0,r1]
  ldr r0,=ED_PLAYING
  mov r1,0x0
  cmp r2,0x0
  streq r1,[r0]
  ldr r0,=AUDIO_FRAME
  streq r1,[r0]
  @@ret:
  pop {pc,r0-r2}
  .pool

  FIX_CONTRACT_BUG:
  mov r6,r4
  push {lr,r0-r6}
  ldr r0,[r7,0x8]
  add r0,r0,r6
  bl 0x0208fbe4
  cmp r0,0x0
  beq @@ret
  ;If the tutorial contract is in progress, we check if there are more
  add r5,r5,0x1
  add r6,r6,0xc4
  @@loop:
  ldr r0,[r7,0x8]
  add r0,r0,r6
  bl 0x0208fbe4
  cmp r0,0x0
  bne @@retfix
  ldr r0,[r7,0x4]
  add r5,r5,0x1
  cmp r5,r0
  add r6,r6,0xc4
  blt @@loop
  @@ret:
  pop {pc,r0-r6}
  @@retfix:
  pop {r0-r6}
  add r5,r5,0x1
  add r6,r6,0xc4
  pop {pc}
  .endarea
.endif
.close

;Inject custom code
.open ARM_FILE,0x02000000
  .if FIRST_GAME
    .org 0x0203a8ec
      ;add r0,r0,0x6
      bl VWF
    .org 0x02030304
      ;add r1,r6,r6,lsl 0x1
      bl CENTERING
    .org 0x0203a6e4
      ;bl 0x0200cffc
      bl CENTERING_NAME
    .org 0x020216d0
      ;add r0,r6,0x1000
      bl SUBTITLE
    .org 0x0206ba2c
      ;ldr r0,[r10,0x8]
      bl SUBTITLE_FRAME
    .org 0x02055b64
      ;bl 0x2069774
      bl SPECIAL
    .org 0x020582b0
      ;bl 0x0205818c
      bl SPECIAL_FRAME
    .org 0x02069698
      ;bl 0x020664d4
      bl SPECIAL_STOP
    .org 0x0207b9bc
      b GOSSIP
      GOSSIP_ZERO:
    .org 0x0207b97c
      GOSSIP_LOOP:

    ;Increase space for the market header
    .org 0x0204500c
      ;mov r3,0x19
      mov r3,0x20
    .org 0x020450dc
      ;mov r3,0x19
      mov r3,0x20

    ;Tweak rumor text position
    .org 0x0206cca4
      ;mov r2,r1 (0x8)
      mov r2,0x6
    .org 0x0206cd6c
      ;mov r2,0x1c
      mov r2,0x16
    .org 0x0206ce94
      ;mov r2,0x70
      mov r2,0x72
  .else
    .org 0x02030ef0
      ;mul r12,r3,r1
      bl VWF
    .org 0x0209d1c4
      ;mov r4,r0
      bl SUBTITLE
    .org 0x0209f1e0
      ;add r1,r1,0x1
      bl SUBTITLE_FRAME
    .org 0x02045080
      ;bl 0x02012a64
      bl SPECIAL
    .org 0x0205f580
      ;bl 0x0205f45c
      bl SPECIAL_FRAME
    .org 0x0205ccc0
      ;bl 0x0206daf8
      bl SPECIAL_STOP
    .org 0x02031954
      ;str r0,[r1]
      bl SPECIAL_CONTROL
    .org 0x0204274c
      bl ED
    .org 0x0205f564
      bl ED_FRAME
    .org 0x02027694
      b GOSSIP
      GOSSIP_ZERO:
    .org 0x0202764c
      b GOSSIP_FIRST
    .org 0x02027698
      GOSSIP_FIRST_ZERO:
    .org 0x02027654
      GOSSIP_LOOP:

    ;Fix contract bug
    .org 0x0209001c
      ;mov r6,r4
      bl FIX_CONTRACT_BUG

    ;Tweak payment deadline text position
    .org 0x020b3d44
      ;.dw 0xe8
      .dw 0xb1

    ;Tweak "To Repay" text position
    .org 0x020565ac
      ;mov r0,0xbe000
      mov r0,0xbe000

    ;Tweak Agreement Destination text position
    .org 0x020b3d14
      ;.dw 0xf4
      .dw 0xdf

    ;Tweak contract OAM size
    ;Increase the size
    .org 0x0205583c
      ;mov r1,0x4
      mov r1,0x6
    ;Move the text right
    .org 0x02056368
      ;mov r0,0x14000
      mov r0,0x1c000
    ;Move the next 2 tiles position
    .org 0x02055864
      ;mov r0,0xe2
      mov r0,0xe4
    .org 0x020558a8
      ;mov r0,0xe6
      mov r0,0xe8
    ;These other values are not hardcoded in the function calls
    .org 0x020b2260
      .dw 0xee  ;0xec
      .dw 0xf0  ;0xee
      .dw 0xf2  ;0xf0
      .dw 0xf4  ;0xf2
    ;Move these other values too
    .org 0x020568e0
      ;add r2,r2,0x7100
      add r2,r2,0x7200
    .org 0x02056918
      ;add r2,r2,0x7300
      add r2,r2,0x7400
    .org 0x02056950
      ;add r2,r2,0x7600
      add r2,r2,0x7700
    .org 0x02056988
      ;add r2,r2,0x7700
      add r2,r2,0x7800
    .org 0x020569c0
      ;add r2,r2,0x7800
      add r2,r2,0x7900
    .org 0x020569f8
      ;add r2,r2,0x7900
      add r2,r2,0x7a00

    ;Tweak rumor text position
    .org 0x02081d88
      ;mov r2,r1 (0x8)
      mov r2,0x6
    .org 0x02081e50
      ;mov r2,0x1c
      mov r2,0x16
    .org 0x02081f78
      ;mov r2,0x70
      mov r2,0x72

    ;Tweak strlen function for centering text
    .org 0x0208e420
      bl STRLEN
    .org 0x0208e4b4
      lsr r2,r0,0x1
      .skip 8
      rsb r1,r2,0x53

    ;Tweak contract days left (%d日) alignment
    .org 0x0203a2e8
      ;mov r5,r0
      sub r5,r0,0x1

    ;Tweak sprintf function to use "_" instead of " " for padding short numbers for more consistent align
    .org 0x0200fcec
      ;mov r1,0x20
      mov r1,0x5f

    ;Tweak Goods Knowledge increased message
    ;Don't care about making more room in the stack since we're not using the text that would be at sp+0x4
    .org 0x0203ab7c
    .area 0x2c,0x0
      str r4,[sp,0x4]
      add r0,r6,r5,lsl 0x2
      add r0,r0,0x8000
      ldr r0,[r0,0xa24]
      str r0,[sp,0x0]
      add r0,sp,0x54
      mov r1,0x4f
      bl 0x0200f534
      ldr r4,[sp,0x4]
    .endarea
    .org 0x0203abcc
      nop

    ;Tweak starting position for dialog text
    .org 0x02030f0c
      ;add r2,r12,0xa
      add r2,r12,0x4
  .endif
.close
