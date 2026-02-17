//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2022.2 (win64) Build 3671981 Fri Oct 14 05:00:03 MDT 2022
//Date        : Wed Dec 17 23:51:54 2025
//Host        : Junyoung running 64-bit major release  (build 9200)
//Command     : generate_target bit_reverse_top.bd
//Design      : bit_reverse_top
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* CORE_GENERATION_INFO = "bit_reverse_top,IP_Integrator,{x_ipVendor=xilinx.com,x_ipLibrary=BlockDiagram,x_ipName=bit_reverse_top,x_ipVersion=1.00.a,x_ipLanguage=VERILOG,numBlks=4,numReposBlks=4,numNonXlnxBlks=0,numHierBlks=0,maxHierDepth=0,numSysgenBlks=0,numHlsBlks=0,numHdlrefBlks=2,numPkgbdBlks=0,bdsource=USER,synth_mode=OOC_per_IP}" *) (* HW_HANDOFF = "bit_reverse_top.hwdef" *) 
module bit_reverse_top
   (clk,
    i_data,
    i_point,
    i_valid,
    o_data,
    o_valid,
    reset);
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 CLK.CLK CLK" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME CLK.CLK, ASSOCIATED_RESET reset, CLK_DOMAIN bit_reverse_top_clk_0, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, INSERT_VIP 0, PHASE 0.0" *) input clk;
  input [31:0]i_data;
  input [10:0]i_point;
  input i_valid;
  output [31:0]o_data;
  output o_valid;
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 RST.RESET RST" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME RST.RESET, INSERT_VIP 0, POLARITY ACTIVE_LOW" *) input reset;

  wire bit_reversal_0_o_bank_sel;
  wire [9:0]bit_reversal_0_o_raddr0;
  wire [9:0]bit_reversal_0_o_raddr1;
  wire bit_reversal_0_o_ren0;
  wire bit_reversal_0_o_ren1;
  wire bit_reversal_0_o_valid;
  wire [9:0]bit_reversal_0_o_waddr0;
  wire [9:0]bit_reversal_0_o_waddr1;
  wire [31:0]bit_reversal_0_o_wdin0;
  wire [31:0]bit_reversal_0_o_wdin1;
  wire bit_reversal_0_o_wen0;
  wire bit_reversal_0_o_wen1;
  wire bit_reversal_0_o_wwe0;
  wire bit_reversal_0_o_wwe1;
  wire [31:0]blk_mem_gen_0_doutb;
  wire [31:0]blk_mem_gen_1_doutb;
  wire clk_0_1;
  wire [31:0]i_data_0_1;
  wire [10:0]i_point_0_1;
  wire i_valid_0_1;
  wire [31:0]mux_0_o_data;
  wire reset_0_1;

  assign clk_0_1 = clk;
  assign i_data_0_1 = i_data[31:0];
  assign i_point_0_1 = i_point[10:0];
  assign i_valid_0_1 = i_valid;
  assign o_data[31:0] = mux_0_o_data;
  assign o_valid = bit_reversal_0_o_valid;
  assign reset_0_1 = reset;
  bit_reverse_top_bit_reversal_0_0 bit_reversal_0
       (.clk(clk_0_1),
        .i_data(i_data_0_1),
        .i_point(i_point_0_1),
        .i_valid(i_valid_0_1),
        .o_bank_sel(bit_reversal_0_o_bank_sel),
        .o_raddr0(bit_reversal_0_o_raddr0),
        .o_raddr1(bit_reversal_0_o_raddr1),
        .o_ren0(bit_reversal_0_o_ren0),
        .o_ren1(bit_reversal_0_o_ren1),
        .o_valid(bit_reversal_0_o_valid),
        .o_waddr0(bit_reversal_0_o_waddr0),
        .o_waddr1(bit_reversal_0_o_waddr1),
        .o_wdin0(bit_reversal_0_o_wdin0),
        .o_wdin1(bit_reversal_0_o_wdin1),
        .o_wen0(bit_reversal_0_o_wen0),
        .o_wen1(bit_reversal_0_o_wen1),
        .o_wwe0(bit_reversal_0_o_wwe0),
        .o_wwe1(bit_reversal_0_o_wwe1),
        .reset(reset_0_1));
  bit_reverse_top_blk_mem_gen_0_0 blk_mem_gen_0
       (.addra(bit_reversal_0_o_waddr0),
        .addrb(bit_reversal_0_o_raddr0),
        .clka(clk_0_1),
        .clkb(clk_0_1),
        .dina(bit_reversal_0_o_wdin0),
        .doutb(blk_mem_gen_0_doutb),
        .ena(bit_reversal_0_o_wen0),
        .enb(bit_reversal_0_o_ren0),
        .wea(bit_reversal_0_o_wwe0));
  bit_reverse_top_blk_mem_gen_0_1 blk_mem_gen_1
       (.addra(bit_reversal_0_o_waddr1),
        .addrb(bit_reversal_0_o_raddr1),
        .clka(clk_0_1),
        .clkb(clk_0_1),
        .dina(bit_reversal_0_o_wdin1),
        .doutb(blk_mem_gen_1_doutb),
        .ena(bit_reversal_0_o_wen1),
        .enb(bit_reversal_0_o_ren1),
        .wea(bit_reversal_0_o_wwe1));
  bit_reverse_top_mux_0_0 mux_0
       (.i_bank_sel(bit_reversal_0_o_bank_sel),
        .i_data0(blk_mem_gen_0_doutb),
        .i_data1(blk_mem_gen_1_doutb),
        .o_data(mux_0_o_data));
endmodule
