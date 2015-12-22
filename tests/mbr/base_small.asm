; Partition struc definition
struc partition
.status     resb 1
.start_chs  resb 3
.type       resb 1
.end_chs    resb 3
.start_lba  resd 1
.length_lba resd 1
endstruc

; MBR code
incbin 'mbr/mbr.bin',0,440

; Disk signature
dd 0x2c585cd1

; Padding
dw 0

; Partition 1 at sector 1, length 1
istruc partition
at partition.status,     db 0
at partition.start_chs,  db 0,2,0
at partition.type,       db 0x83
at partition.end_chs,    db 0,2,0
at partition.start_lba,  dd 1
at partition.length_lba, dd 1
iend

; Partition 2 at sector 2, length 1
istruc partition
at partition.status,     db 0
at partition.start_chs,  db 0,3,0
at partition.type,       db 0x83
at partition.end_chs,    db 0,3,0
at partition.start_lba,  dd 2
at partition.length_lba, dd 1
iend

; Partition 3 at sector 3, length 1
istruc partition
at partition.status,     db 0
at partition.start_chs,  db 0,4,0
at partition.type,       db 0x83
at partition.end_chs,    db 0,4,0
at partition.start_lba,  dd 3
at partition.length_lba, dd 1
iend

; Partition 4 at sector 4, length 1
istruc partition
at partition.status,     db 0
at partition.start_chs,  db 0,5,0
at partition.type,       db 0x83
at partition.end_chs,    db 0,5,0
at partition.start_lba,  dd 4
at partition.length_lba, dd 1
iend

; Boot signature
dw 0xaa55

; Partition 1 contents
times 510 db 1
dw 0xaa55

; Partition 2 contents
times 510 db 2
dw 0xaa55

; Partition 3 contents
times 510 db 3
dw 0xaa55

; Partition 4 contents
times 510 db 4
dw 0xaa55

; Pad disk image to 63 tracks, 16 heads (minimum Bochs allows)
times (16*63*512)-($-$$) db 0
