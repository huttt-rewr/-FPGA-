"""Fixed 321x241 entry point; uses the validated official-converter adaptation."""
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'scripts'))
import prepare_media
if __name__=='__main__':
    sys.argv=[sys.argv[0],'convert',*sys.argv[1:],'--width','321','--height','241']
    raise SystemExit(prepare_media.main())
