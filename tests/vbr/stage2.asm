[BITS 16]
[ORG 0x2000]

; Allow interrupts
; See http://forum.osdev.org/viewtopic.php?p=236455#p236455 for more information
sti

mov bp,message
jmp start_output

output_loop:
int 0x10        ; output
inc bp
start_output:
mov ah,0x0e     ; BIOS teletype
mov al,[bp]     ; get next char
cmp al,0        ; check for end of string
jnz output_loop
hang:
; Bochs magic breakpoint, for unit testing purposes.
xchg bx,bx
sti
hlt
jmp hang

message: db "Loaded inode 5 stage2 bootloader.",0
