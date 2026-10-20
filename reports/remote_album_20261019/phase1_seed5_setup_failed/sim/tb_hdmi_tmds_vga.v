`timescale 1ns/1ps
module tb_hdmi_tmds_vga;
    reg clk=0,rst=1,source_rst=1;
    always #5 clk=~clk;
    wire hs,vs,de;
    adaptive_raster raster(clk,source_rst,1'b0,hs,vs,de);
    // Model an arbitrary overlay latency; no dependence on reset phase.
    reg [26:0] pipe[0:22];
    integer p,n=0,errors=0,pixels=0,frames=0,checks=0;
    wire in_hs=pipe[22][26],in_vs=pipe[22][25],in_de=pipe[22][24];
    wire [23:0] in_rgb=pipe[22][23:0];
    wire [9:0] c0,c1,c2,cc;
    hdmi_tmds_vga dut(clk,rst,in_vs,in_de,in_rgb,c0,c1,c2,cc);
    reg [9:0] e0,e1,e2;
    integer rd0=0,rd1=0,rd2=0;
    reg [23:0] pattern;
    always @(posedge clk)begin
        n<=n+1;
        pattern={raster.v[7:0],raster.h[7:0],raster.h[7:0]^raster.v[7:0]};
        pipe[0]<={hs,vs,de,pattern};
        for(p=1;p<23;p=p+1)pipe[p]<=pipe[p-1];
    end
    // Independent algorithmic oracle: calculate disparity by COUNTING the
    // emitted ten bits, not the DUT's arithmetic recurrence.
    task reference;
        input active;input [1:0] ctl;input [7:0] d;
        inout integer rd;output [9:0] encoded;
        integer j,ones,qones,delta;reg xn;reg [8:0] q;
        begin
            if(!active)begin
                case(ctl)
                    0:encoded=10'h354;1:encoded=10'h0ab;
                    2:encoded=10'h154;3:encoded=10'h2ab;
                endcase
                rd=0;
            end else begin
                ones=0;for(j=0;j<8;j=j+1)ones=ones+d[j];
                xn=ones>4 || (ones==4 && d[0]==0);
                q[0]=d[0];
                for(j=1;j<8;j=j+1)begin
                    if(xn)q[j]=~(q[j-1]^d[j]);else q[j]=q[j-1]^d[j];
                end
                q[8]=!xn;qones=0;
                for(j=0;j<8;j=j+1)qones=qones+q[j];
                if(rd==0 || qones==4)begin
                    encoded[9]=!q[8];encoded[8]=q[8];
                    encoded[7:0]=q[8]?q[7:0]:~q[7:0];
                end else begin
                    encoded[9]=(rd>0 && qones>4)||(rd<0 && qones<4);
                    encoded[8]=q[8];
                    encoded[7:0]=encoded[9]?~q[7:0]:q[7:0];
                end
                delta=-10;for(j=0;j<10;j=j+1)delta=delta+2*encoded[j];
                rd=rd+delta;
                if(rd>8 || rd< -8)begin errors=errors+1;$display("FAILED DC bound %0d",rd);end
            end
        end
    endtask
    always @(posedge clk)begin
        if(rst)begin rd0=0;rd1=0;rd2=0;end
        else begin
            if(dut.locked && (dut.de_int!==in_de || dut.hs!==in_hs || (dut.v_now>=2)!==in_vs || dut.v_now>=525))begin
                errors=errors+1;if(errors<5)$display("FAILED DE phase h=%0d v=%0d",dut.h_now,dut.v_now);
            end
            if(dut.frame_start)frames=frames+1;
            if(dut.pixel_de)pixels=pixels+1;
            reference(dut.pixel_de,{!in_vs,(dut.locked?!in_hs:!dut.hs)},in_rgb[7:0],rd0,e0);
            reference(dut.pixel_de,0,in_rgb[15:8],rd1,e1);
            reference(dut.pixel_de,0,in_rgb[23:16],rd2,e2);
            #1;
            checks=checks+1;
            if(c0!==e0 || c1!==e1 || c2!==e2 || cc!==10'h01f)begin
                errors=errors+1;if(errors<5)$display("FAILED TMDS sample %0d actual=%h/%h/%h expected=%h/%h/%h lock=%b",checks,c0,c1,c2,e0,e1,e2,dut.locked);
            end
        end
    end
    initial begin
        for(p=0;p<23;p=p+1)pipe[p]={1'b0,1'b1,1'b0,24'd0};
        repeat(5)@(negedge clk);source_rst=0;
        // Release the transmitter in the middle of a frame, NOT at h=0.
        repeat(2000)@(negedge clk);rst=0;
        wait(frames==1);wait(in_de);wait(!in_de);
        // Reset/relock in the active frame; no stale counter phase survives.
        @(negedge clk);rst=1;repeat(7)@(negedge clk);rst=0;
        wait(frames==4);repeat(10)@(negedge clk);
        if(pixels<614400 || checks<840000)begin errors=errors+1;$display("FAILED raster coverage");end
        if(errors==0)$display("ALL PASS tb_hdmi_tmds_vga: full frames, delayed overlays, mid-frame reset/relock, RGB/DC/control codes, clock 01f");
        else $display("FAILED tb_hdmi_tmds_vga errors=%0d",errors);
        $finish;
    end
    initial begin #20000000;$display("FAILED tb_hdmi_tmds_vga watchdog");$finish;end
endmodule
