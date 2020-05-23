// Raspberry Pi 3 'Bare Metal' 8BPP Hello World Demo by krom (Peter Lemon):
// 1. Set Cores 1..3 To Infinite Loop
// 2. Setup Frame Buffer
// 3. Copy Hello World Text Characters To Frame Buffer Using CPU

/*
code64
processor cpu64_v8
format binary as 'img'
include 'LIB\R_PI2.INC'
*/

MAIL_BASE        = 0xB880 // Mailbox Base Address
PERIPHERAL_BASE  = 0x3F000000 // Peripheral Base Address
MAIL_TAGS    = 8 // Mailbox Channel 8: Tags (ARM to VC)
MAIL_WRITE  =   0x20 // Mailbox Write Register

Set_Physical_Display  = 0x00048003 // Frame Buffer: Set Physical (Display) Width/Height (Response: Width In Pixels, Height In Pixels)
Set_Virtual_Buffer    = 0x00048004 // Frame Buffer: Set Virtual (Buffer) Width/Height (Response: Width In Pixels, Height In Pixels)
Set_Depth             = 0x00048005 // Frame Buffer: Set Depth (Response: Bits Per Pixel)
Set_Virtual_Offset    = 0x00048009 // Frame Buffer: Set Virtual Offset (Response: X In Pixels, Y In Pixels)
Set_Palette           = 0x0004800B // Frame Buffer: Set Palette (Response: RGBA Palette Values (Index 0 To 255))
Allocate_Buffer       = 0x00040001 // Frame Buffer: Allocate Buffer (Response: Frame Buffer Base Address In Bytes, Frame Buffer Size In Bytes)


// Setup Frame Buffer
SCREEN_X       = 640
SCREEN_Y       = 480
BITS_PER_PIXEL = 8

// Setup Characters
CHAR_X = 8
CHAR_Y = 8

// Return CPU ID (0..3) Of The CPU Executed On
mrs x0,MPIDR_EL1 // X0 = Multiprocessor Affinity Register (MPIDR)
ands x0,x0,3 // X0 = CPU ID (Bits 0..1)
b.ne CoreLoop // IF (CPU ID != 0) Branch To Infinite Loop (Core ID 1..3)

FB_Init:
  mov w0,FB_STRUCT + MAIL_TAGS
  mov x1,MAIL_BASE
  orr x1,x1,PERIPHERAL_BASE
  str w0,[x1,MAIL_WRITE + MAIL_TAGS] // Mail Box Write

  ldr w0, FB_POINTER // W0 = Frame Buffer Pointer
  cbz w0,FB_Init // IF (Frame Buffer Pointer == Zero) Re-Initialize Frame Buffer

  and w0,w0,0x3FFFFFFF // Convert Mail Box Frame Buffer Pointer From BUS Address To Physical Address ($CXXXXXXX -> $3XXXXXXX)
  adr x1,FB_POINTER
  str w0,[x1] // Store Frame Buffer Pointer Physical Address

mov x3,0 // Counter
mov x8,0x3333
orr x8,x8,x8,LSL 16
orr x8,x8,x8,LSL 32
and x7,x8,x8,LSR 1
orr x7,x7,x7,LSL 2 // Save an instruction by constructing 0x7777 from 0x3333

mov w17,w0

