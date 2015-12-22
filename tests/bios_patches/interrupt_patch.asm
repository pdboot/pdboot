; Signature
dw 0xaa55
db sectors

; Install patched interrupt
push eax
push ds

xor ax,ax
mov ds,ax

mov eax,dword[ds:(interrupt * 4)]
mov dword[ds:(fallback * 4)],eax
mov eax,0xd0000000 + interrupt_handler
mov dword[ds:(interrupt * 4)],eax

pop ds
pop eax

retf

fallback_handler:
int fallback
; Patch the stack with the flags returned from the actual BIOS call
pushf
push bp
push ax
mov bp,sp
mov ax,word[ss:bp+4]
mov word[ss:bp+10],ax
pop ax
pop bp
popf
iret
