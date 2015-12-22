# -*- coding: utf-8 -*-

from ..bochs import Bochs, extract_dl, extract_cs, extract_rip, extract_screen_contents
from ..utils import delete_if_exists
import struct

VBR_OFFSET = 4096
VBR_LEN = 1024

SUPERBLOCK_OFFSET = 5120

INODE_OFFSET = 10752

with open('vbr/vbr-ext2.bin', 'rb') as f:
  vbr = f.read()
assert len(vbr) == VBR_LEN

with open('tests/vbr/base_simple.img', 'rb') as f:
  base_simple = f.read()

with open('tests/vbr/base_4k_blocks.img', 'rb') as f:
  base_4k_blocks = f.read()

with open('tests/vbr/base_256b_inodes.img', 'rb') as f:
  base_256b_inodes = f.read()

with open('tests/vbr/base_indirect.img', 'rb') as f:
  base_indirect = f.read()

NO_LBA_ERROR = 'BIOS does not support LBA extensions!'
READ_ERROR = 'Error reading disk!'
INVALID_EXT_ERROR = 'Invalid or unsupported ext2 filesystem!'
BOOTLOADER_ERROR = 'Bootloader is missing or empty!'
MEMORY_ERROR = 'Out of low memory!'
STAGE2_MESSAGE = 'Loaded inode 5 stage2 bootloader.'

def _test(test_name, expected_output, base_image = base_simple, optrom = None):
  # Set up disk image
  image = bytearray(base_image)
  image[VBR_OFFSET:VBR_OFFSET+VBR_LEN] = vbr
  image_path = 'tests/vbr/{0}.img'.format(test_name)
  with open(image_path, 'wb') as f:
    f.write(image)

  # Run Bochs
  vmem_path = 'tests/vbr/{0}_vmem.img'.format(test_name)
  delete_if_exists(vmem_path)
  bochs = Bochs(hdd = image_path, optrom = optrom)
  output = bochs.run(
    'c',
    'writemem \'{0}\' 0xb8000 4000'.format(vmem_path),
    'quit')

  # Print Bochs output for debugging
  print(output.stdout)

  # Extract data
  with open(vmem_path, 'rb') as f:
    video_memory = f.read()
  screen_contents = extract_screen_contents(video_memory)

  # Assertions
  assert expected_output in screen_contents

def test_boot_data():
  UUID_OFFSET = 104

  # Set up disk image
  image = bytearray(base_simple)
  image[VBR_OFFSET:VBR_OFFSET+VBR_LEN] = vbr
  image_path = 'tests/vbr/test_boot_data.img'
  with open(image_path, 'wb') as f:
    f.write(image)

  # Run Bochs
  vmem_path = 'tests/vbr/test_boot_data_vmem.img'
  data_path = 'tests/vbr/test_boot_data_data.img'
  delete_if_exists(vmem_path)
  delete_if_exists(data_path)
  bochs = Bochs(hdd = image_path)
  output = bochs.run(
    'b 0x7c00',
    'b 0x2000',
    'c', # Continue to MBR
    'r',
    'c', # Continue to VBR
    'c', # Continue to stage 2
    'r',
    'sreg',
    'writemem \'{0}\' ds:si 33'.format(data_path),
    'c', # Run stage 2
    'writemem \'{0}\' 0xb8000 4000'.format(vmem_path),
    'quit')

  # Print Bochs output for debugging
  print(output.stdout)

  # Extract data
  with open(vmem_path, 'rb') as f:
    video_memory = f.read()
  screen_contents = extract_screen_contents(video_memory)

  with open(data_path, 'rb') as f:
    boot_data = f.read()
  lba_start, lba_length, uuid_low, uuid_high = struct.unpack_from('<QQQQ', boot_data)
  disk_id = struct.unpack_from('B', boot_data, 32)[0]

  split = output.split()
  dl_before = int(extract_dl(split[4]), 16)
  rip = extract_rip(split[7])
  cs = extract_cs(split[8])

  uuid = struct.unpack_from('<QQ', image, SUPERBLOCK_OFFSET + UUID_OFFSET)

  # Assertions
  assert STAGE2_MESSAGE in screen_contents
  assert lba_start == 8
  assert lba_length == 1000
  assert disk_id == dl_before
  assert rip == '00000000_00002000'
  assert cs == '0000'
  assert uuid_low == uuid[0]
  assert uuid_high == uuid[1]

def _bios_patch_test(test_name, patch_name, expected_output):
  _test(test_name, expected_output, optrom = 'tests/bios_patches/{0}.img'.format(patch_name))

def test_no_lba_extensions():
  _bios_patch_test('test_no_lba_extensions', 'no_lba', NO_LBA_ERROR)

def test_disk_read_failure():
  _bios_patch_test('test_disk_read_failure', 'read_fail', READ_ERROR)

def test_success():
  _test('test_success', STAGE2_MESSAGE)

def test_single_read_failure():
  _bios_patch_test('test_single_read_failure', 'read_fail_once', STAGE2_MESSAGE)

def test_invalid_first_data_block():
  FIRST_DATA_BLOCK_OFFSET = 20
  image = bytearray(base_simple)
  image[SUPERBLOCK_OFFSET + FIRST_DATA_BLOCK_OFFSET] = 0 #should be 1 on 1KB block FS
  _test('test_invalid_first_data_block', INVALID_EXT_ERROR, base_image = image)

