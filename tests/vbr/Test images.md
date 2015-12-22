Setup
=====

```bash
nasm base_unformatted.asm -o base_unformatted.img
nasm stage2.asm -o stage2.bin
nasm stage2_large.asm -o stage2_large.bin
```

base_simple.img
===============

```bash
cp base_unformatted.img base_simple.img
nbd-bind base_simple.img base_simple
mke2fs base_simple-p1
mkdir mp
sudo mount base_simple-p1 mp
sudo cp stage2.bin mp
cd mp
sudo ../../../tools/ext4-swap-boot-inode stage2.bin
sudo rm stage2.bin
cd ..
sudo umount mp
rmdir mp
nbd-unbind base_simple
```

base_4k_blocks.img
==================

```bash
cp base_unformatted.img base_4k_blocks.img
nbd-bind base_4k_blocks.img base_4k_blocks
mke2fs -b 4096 base_4k_blocks-p1
mkdir mp
sudo mount base_4k_blocks-p1 mp
sudo cp stage2.bin mp
cd mp
sudo ../../../tools/ext4-swap-boot-inode stage2.bin
sudo rm stage2.bin
cd ..
sudo umount mp
rmdir mp
nbd-unbind base_4k_blocks
```

base_256b_inodes.img
====================

```bash
cp base_unformatted.img base_256b_inodes.img
nbd-bind base_256b_inodes.img base_256b_inodes
mke2fs -I 256 base_256b_inodes-p1
mkdir mp
sudo mount base_256b_inodes-p1 mp
sudo cp stage2.bin mp
cd mp
sudo ../../../tools/ext4-swap-boot-inode stage2.bin
sudo rm stage2.bin
cd ..
sudo umount mp
rmdir mp
nbd-unbind base_256b_inodes
```

base_indirect.img
=================

This image has a large bootloader that uses indirect and doubly indirect blocks.

```bash
cp base_unformatted.img base_indirect.img
nbd-bind base_indirect.img base_indirect
mke2fs base_indirect-p1
mkdir mp
sudo mount base_indirect-p1 mp
sudo cp stage2_large.bin mp
cd mp
sudo ../../../tools/ext4-swap-boot-inode stage2_large.bin
sudo rm stage2_large.bin
cd ..
sudo umount mp
rmdir mp
nbd-unbind base_indirect
```
