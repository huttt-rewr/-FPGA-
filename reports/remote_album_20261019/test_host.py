"""Exercise the PC helper without importing pyserial or opening a COM port."""
from pathlib import Path
import datetime as dt
import importlib.util
import unittest

root=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('album_remote',root/'scripts/album_remote.py')
remote=importlib.util.module_from_spec(spec)
spec.loader.exec_module(remote)

class Port:
 def __init__(self,reply):self.reply=reply;self.writes=[];self.flushed=False
 def write(self,data):self.writes.append(data)
 def flush(self):self.flushed=True
 def read(self,n):assert n==1;return self.reply

class HostTests(unittest.TestCase):
 def test_beijing_conversion_and_midnight(self):
  utc=dt.timezone.utc
  self.assertEqual(remote.time_packet(dt.datetime(2026,10,20,16,0,0,tzinfo=utc)),b'T000000')
  self.assertEqual(remote.time_packet(dt.datetime(2026,10,20,15,59,59,tzinfo=utc)),b'T235959')
 def test_command_bytes_and_single_ack(self):
  for packet in (b'n',b'p',b'b',b'a',b's',b'h',b'l',b'T123456'):
   port=Port(b'K');self.assertEqual(remote.exchange(port,packet),b'K')
   self.assertEqual(port.writes,[packet]);self.assertTrue(port.flushed)
 def test_errors_are_not_reported_as_success(self):
  for reply in (b'?',b'',b'X'):
   with self.assertRaises(RuntimeError):remote.exchange(Port(reply),b'n')

if __name__=='__main__':unittest.main()
