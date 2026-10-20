module cdc_encoded_probe(input sc,sr,dc,dr,input [69:0] data,output [69:0] result);
 cdc_snapshot #(.WIDTH(70),.ENCODE_HOLD(1)) snapshot(sc,sr,data,dc,dr,result);
endmodule
