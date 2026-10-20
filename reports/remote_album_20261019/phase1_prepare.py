from pathlib import Path
root=Path(__file__).resolve().parents[2]
for name in ('tb_board_pipeline','tb_effects_pipeline','tb_svga_pipeline','tb_caption_overlay','tb_caption_pipeline'):
    p=root/'sim'/(name+'.v');s=p.read_text()
    import re
    def update(m):
        text=m.group()
        # Old short positional users did not supply mode_800 either.
        if name in ('tb_effects_pipeline','tb_caption_overlay'):
            extra=",1'b0,8'd0,24'd0,1'b0"
        else:extra=",8'd0,24'd0,1'b0"
        return text[:-2]+extra+');'
    s=re.sub(r'caption_overlay\s+(?:#\(.*?\)\s*)?\w+\(.*?\);',update,s,flags=re.S)
    p.write_text(s,encoding='utf-8')
p=root/'scripts/run_tests.ps1';s=p.read_text()
s=s.replace('$files += @($mergeTests |',"$mergeTests += @('tb_remote_uart')\n $files += @($mergeTests |")
p.write_text(s,encoding='utf-8')
print('Updated caption callers and registered UART integration regression')
