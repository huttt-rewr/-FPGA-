"""A fake completed tool must not qualify reports left by an older build."""
from pathlib import Path
import importlib.util
import sys
import tempfile

root=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('build',root/'scripts/run_build.py')
build=importlib.util.module_from_spec(spec)
spec.loader.exec_module(build)
with tempfile.TemporaryDirectory(prefix='archive_guard_',dir=Path(__file__).parent) as task_dir:
    build.ROOT=Path(task_dir)
    build.REPORTS=build.ROOT/'reports'
    build.REPORTS.mkdir()
    (build.ROOT/'scripts').mkdir()
    (build.ROOT/'scripts/fake.py').write_text('print("IMPLEMENTATION_COMPLETED")\n')
    products=['video_improve_routed.db','physical_area.txt','timing_status.txt','timing_summary.txt','io.txt',
              'video_improve_prior_opt.db','prior_opt_timing_status.txt',
              'prior_opt_timing_paths20.txt','routed_timing_paths20.txt']
    for name in products:
        (build.REPORTS/name).write_text('stale previous result')
    try:
        build.run(sys.executable,'fake.py','implementation.log','IMPLEMENTATION_COMPLETED',products)
    except RuntimeError as e:
        assert 'Missing fresh products' in str(e)
    else:
        raise AssertionError('Stale products incorrectly qualified as fresh')
    assert all(not (build.REPORTS/name).exists() for name in products)
    archive=list((build.REPORTS/'previous_build').iterdir())
    assert len(archive)==1
    assert all((archive[0]/name).read_text()=='stale previous result' for name in products)
    print('ALL PASS archive guard: completion marker plus nine stale products is rejected; evidence archived')
