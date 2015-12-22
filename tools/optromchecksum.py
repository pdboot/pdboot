#!/usr/bin/python3
# -*- coding: utf-8 -*-

import sys

def main(args):
  if len(args) != 2:
    print('Usage: optromchecksum.py FILENAME', file=sys.stderr)
    return 1
  filename = args[1]
  with open(filename, 'rb') as in_file:
    raw = in_file.read()
  out = bytearray(raw)
  out.append((-sum(out)) % 256)
  with open(filename, 'wb') as out_file:
    out_file.write(out)
  return 0

if __name__ == '__main__':
  exit(main(sys.argv))
