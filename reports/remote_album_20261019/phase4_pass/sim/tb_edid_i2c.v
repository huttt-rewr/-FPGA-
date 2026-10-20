`timescale 1ns/1ps
module tb_edid_i2c;
    reg clk=0,rst=1,start=0;
    always #5 clk=~clk;
    tri1 scl,sda;
    reg card_low=0;
    assign sda=card_low?1'b0:1'bz;
    wire valid,busy,done,error;
    wire [7:0] data;
    edid_i2c #(.QUARTER_CYCLES(8)) dut(clk,rst,start,scl,sda,valid,data,busy,done,error);
    // The real parser timeout is 16M cycles. Here bytes take ~300 cycles;
    // keep the timeout longer than a byte and shorten only total test time.
    wire actual_done,actual_good,actual_800,actual_fallback;
    edid_display_mode #(.TIMEOUT(2000)) negotiated(clk,rst,start,valid,data,
        actual_done,actual_good,actual_800,actual_fallback);
    reg [7:0] block[0:127];
    integer i,j,sum,scenario=0,errors=0,received=0,starts=0,stops=0;
    reg [7:0] address;
    always @(posedge clk)if(rst)received=0;else if(valid)begin
        if(received>=128 || data!==block[received])begin
            errors=errors+1;if(errors<5)$display("FAILED EDID stream idx=%0d data=%h",received,data);
        end
        received=received+1;
    end
    always @(negedge sda)if(scl===1 && !rst)starts=starts+1;
    always @(posedge sda)if(scl===1 && !rst)stops=stops+1;
    task receive_byte;
        output [7:0] value;
        integer k;
        begin
            for(k=7;k>=0;k=k-1)begin @(posedge scl);#1;value[k]=sda;end
        end
    endtask
    task acknowledge;
        input reject;
        begin
            @(negedge scl);card_low=!reject;
            @(posedge scl);@(negedge scl);card_low=0;
        end
    endtask
    task send_byte;
        input [7:0] value;input last;
        integer k;
        begin
            for(k=7;k>=0;k=k-1)begin
                card_low=!value[k];@(posedge scl);@(negedge scl);
            end
            card_low=0;
            @(posedge scl);#1;
            if(sda!==last)begin errors=errors+1;$display("FAILED master ACK last=%b SDA=%b",last,sda);end
            @(negedge scl);
        end
    endtask
    task card;
        integer k;
        begin : card_transaction
            @(negedge sda);if(scl!==1)begin errors=errors+1;$display("FAILED start");end
            receive_byte(address);
            if(address!==8'ha0)begin errors=errors+1;$display("FAILED A0 %h",address);end
            acknowledge(scenario==4);
            if(scenario==4)disable card_transaction;
            receive_byte(address);
            if(address!==0)begin errors=errors+1;$display("FAILED offset %h",address);end
            acknowledge(scenario==5);
            if(scenario==5)disable card_transaction;
            @(negedge sda);
            if(scl!==1)begin errors=errors+1;$display("FAILED repeated START");end
            receive_byte(address);
            if(address!==8'ha1)begin errors=errors+1;$display("FAILED A1 %h",address);end
            acknowledge(scenario==6);
            if(scenario==6)disable card_transaction;
            for(k=0;k<128;k=k+1)send_byte(block[k],k==127);
        end
    endtask
    task trigger;
        begin @(negedge clk);start=1;@(negedge clk);start=0;end
    endtask
    task make_block;
        begin
            for(i=0;i<128;i=i+1)block[i]=i*17;
            block[0]=0;block[7]=0;
            for(i=1;i<7;i=i+1)block[i]=255;
            block[18]=1;block[19]=4;block[20]=128;
            block[35]=(scenario==1)?0:1;
            // Clear alternate capability descriptors so case 1 tests fallback.
            for(i=38;i<126;i=i+1)block[i]=0;
            if(scenario==3)block[0]=1;
            sum=0;for(i=0;i<127;i=i+1)sum=sum+block[i];block[127]=-sum;
            if(scenario==2)block[127]=block[127]^1;
        end
    endtask
    initial begin
        repeat(4)@(negedge clk);rst=0;
        for(scenario=0;scenario<9;scenario=scenario+1)begin
            rst=1;card_low=0;repeat(4)@(negedge clk);rst=0;
            received=0;starts=0;stops=0;make_block;
            if(scenario<7)begin
                fork card();trigger();join
            end else if(scenario==7)begin
                // A missing display NACKs the address; no stream is emitted.
                trigger;
            end else begin
                // Reset midway through a command must release both lines.
                trigger;repeat(70)@(negedge clk);rst=1;#1;
                if(scl!==1 || sda!==1 || busy)begin errors=errors+1;$display("FAILED reset bus release");end
                repeat(4)@(negedge clk);rst=0;
                scenario=0;received=0;starts=0;stops=0;make_block;
                fork card();trigger();join
                scenario=8;
            end
            wait(done);repeat(3)@(negedge clk);
            if(busy || scl!==1 || sda!==1)begin errors=errors+1;$display("FAILED idle bus");end
            if(scenario>=4 && scenario<=7)begin
                if(!error || received!=0)begin errors=errors+1;$display("FAILED NACK case %0d",scenario);end
                repeat(2100)@(negedge clk);
                if(!actual_done || actual_good || actual_800 || !actual_fallback)begin
                    errors=errors+1;$display("FAILED missing display fallback");
                end
            end else begin
                if(error || received!=128 || starts!=2 || stops!=1 || !actual_done ||
                   actual_good!==(scenario!=2 && scenario!=3) ||
                   actual_800!==(scenario==0 || scenario==8) ||
                   actual_fallback!==(scenario!=0 && scenario!=8))begin
                    errors=errors+1;$display("FAILED EDID scenario %0d bytes=%0d starts=%0d stops=%0d done/good/800=%b%b%b",
                      scenario,received,starts,stops,actual_done,actual_good,actual_800);
                end
            end
        end
        if(errors==0)$display("ALL PASS tb_edid_i2c: A0/offset/repeated START/A1,128 bytes, ACK127/NACK1, checksum/header, unsupported display, three NACK stages, missing display, reset/retry");
        else $display("FAILED tb_edid_i2c errors=%0d",errors);
        $finish;
    end
    initial begin #10000000;$display("FAILED tb_edid_i2c watchdog state=%0d case=%0d",dut.state,scenario);$finish;end
endmodule
