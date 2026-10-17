from pathlib import Path
import shutil

root = Path(__file__).resolve().parents[2]
out = root/'reports/fat32_20261015'
for path in (root/'reports/previous_build').rglob('timing_status.txt'):
    text = path.read_text()
    label = ('initial' if 'SWNS: -2.150ns' in text else
             'pipeline' if 'SWNS: -0.690ns' in text else
             'compact' if 'SWNS: -0.733ns' in text else
             'boundary' if 'SWNS: -0.854ns' in text else
             'metadata' if 'SWNS: -2.173ns' in text else
             'onehot' if 'SWNS: -1.994ns' in text else
             'parallel' if 'SWNS: -0.450ns' in text else
             'checks' if 'SWNS: -1.047ns' in text else
             'descriptors' if 'SWNS: -0.672ns' in text else
             'response' if 'SWNS: -0.091ns' in text else
             'store' if 'SWNS: -0.472ns' in text else
             'boot_physplace' if 'SWNS: -1.134ns' in text else
             'geomfields' if 'SWNS: -0.541ns' in text else None)
    if label:
        dest = out/f'trial_{label}'
        dest.mkdir(exist_ok=True)
        for name in ('timing_status.txt', 'timing_summary.txt', 'implementation.log', 'physical_area.txt'):
            source = path.parent/name
            if source.is_file():
                shutil.copy2(source, dest/name)
        print(label, text.strip())
