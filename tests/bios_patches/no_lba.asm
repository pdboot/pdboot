[BITS 16]
[ORG 0]

sectors equ 1
interrupt equ 0x13
fallback equ 0xa7

%include 'tests/bios_patches/interrupt_patch.asm'

; Fail all calls with 0x41 <= ah <= 0x49
interrupt_handler:
pushf
cmp ah,0x41
jb continue
cmp ah,0x49
jbe fail
continue:
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
