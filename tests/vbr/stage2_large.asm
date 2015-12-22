[BITS 16]
[ORG 0x2000]

; This is an artificially inflated stage 2, which has a character to output
; every 10240 bytes, to prove that the whole file was loaded.

; Allow interrupts
; See http://forum.osdev.org/viewtopic.php?p=236455#p236455 for more information
sti

xor dx,dx
mov bp,message
jmp start_output

output_loop:
int 0x10        ; output
add dx,640      ; 10k separation per character = 640 paragraphs
start_output:
mov ds,dx
mov ah,0x0e     ; BIOS teletype
mov al,[ds:bp]     ; get next char
cmp al,0        ; check for end of string
jnz output_loop
hang:
; Bochs magic breakpoint, for unit testing purposes.
xchg bx,bx
sti
hlt
jmp hang

message: db "L"
times 10239 db 0
db "o"
times 10239 db 0
db "a"
times 10239 db 0
db "d"
times 10239 db 0
db "e"
times 10239 db 0
db "d"
times 10239 db 0
db " "
times 10239 db 0
db "i"
times 10239 db 0
db "n"
times 10239 db 0
db "o"
times 10239 db 0
db "d"
times 10239 db 0
db "e"
times 10239 db 0
db " "
times 10239 db 0
db "5"
times 10239 db 0
db " "
times 10239 db 0
db "s"
times 10239 db 0
db "t"
times 10239 db 0
db "a"
times 10239 db 0
db "g"
times 10239 db 0
db "e"
times 10239 db 0
db "2"
times 10239 db 0
db " "
times 10239 db 0
db "b"
times 10239 db 0
db "o"
times 10239 db 0
db "o"
times 10239 db 0
db "t"
times 10239 db 0
db "l"
times 10239 db 0
db "o"
times 10239 db 0
db "a"
times 10239 db 0
db "d"
times 10239 db 0
db "e"
times 10239 db 0
db "r"
times 10239 db 0
db "."
times 10239 db 0
db 0
