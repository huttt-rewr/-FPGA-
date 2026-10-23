"""Verify generated menu glyphs and immutable legacy artwork."""
from pathlib import Path
import hashlib
import re
import unittest
import gen_zh_font as font

ROOT = Path(__file__).resolve().parent.parent


class FontTests(unittest.TestCase):
    def test_legacy_and_embedded_words(self):
        base = ROOT/'src/modules/osd'
        words = [int(w,16) for w in (base/'zh_font.mem').read_text().split()]
        self.assertEqual(len(words), 1232)
        self.assertEqual(hashlib.sha256(b''.join(w.to_bytes(2,'big') for w in words[:512])).hexdigest(),
                         'fdb922b8775a74f73ebc471632e15ac5f8bb2d8c96658a2b908b8a6ed026a736')
        rtl = (base/'zh_font_rom.v').read_text()
        embedded = {int(i):int(v,16) for i,v in re.findall(r"mem\[(\d+)\]=16'h([0-9a-f]+);",rtl)}
        self.assertEqual([embedded[i] for i in range(1232)], words)
        for name,expected in [('legacy_words',words[:512]),('menu_words',words[512:])]:
            bank = {int(i):int(v,16) for i,v in re.findall(
                name+r"\[(\d+)\]=16'h([0-9a-f]+);",rtl)}
            self.assertEqual([bank[i] for i in range(len(expected))],expected)
        self.assertNotIn('$readmem',rtl)
        self.assertEqual(len(font.CHARS),77)
        self.assertEqual(font.CHARS[32:34], '菜单')
        for index,ch in enumerate(font.CHARS[32:],32):
            if ch!=' ':
                self.assertTrue(any(words[index*16:index*16+16]),ch)


if __name__ == '__main__':
    unittest.main(verbosity=2)
