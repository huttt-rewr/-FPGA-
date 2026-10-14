"""Fixed 800x600 entry point; uses the validated official-converter adaptation."""
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'scripts'))
import prepare_media
if __name__=='__main__':
    sys.argv=[sys.argv[0],'convert',*sys.argv[1:],'--width','800','--height','600']
    raise SystemExit(prepare_media.main())
