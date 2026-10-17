"""Check capacity-comparison rewrite at accepted BPB bounds and random points."""
import random

rng = random.Random(20261016)
sectors = [0, 1, 511, 512, 513, 0x1fffff, 0x7fffff, 0xffffff]
clusters = [0, 1, 127, 128, 129, 65525, 0xfffffed, 0xfffffee, 0xffffffff]
cases = [(a,b) for a in sectors for b in clusters]
cases += [(rng.randrange(1<<24),rng.randrange(1<<32)) for _ in range(100000)]
for fat, maximum in cases:
    assert (((fat<<7)&0xffffffff)<=maximum) == (fat<=(maximum>>7))
print(f'ALL PASS {len(cases)} capacity comparisons with accepted fat_sectors[31:24]==0')
fat, maximum = 0x02000000, 1
assert (((fat<<7)&0xffffffff)<=maximum) != (fat<=(maximum>>7))
print('Unrestricted identity is false; existing BPB upper-byte rejection is required')
