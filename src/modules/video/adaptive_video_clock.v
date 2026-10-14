// Additional fixed outputs, not undocumented dynamic PLL programming.
// Derived from the existing 1GHz NOCOMP video PLL configuration.
// Select changes only during boot with ALL consumers held in reset for 4096
// reference pixel cycles. Dedicated global switches select related 1x/5x pairs.
module adaptive_video_clock(input refclk,input reset,input mode_800,
 output locked,output boot_clk,output pixel_clk,output serial_clk);
 wire c25,c125,c40,c200;
 EG_PHY_PLL #(.DPHASE_SOURCE("DISABLE"),.DYNCFG("DISABLE"),.FIN("50.000000"),
  .FEEDBK_MODE("NOCOMP"),.FEEDBK_PATH("VCO_PHASE_0"),.STDBY_ENABLE("DISABLE"),
  .PLLRST_ENA("ENABLE"),.SYNC_ENABLE("DISABLE"),.GMC_GAIN(2),.ICP_CURRENT(9),
  .KVCO(2),.LPF_CAPACITOR(1),.LPF_RESISTOR(8),.REFCLK_DIV(1),.FBCLK_DIV(20),
  .CLKC0_ENABLE("ENABLE"),.CLKC0_DIV(40),.CLKC0_CPHASE(39),.CLKC0_FPHASE(0),
  .CLKC1_ENABLE("ENABLE"),.CLKC1_DIV(8),.CLKC1_CPHASE(7),.CLKC1_FPHASE(0),
  .CLKC2_ENABLE("ENABLE"),.CLKC2_DIV(25),.CLKC2_CPHASE(24),.CLKC2_FPHASE(0),
  .CLKC3_ENABLE("ENABLE"),.CLKC3_DIV(5),.CLKC3_CPHASE(4),.CLKC3_FPHASE(0)) pll_inst(
  .refclk(refclk),.reset(reset),.stdby(1'b0),.extlock(locked),.load_reg(1'b0),
  .psclk(1'b0),.psdown(1'b0),.psstep(1'b0),.psclksel(3'b0),.psdone(),
  .dclk(1'b0),.dcs(1'b0),.dwe(1'b0),.di(8'b0),.daddr(6'b0),.do(),.fbclk(),
  .clkc({open,c200,c40,c125,c25}));
 EG_LOGIC_BUFG boot_buffer(.i(c25),.o(boot_clk));
 EG_LOGIC_BUFGMUX pixel_switch(.i0(c25),.i1(c40),.s(mode_800),.o(pixel_clk));
 EG_LOGIC_BUFGMUX serial_switch(.i0(c125),.i1(c200),.s(mode_800),.o(serial_clk));
endmodule
