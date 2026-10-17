"""Install CMD6 negotiation after the accepted native25 checkpoint."""
from pathlib import Path
import hashlib,json,shutil,subprocess,sys
R=Path(__file__).resolve().parents[2];O=Path(__file__).resolve().parent;stage=sys.argv[1]
v=json.loads((O/(stage+'_validation.json')).read_text())
assert v['build_status']=='completed' and v['regression_passed']==78
for name,digest in v['sources'].items():assert hashlib.sha256((R/name).read_bytes()).hexdigest()==digest,name
subprocess.run(['python',str(O/'prepare_highspeed.py')],cwd=R,check=True)
subprocess.run(['python',str(O/'prepare_highspeed_test.py')],cwd=R,check=True)
for name in ('sd_bus_phy.v','sd_native_controller.v','sd_card_top_native.v'):
 shutil.copy2(O/'highspeed'/name,R/'src/modules/sd/native'/name)
shutil.copy2(O/'highspeed/sd_native_card_model.v',R/'sim/sd_native_card_model.v')
shutil.copy2(O/'highspeed/tb_sd_highspeed.v',R/'sim/tb_sd_highspeed.v')
p=R/'src/modules/sd/sd_card_top.v';s=p.read_text(encoding='utf-8')
s=s.replace('parameter NATIVE_4BIT=0,','parameter NATIVE_4BIT=0,parameter NATIVE_HIGH_SPEED=0,')
s=s.replace('sd_card_top_native #(.SPI_LOW_SPEED_DIV', 'sd_card_top_native #(.ENABLE_HIGH_SPEED(NATIVE_HIGH_SPEED),.SPI_LOW_SPEED_DIV')
p.write_text(s,encoding='utf-8')
p=R/'src/modules/bmp/sd_card_bmp.v';s=p.read_text(encoding='utf-8')
s=s.replace('parameter NATIVE_4BIT=0,', 'parameter NATIVE_4BIT=0,parameter NATIVE_HIGH_SPEED=0,')
s=s.replace('sd_card_top #(.NATIVE_4BIT(NATIVE_4BIT))', 'sd_card_top #(.NATIVE_4BIT(NATIVE_4BIT),.NATIVE_HIGH_SPEED(NATIVE_HIGH_SPEED))')
p.write_text(s,encoding='utf-8')
p=R/'src/top.v';s=p.read_text(encoding='utf-8')
s=s.replace('.NATIVE_4BIT(1),', '.NATIVE_4BIT(1),.NATIVE_HIGH_SPEED(1),',1);p.write_text(s,encoding='utf-8')
s=(R/'sim/tb_sd_native_integrated.v').read_text(encoding='utf-8')
s=s.replace('tb_sd_native_integrated','tb_sd_highspeed_player')
s=s.replace('.NATIVE_4BIT(1),', '.NATIVE_4BIT(1),.NATIVE_HIGH_SPEED(1),',1)
s=s.replace('#(.IMAGE_MODE(1)) card', '#(.IMAGE_MODE(1),.DOUT_DELAY(14)) card')
s=s.replace(".ccs(1'b1),.fault(4'd0),", ".ccs(1'b1),.fault(4'd0),.hs_mode(4'd1),")
s=s.replace('formal native profile without force/', 'formal CMD6/50MHz with14ns delayed card, no force/')
(R/'sim/tb_sd_highspeed_player.v').write_text(s,encoding='utf-8')
p=R/'scripts/run_tests.ps1';s=p.read_text(encoding='utf-8')
s=s.replace("'tb_sd_native_integrated')", "'tb_sd_native_integrated','tb_sd_highspeed','tb_sd_highspeed_player')")
p.write_text(s,encoding='utf-8')
print('Installed automatic CMD6 SDR50 negotiation and two tests; unsupported cards stay native25')