def test_invalid_block_size():
  LOG_BLOCK_SIZE_OFFSET = 24
  image = bytearray(base_simple)
  image[SUPERBLOCK_OFFSET + LOG_BLOCK_SIZE_OFFSET] = 6 #64KB blocks
  _test('test_invalid_block_size', INVALID_EXT_ERROR, base_image = image)

def test_invalid_fragment_size():
  LOG_FRAGMENT_SIZE_OFFSET = 28
  image = bytearray(base_simple)
  image[SUPERBLOCK_OFFSET + LOG_FRAGMENT_SIZE_OFFSET] = 1 #2KB fragments on 1KB block FS
  _test('test_invalid_fragment_size', INVALID_EXT_ERROR, base_image = image)

def test_too_many_inodes_per_group():
  INODES_PER_GROUP_OFFSET = 40
  image = bytearray(base_simple)
  # In a 1KB block FS, the maximum inodes per group is 8192, as the inode bitmap
  # must fit one one block.
  struct.pack_into('<I', image, SUPERBLOCK_OFFSET + INODES_PER_GROUP_OFFSET, 8200)
  _test('test_too_many_inodes_per_group', INVALID_EXT_ERROR, base_image = image)

def test_invalid_inodes_per_group():
  INODES_PER_GROUP_OFFSET = 40
  image = bytearray(base_simple)
  # The number of inodes per group must be a multiple of the number of inodes
  # that can fit in a block, which is 8 for a 1KB block FS with 128 byte inodes.
  struct.pack_into('<I', image, SUPERBLOCK_OFFSET + INODES_PER_GROUP_OFFSET, 44)
  _test('test_too_many_inodes_per_group', INVALID_EXT_ERROR, base_image = image)

def test_no_ext_signature():
  SIGNATURE_OFFSET = 56
  image = bytearray(base_simple)
  image[SUPERBLOCK_OFFSET + SIGNATURE_OFFSET] = 0
  _test('test_no_ext_signature', INVALID_EXT_ERROR, base_image = image)

def test_unsupported_major_revision():
  REVISION_OFFSET = 76
  image = bytearray(base_simple)
  image[SUPERBLOCK_OFFSET + REVISION_OFFSET] = 2
  _test('test_unsupported_major_revision', INVALID_EXT_ERROR, base_image = image)

def test_unsupported_inode_size():
  INODE_SIZE_OFFSET = 88
  image = bytearray(base_simple)
  struct.pack_into('<H', image, SUPERBLOCK_OFFSET + INODE_SIZE_OFFSET, 300)
  _test('test_unsupported_inode_size', INVALID_EXT_ERROR, base_image = image)

def test_unsupported_features():
  REQUIRED_FEATURES_OFFSET = 96
  image = bytearray(base_simple)
  # 3 = compression and typing. Typing is supported, compression is not.
  image[SUPERBLOCK_OFFSET + REQUIRED_FEATURES_OFFSET] = 3
  _test('test_unsupported_features', INVALID_EXT_ERROR, base_image = image)

def test_bootloader_not_a_regular_file():
  BLOCK_DEVICE = 0x6000
  image = bytearray(base_simple)
  assert struct.unpack_from('<H', image, INODE_OFFSET)[0] == 0x8000
  struct.pack_into('<H', image, INODE_OFFSET, BLOCK_DEVICE)
  _test('test_bootloader_not_a_regular_file', BOOTLOADER_ERROR, base_image = image)

def test_bootloader_missing():
  image = bytearray(base_simple)
  assert struct.unpack_from('<H', image, INODE_OFFSET)[0] == 0x8000
  struct.pack_into('<H', image, INODE_OFFSET, 0)
  _test('test_bootloader_missing', BOOTLOADER_ERROR, base_image = image)

def test_bootloader_empty():
  SIZE_OFFSET = 4
  image = bytearray(base_simple)
  assert struct.unpack_from('<I', image, INODE_OFFSET + SIZE_OFFSET)[0] != 0
  struct.pack_into('<I', image, INODE_OFFSET + SIZE_OFFSET, 0)
  _test('test_bootloader_empty', BOOTLOADER_ERROR, base_image = image)

def test_bootloader_too_large():
  SIZE_OFFSET = 4
  image = bytearray(base_simple)
  struct.pack_into('<I', image, INODE_OFFSET + SIZE_OFFSET, 650000)
  _test('test_bootloader_too_large', MEMORY_ERROR, base_image = image)

def test_sparse_bootloader():
  BLOCK1_OFFSET = 40
  image = bytearray(base_simple)
  assert struct.unpack_from('<I', image, INODE_OFFSET + BLOCK1_OFFSET)[0] != 0
  struct.pack_into('<I', image, INODE_OFFSET + BLOCK1_OFFSET, 0)
  _test('test_sparse_bootloader', INVALID_EXT_ERROR, base_image = image)

def test_4k_blocks():
  _test('test_4k_blocks', STAGE2_MESSAGE, base_image = base_4k_blocks)

def test_256b_inodes():
  _test('test_256b_inodes', STAGE2_MESSAGE, base_image = base_256b_inodes)

def test_indirect():
  _test('test_indirect', STAGE2_MESSAGE, base_image = base_indirect)
