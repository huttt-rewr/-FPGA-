"""Reproduce the live-row requirement for the requested streaming zoom mapping.

No RTL or memory-controller changes: show why two most-recent rows are insufficient.
Assume an ideal instantaneous RAM read (more favorable than actual hardware).
"""
from pathlib import Path
import json, math

cases=[]
for width,height in ((640,480),(800,600)):
    for numerator in (16,20,24):
        rows=[]
        first_bad=None
        for out_y in range(height):
            source_y=(out_y*16)//numerator
            oldest_available=max(0,out_y-1)
            if source_y<oldest_available and first_bad is None:
                first_bad={'output_row':out_y,'source_row':source_y,
                           'two_rows_contain':[out_y-1,out_y]}
            rows.append(out_y-source_y+1)
        retained=max(rows)
        cases.append({'width':width,'height':height,'zoom_n':numerator,
                      'max_simultaneous_retained_rows':retained,
                      'storage_bits_for_full_rows':retained*width*24,
                      'minimum_bram9k_ideal_packing':math.ceil(retained*width*24/9216),
                      'first_missing_row':first_bad})
        if numerator>16:
            assert first_bad is not None
assert cases[2]['max_simultaneous_retained_rows']==161
assert cases[5]['max_simultaneous_retained_rows']==201
Path(__file__).with_name('zoom_storage.json').write_text(json.dumps(cases,indent=2),encoding='utf-8')
print('Confirmed: two recent rows cannot implement the requested 2D zoom.')
print('1.5x: VGA needs 161 retained rows, SVGA needs 201; available spare BRAM = 23.')
