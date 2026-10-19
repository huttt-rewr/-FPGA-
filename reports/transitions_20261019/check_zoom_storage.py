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
        live_rows=[]
        first_bad=None
        last_source=((height-1)*16)//numerator
        for out_y in range(height):
            source_y=(out_y*16)//numerator
            oldest_available=max(0,out_y-1)
            if source_y<oldest_available and first_bad is None:
                first_bad={'output_row':out_y,'source_row':source_y,
                           'two_rows_contain':[out_y-1,out_y]}
            rows.append(out_y-source_y+1)
            # Even discarding rows below the cropped source window leaves a large
            # set of already-arrived source rows needed by future output pixels.
            live_rows.append(max(0,min(out_y,last_source)-source_y+1))
        retained=max(rows)
        cases.append({'width':width,'height':height,'zoom_n':numerator,
                      'max_full_rolling_window_rows':retained,
                      'rolling_window_bits':retained*width*24,
                      'rolling_window_bram9k_ideal_packing':math.ceil(retained*width*24/9216),
                      'max_live_whole_source_rows_after_crop_discard':max(live_rows),
                      'live_whole_rows_bram9k_ideal_packing':math.ceil(max(live_rows)*width*24/9216),
                      'first_missing_row':first_bad})
        if numerator>16:
            assert first_bad is not None
assert cases[2]['max_full_rolling_window_rows']==161
assert cases[5]['max_full_rolling_window_rows']==201
Path(__file__).with_name('zoom_storage.json').write_text(json.dumps(cases,indent=2),encoding='utf-8')
print('Confirmed: two recent rows cannot implement the requested 2D zoom.')
print('1.5x rolling history spans 161 VGA rows / 201 SVGA rows; this is NOT a universal memory lower bound.')
print('Even discarding cropped-away whole rows needs',cases[2]['max_live_whole_source_rows_after_crop_discard'],
      '/',cases[5]['max_live_whole_source_rows_after_crop_discard'],'live whole rows; spare BRAM = 23.')
