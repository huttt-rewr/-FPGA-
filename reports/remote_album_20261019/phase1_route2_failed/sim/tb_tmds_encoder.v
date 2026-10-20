`timescale 1ns/1ps
// Exhaustive input-byte pairs + long constant patterns, all four controls.
module tb_tmds_encoder;
    reg clk=0,rst=1,de=0;reg [1:0] ctl=0;reg [7:0] data=0;
    wire [9:0] symbol;
    tmds_encoder dut(clk,rst,de,ctl,data,symbol);
    always #5 clk=~clk;
    integer a,b,j,k,ones,qn,rd=0,delta,errors=0;
    reg [8:0] q;reg [9:0] expected;reg invert;
    task step;
        input active;input [7:0] value;input [1:0] control;
        begin
            @(negedge clk);de=active;data=value;ctl=control;
            if(!active)begin
                case(control)
                    0:expected=10'h354;1:expected=10'hab;
                    2:expected=10'h154;3:expected=10'h2ab;
                endcase
                rd=0;
            end else begin
                ones=0;for(j=0;j<8;j=j+1)ones=ones+value[j];
                invert=ones>4 || (ones==4 && !value[0]);
                q[0]=value[0];for(j=1;j<8;j=j+1)q[j]=invert?~(q[j-1]^value[j]):(q[j-1]^value[j]);
                q[8]=!invert;qn=0;for(j=0;j<8;j=j+1)qn=qn+q[j];
                if(rd==0 || qn==4)invert=!q[8];
                else invert=(rd>0 && qn>4)||(rd<0 && qn<4);
                expected={invert,q[8],(invert?~q[7:0]:q[7:0])};
                delta=-10;for(j=0;j<10;j=j+1)delta=delta+2*expected[j];
                rd=rd+delta;
            end
            @(posedge clk);#1;
            if(symbol!==expected || $signed(dut.disparity)!=rd || rd>8 || rd< -8)begin
                errors=errors+1;if(errors<5)$display("FAILED encoder data=%h actual=%h expected=%h rd=%0d",value,symbol,expected,rd);
            end
        end
    endtask
    initial begin
        repeat(3)@(negedge clk);rst=0;
        for(a=0;a<256;a=a+1)begin
            step(0,0,a%4);
            for(b=0;b<256;b=b+1)begin step(1,a,0);step(1,b,0);end
            for(k=0;k<64;k=k+1)step(1,a,0);
        end
        for(a=0;a<4;a=a+1)step(0,0,a);
        @(negedge clk);rst=1;#1;
        if(symbol!==10'h354 || dut.disparity!==0)errors=errors+1;
        if(errors==0)$display("ALL PASS tb_tmds_encoder: 65536 byte pairs, 256 constant runs, all controls, DC bound and async reset");
        else $display("FAILED tb_tmds_encoder errors=%0d",errors);
        $finish;
    end
endmodule
