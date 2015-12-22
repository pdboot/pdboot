[BITS 16]
[ORG 0]

sectors equ 1
interrupt equ 0x13
fallback equ 0xa7

%include 'tests/bios_patches/interrupt_patch.asm'

interrupt_handler:
pushf
cmp ah,0x42 ; ah=0x42 is disk read, which we want to fail
je fail
popf
jmp fallback_handler

fail:
push bp
mov bp,sp
or word[ss:bp+8],1
pop bp
popf
iret

; Padding
times (512*sectors)-($-$$)-1 db 0
