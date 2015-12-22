# -*- coding: utf-8 -*-

try:
  from .config import default_bochs
except ImportError:
  print("tests/config.py is missing. Please copy tests/default_config.py and make any customizations you need.")
  raise
import os
import re
import subprocess
import tempfile
import threading

__all__ = ['Bochs', 'extract_dl', 'extract_cs', 'extract_rip', 'extract_screen_contents']

def extract_dl(output):
  return re.search('rdx: [0-9a-f]{8}_[0-9a-f]{6}([0-9a-f]{2})\s', output).group(1)

def extract_rip(output):
  return re.search('rip: ([0-9a-f]{8}_[0-9a-f]{8})\s', output).group(1)

def extract_cs(output):
  return re.search('cs:0x([0-9a-f]{4}),', output).group(1)

def extract_screen_contents(video_memory):
  return str(video_memory[::2], encoding='cp437')

def format(obj):
  if isinstance(obj, tuple):
    return format_tuple(*obj)
  elif isinstance(obj, str):
    return format_string(obj)
  else:
    try:
      obj = iter(obj)
    except:
      return format_string(str(obj))
    return format_iter(obj)

def format_string(string):
  if '\r' in string or '\n' in string or '"' in string:
    raise Exception('String contains invalid characters: ' + string)
  if ' ' in string or '\t' in string or ',' in string:
    return '"' + string + '"'
  return string

def format_iter(iter):
  return ', '.join([format(x) for x in iter])

def format_tuple(key, value):
  return format(key) + '=' + format(value)

class BochsOutput:
  def __init__(self, stdout, stderr):
    self.stdout = stdout
    self.stderr = stderr

  def split(self):
    return re.split('<bochs:\d+>', self.stdout)

class Bochs:
  def __init__(self, log = None, hdd = None, boot = None, bochs = None, optrom = None):
    if log == None:
      f = tempfile.NamedTemporaryFile(delete = False)
      log = f.name
      f.close()
    self._config = {
      'display_library': 'nogui',
      'port_e9_hack': [('enabled', 1)],
      'magic_break': [('enabled', 1)],
      'romimage': [('file', '$BXSHARE/BIOS-bochs-latest')],
      'vgaromimage': [('file', '$BXSHARE/VGABIOS-lgpl-latest')],
      'log': log
    }
    autoboot = []
    if hdd != None:
      self._config['ata0-master'] = [('type', 'disk'), ('path', hdd)]
      autoboot.append('disk')
    if boot == None:
      boot = autoboot
    if optrom != None:
      self._config['optromimage1'] = [('file', optrom), ('address', '0xd0000')]
    self._config['boot'] = boot
    self._bochs = bochs if bochs != None else default_bochs

  def run(self, *commands, timeout = 5):
    rc = tempfile.NamedTemporaryFile(mode = 'w', delete = False)
    for key in self._config:
      value = self._config[key]
      rc.write(format(key))
      rc.write(': ')
      rc.write(format(value))
      rc.write('\n')
    rc.close()
    p = subprocess.Popen(
      [self._bochs, '-q', '-f', rc.name],
      stdin = subprocess.PIPE,
      stdout = subprocess.PIPE,
      stderr = subprocess.PIPE,
      universal_newlines = True)
    try:
      out, err = p.communicate(input = '\n'.join(commands) + '\n', timeout = timeout)
    except subprocess.TimeoutExpired:
      p.kill()
      raise
    return BochsOutput(out, err)
