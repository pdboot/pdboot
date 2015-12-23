# -*- coding: utf-8 -*-

from ..bochs import Bochs, extract_screen_contents
from ..utils import delete_if_exists
import re

partition_type_offset = 4

with open('tests/mbr/base_small.img', 'rb') as f:
  base_small = f.read()

def _test_boot_partition(partition, optrom = None):
  # Calculate offsets
  table_offset = 446 + 16 * (partition - 1)
  partition_offset = 512 * partition

  # Set up disk image
  image = bytearray(base_small)
  image[table_offset] = 0x80
  image_path = 'tests/mbr/test_boot_partition_{0}.img'.format(str(partition))
  with open(image_path, 'wb') as f:
    f.write(image)

  # Run Bochs
  entry_path = 'tests/mbr/test_boot_partition_{0}_entry.img'.format(str(partition))
  delete_if_exists(entry_path)
  vbr_path = 'tests/mbr/test_boot_partition_{0}_vbr.img'.format(str(partition))
  delete_if_exists(vbr_path)
  bochs = Bochs(hdd = image_path, optrom = optrom)
  output = bochs.run(
    'b 0x7c00',
    'c',
    'r',
    'c',
    'r',
    'sreg',
    'writemem \'{0}\' ds:si 16'.format(entry_path),
    'writemem \'{0}\' 0x7c00 512'.format(vbr_path),
    'quit')

  # Print Bochs output for debugging
  print(output.stdout)

  # Extract data
  with open(entry_path, 'rb') as f:
    table_entry = f.read()
  with open(vbr_path, 'rb') as f:
    vbr = f.read()
  dl_before = output[3].regs.dl
  dl_after = output[5].regs.dl
  rip_after = output[5].regs.rip
  cs_after = output[6].sregs.cs

  # Assertions
  assert dl_after == dl_before
  assert rip_after == 0x7c00
  assert cs_after == 0x0000
  assert table_entry == image[table_offset:table_offset+16]
  assert vbr == image[partition_offset:partition_offset+512]

def test_boot_partition_1(): _test_boot_partition(1)
def test_boot_partition_2(): _test_boot_partition(2)
def test_boot_partition_3(): _test_boot_partition(3)
def test_boot_partition_4(): _test_boot_partition(4)

def test_no_active_partitions():
  # Set up disk image
  image = bytearray(base_small)
  image_path = 'tests/mbr/test_no_bootable_partitions.img'
  with open(image_path, 'wb') as f:
    f.write(image)

  # Run Bochs
  vmem_path = 'tests/mbr/test_no_bootable_partitions_vmem.img'
  delete_if_exists(vmem_path)
  bochs = Bochs(hdd = image_path)
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
  assert 'No active partition found!' in screen_contents

def test_active_partition_with_invalid_type():
  # Offsets
  table_offset = 446

  # Set up disk image
  image = bytearray(base_small)
  image[table_offset] = 0x80
  image[table_offset+partition_type_offset] = 0
  image_path = 'tests/mbr/test_active_partition_with_invalid_type.img'
  with open(image_path, 'wb') as f:
    f.write(image)

  # Run Bochs
  vmem_path = 'tests/mbr/test_active_partition_with_invalid_type_vmem.img'
  delete_if_exists(vmem_path)
  bochs = Bochs(hdd = image_path)
  output = bochs.run(
    'b 0x7c00',
    'c',
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
  assert 'Active partition has invalid partition type!' in screen_contents

def test_no_lba_extensions():
  # Offsets
  table_offset = 446

  # Set up disk image
  image = bytearray(base_small)
  image[table_offset] = 0x80
  image_path = 'tests/mbr/test_no_lba_extensions.img'
  with open(image_path, 'wb') as f:
    f.write(image)

  # Run Bochs
  vmem_path = 'tests/mbr/test_no_lba_extensions_vmem.img'
  delete_if_exists(vmem_path)
  bochs = Bochs(hdd = image_path, optrom = 'tests/bios_patches/no_lba.img')
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
  assert 'BIOS does not support LBA extensions!' in screen_contents

def test_single_disk_read_failure(): _test_boot_partition(1, optrom = 'tests/bios_patches/read_fail_once.img')

def test_disk_read_failure():
  # Offsets
  table_offset = 446

  # Set up disk image
  image = bytearray(base_small)
  image[table_offset] = 0x80
  image_path = 'tests/mbr/test_disk_read_failure.img'
  with open(image_path, 'wb') as f:
    f.write(image)

  # Run Bochs
  vmem_path = 'tests/mbr/test_disk_read_failure_vmem.img'
  delete_if_exists(vmem_path)
  bochs = Bochs(hdd = image_path, optrom = 'tests/bios_patches/read_fail.img')
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
  assert 'Failed to read volume boot record!' in screen_contents

def test_active_partition_with_no_boot_signature():
  # Offsets
  table_offset = 446
  partition_1_boot_signature = 1024 - 2

  # Set up disk image
  image = bytearray(base_small)
  image[table_offset] = 0x80
  image[partition_1_boot_signature] = 0
  image[partition_1_boot_signature+1] = 0
  image_path = 'tests/mbr/test_active_partition_with_no_boot_signature.img'
  with open(image_path, 'wb') as f:
    f.write(image)

  # Run Bochs
  vmem_path = 'tests/mbr/test_active_partition_with_no_boot_signature_vmem.img'
  delete_if_exists(vmem_path)
  bochs = Bochs(hdd = image_path)
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
  assert 'Volume boot record is not bootable (missing 0xaa55 boot signature)!' in screen_contents
