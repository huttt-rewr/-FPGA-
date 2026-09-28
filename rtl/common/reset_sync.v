module reset_sync(input clk, input arst, output rst);
    (* async_reg = "true" *) reg [2:0] sync_ff;
    always @(posedge clk or posedge arst)
        if (arst) sync_ff <= 3'b111;
        else sync_ff <= {sync_ff[1:0],1'b0};
    assign rst = sync_ff[2];
endmodule