Loop:
  add x3,x3,1

  // Calculate div faster using multiplication

  // MOD 3
  umulh x9,x3,x7
  add x9,x9,1
  add x9,x9,x9,LSL 1
  cmp x9,x3
  beq Mod3
  PRNUM:
    adr x2,NumberBuffer // X2 = Text Offset
    add x9, x3, 1
    umulh x9, x9, x8 // /5
    and x9,x9,-2 // /2 * 2
    add x10, x9, x9,LSL 2 // *5
    sub x10, x3, x10
    add w10,w10, 0x30
    strb w10,[x2]
  b EndMod

  Mod3:
    adr x2,Fizz

  EndMod:

  // Draw Characters
  mov w1,256 + (SCREEN_X * 32)
  mov w18,SCREEN_X * 8
  and x19,x3,0x1F
  mul w18,w18,w19
  add w1,w1,w18
  add w0,w17,w1 // Place Text At XY Position 256,32

  adr x1,Font // X1 = Characters

  DrawChars:
    mov w4,CHAR_Y // W4 = Character Row Counter
    ldrb w5,[x2],#1 // X5 = Next Text Character, Advance text pointer
    cmp w5,#0
    beq EndChars
    add x5,x1,x5,lsl 6 // Add Shift To Correct Position In Font (* 64)

    DrawChar:
      ldr x6,[x5],8 // Load Font Text Character Row
      str x6,[x0],8 // Store Font Text Character Row To Frame Buffer
      add x0,x0,SCREEN_X - CHAR_X // Jump Down 1 Scanline, Jump Back 1 Char
      subs w4,w4,1 // Decrement Character Row Counter
      b.ne DrawChar // IF (Character Row Counter != 0) DrawChar
    mov x4,(SCREEN_X * CHAR_Y) - CHAR_X
    sub x0,x0,x4 // Jump To Top Of Char, Jump Forward 1 Char
    b DrawChars
  EndChars:

  mov x15,0
  movk x15,0x0020,LSL 16
  Delay:
    subs x15,x15,1
    bne Delay

  b Loop

CoreLoop: // Infinite Loop For Core 1..3
  b CoreLoop

.align 4
FB_STRUCT: // Mailbox Property Interface Buffer Structure
  .word FB_STRUCT_END - FB_STRUCT // Buffer Size In Bytes (Including The Header Values, The End Tag And Padding)
  .word 0x00000000 // Buffer Request/Response Code
	       // Request Codes: $00000000 Process Request Response Codes: $80000000 Request Successful, $80000001 Partial Response
// Sequence Of Concatenated Tags
  .word Set_Physical_Display // Tag Identifier
  .word 0x00000008 // Value Buffer Size In Bytes
  .word 0x00000008 // 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
  .word SCREEN_X // Value Buffer
  .word SCREEN_Y // Value Buffer

  .word Set_Virtual_Buffer // Tag Identifier
  .word 0x00000008 // Value Buffer Size In Bytes
  .word 0x00000008 // 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
  .word SCREEN_X // Value Buffer
  .word SCREEN_Y // Value Buffer

  .word Set_Depth // Tag Identifier
  .word 0x00000004 // Value Buffer Size In Bytes
  .word 0x00000004 // 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
  .word BITS_PER_PIXEL // Value Buffer

  .word Set_Virtual_Offset // Tag Identifier
  .word 0x00000008 // Value Buffer Size In Bytes
  .word 0x00000008 // 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
FB_OFFSET_X:
  .word 0 // Value Buffer
FB_OFFSET_Y:
  .word 0 // Value Buffer

  .word Set_Palette // Tag Identifier
  .word 0x00000010 // Value Buffer Size In Bytes
  .word 0x00000010 // 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
  .word 0 // Value Buffer (Offset: First Palette Index To Set (0-255))
  .word 2 // Value Buffer (Length: Number Of Palette Entries To Set (1-256))
FB_PAL:
  .word 0x00000000, 0xFFFFFFFF // RGBA Palette Values (Offset To Offset+Length-1)

  .word Allocate_Buffer // Tag Identifier
  .word 0x00000008 // Value Buffer Size In Bytes
  .word 0x00000008 // 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
FB_POINTER:
  .word 0 // Value Buffer
  .word 0 // Value Buffer

.word 0x00000000 // $0 (End Tag)
FB_STRUCT_END:

NumberBuffer:
  .ascii "TODO: Do number         \0"

Fizz:
  .ascii "Fizz                    \0"

Buzz:
  .ascii "Buzz                    \0"

Fizzbuzz:
  .ascii "Fizzbuzz                \0"

.align 3
Font:
  .include "Font8x8.s"
