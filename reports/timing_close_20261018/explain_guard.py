from pathlib import Path
p=Path('reports/timing_close_20261018/evidence.py');s=p.read_text(encoding='utf-8')
s=s.replace("assert set(changed)<= {'src/modules/bmp/sd_card_bmp.v'}, 'Only selected image-index candidate may remain'", "assert set(changed)<= {'src/modules/sd/sd_fat32.v'}, 'Only selected FAT32 guard partition may remain'")
s=s.replace("only selected image-index RTL plus flow/regression", "only selected FAT32 guard RTL plus flow/regression")
p.write_text(s,encoding='utf-8')
p=Path('docs/TIMING_CLOSE_20261018.md');s=p.read_text(encoding='utf-8')
a='## 通过标准是什么'
b='''## FAT32把最终OR移到现有下一拍

原版在STREAM_CHECK同时计算六项错误并将其OR存入单个stream_bad寄存器；下一拍STREAM_PREP依据该寄存器决定进入错误态还是继续。新候选在同一个STREAM_CHECK边沿分别存下六项错误，再把六项寄存结果OR送给原来的STREAM_PREP。两者满足：`OR(register(guards)) == register(OR(guards))`，条件是每项使用相同复位值、相同时钟和相同使能；本候选全部满足这些条件。

这样每条宽比较器到它自身结果寄存器的路径不再串接最终OR。最终OR移入下一拍原有状态选择路径；外部SD请求、错误、结束节拍均相同，也不新增状态或等待。代价是最多增加5个结果寄存器，且下一拍状态选择路径略长；因此仍需完整物理验证，不能仅凭这个变换认定更好。全部32/33位比较与卷容量保护保持原式，不依赖错误的24位卷容量假设。

独立真实DUT边界测试与原版逐拍对照通过，覆盖FAT链跳转、双方owner、游标命中/未命中及文件扇区越界。最终是否保留见实际结果。

## 通过标准是什么'''
assert a in s;s=s.replace(a,b);p.write_text(s,encoding='utf-8')
