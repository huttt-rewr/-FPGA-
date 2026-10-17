from pathlib import Path
R=Path(__file__).resolve().parents[2]
p=R/'src/modules/control/picture_controls.v';s=p.read_text(encoding='utf-8')
a=s.index(' reg [CW-1:0] count[0:2];');b=s.index(' // Optional board menu.',a)
s=s[:a]+''' // Each key has a separate counter rather than an indexed array. TD must
 // not build shared RAM/mux control for three independent debounce channels.
 always @(posedge clk)begin
  if(rst)begin sync0<=0;sync1<=0;end
  else begin sync0<={key3_n,key2_n,key1_n};sync1<=sync0;end
 end
 genvar k;
 generate for(k=0;k<3;k=k+1)begin:key_debounce
  reg [CW-1:0] count;
  reg terminal;
  always @(posedge clk)begin
   if(rst)begin count<=0;terminal<=0;stable[k]<=0;armed[k]<=0;pulse[k]<=0;end
   else begin
    pulse[k]<=0;
    // Predict the count used next cycle, keeping the wide comparator off
    // the pulse/stable/counter-reset path. The input-match gate prevents a
    // stale terminal bit from accepting a new bounce immediately.
    terminal<=(sync1[k]!=stable[k]) && (count==DEBOUNCE_CYCLES-2);
    if(sync1[k]==stable[k])count<=0;
    else if(DEBOUNCE_CYCLES<=1 || terminal)begin
     stable[k]<=sync1[k];count<=0;
     if(sync1[k])armed[k]<=1;
     else if(armed[k])begin pulse[k]<=1;armed[k]<=0;end
    end else count<=count+1'b1;
   end
  end
 end endgenerate
'''+s[b:]
p.write_text(s,encoding='utf-8')
print('Generated independent KEY counters and one-cycle-ahead terminal flags; debounce duration preserved')
