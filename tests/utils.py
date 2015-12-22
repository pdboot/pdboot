# -*- coding: utf-8 -*-

import errno
import os

def delete_if_exists(filename):
  try:
    os.remove(filename)
  except OSError as e:
    if e.errno != errno.ENOENT:
      raise
