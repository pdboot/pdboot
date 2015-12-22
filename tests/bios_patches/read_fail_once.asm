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

; Remove patched interrupt, so that the next read succeeds
push eax
push ds

xor ax,ax
mov ds,ax

mov eax,dword[ds:(fallback * 4)]
mov dword[ds:(interrupt * 4)],eax

pop ds
pop eax
iret

; Padding
times (512*sectors)-($-$$)-1 db 0
