.PHONY: all targets clean test

pdboot = mbr/mbr.bin vbr/vbr-ext2.bin
tools = tools/ext4-swap-boot-inode
tests = tests/mbr/base_small.img tests/bios_patches/read_fail.img tests/bios_patches/no_lba.img tests/bios_patches/read_fail_once.img

targets = $(pdboot) $(tools) $(tests)

all: $(targets)

mbr/mbr.bin: mbr/mbr.asm
	nasm $< -o $@

vbr/vbr-ext2.bin: vbr/vbr-ext2.asm
	nasm $< -o $@

tests/mbr/base_small.img: tests/mbr/base_small.asm mbr/mbr.bin
	nasm $< -o $@

tools/ext4-swap-boot-inode: tools/ext4-swap-boot-inode.c

tests/bios_patches/%.img: tests/bios_patches/%.asm tests/bios_patches/interrupt_patch.asm
	nasm $< -o $@
	tools/optromchecksum.py $@

test: all
	py.test-3 tests $(pytest_options)

clean:
	rm -f $(targets) tests/mbr/test_*.img tests/vbr/test_*.img
