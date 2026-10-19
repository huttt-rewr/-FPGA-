from pathlib import Path
p=Path('docs/TIMING_CLOSE_20261018.md');s=p.read_text(encoding='utf-8-sig')
a='## 通过标准是什么'
b='''## 下一图索引的完整位宽证明

当前索引`cur`为6位，图片计数`count`为7位。原函数用`count==0 || cur>=count-1`判断是否回到第0张。对于非零无符号整数count，`cur>=count-1`等价于`cur+1>=count`；当count为0时，后一式同样恒真。因此可以完整替换成`count<=({1'b0,cur}+7'd1)`。

必须先把cur扩为7位，再加1：63+1应为64，不能在6位中先溢出变0。选中的下一个索引仍使用原6位`cur+6'd1`，因此即使计数超过实际64文件上限，也保留原函数的所有位模式行为。新测试直接调用生产模块函数，穷举64×128=8192组输入；完整播放器回归另查next/prev/direct、忙时选择、实际整帧和PCM。

这项候选只改变组合运算的排列，不增加时钟或SD等待。具体是否保留仍以最终实际结果为准。

## 通过标准是什么'''
assert a in s;s=s.replace(a,b);p.write_text(s,encoding='utf-8')
