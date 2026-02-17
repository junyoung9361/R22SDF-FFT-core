`timescale 1ns / 1ps
module fft_top 
#(
    // FFT parameter
    parameter integer DWIDTH         = 32,
    parameter integer FIFO_DEPTH     = 512,
    parameter integer FIFO_DEPTH_LOG = 9,
    parameter integer ROM_DEPTH      = 512,
    parameter integer ROM_DEPTH_LOG  = 9,
    parameter ROM1_INIT_FILE = "twiddle_ROM_1.hex",
    parameter ROM2_INIT_FILE = "twiddle_ROM_2.hex",
    parameter ROM3_INIT_FILE = "twiddle_ROM_3.hex",
    parameter ROM4_INIT_FILE = "twiddle_ROM_4.hex",

    // AXI parameter
    parameter integer C_S00_AXI_DATA_WIDTH = 32,
    parameter integer C_S00_AXI_ADDR_WIDTH = 4
)
(
    // Global Clock & Reset
    input wire  aclk,
    input wire  aresetn, 

    // AXI4-Lite Slave Interface (Control)
    input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
    input wire [2 : 0] s00_axi_awprot,
    input wire  s00_axi_awvalid,
    output wire s00_axi_awready,
    input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
    input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
    input wire  s00_axi_wvalid,
    output wire s00_axi_wready,
    output wire [1 : 0] s00_axi_bresp,
    output wire s00_axi_bvalid,
    input wire  s00_axi_bready,
    input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
    input wire [2 : 0] s00_axi_arprot,
    input wire  s00_axi_arvalid,
    output wire s00_axi_arready,
    output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
    output wire [1 : 0] s00_axi_rresp,
    output wire s00_axi_rvalid,
    input wire  s00_axi_rready,

    // AXI4-Stream Slave Interface (Input: DMA -> FFT)
    input  wire [DWIDTH-1:0] s_axis_tdata,
    input  wire              s_axis_tvalid,
    output wire              s_axis_tready,
    input  wire              s_axis_tlast, 

    // AXI4-Stream Master Interface (Output: FFT -> DMA)
    output wire [DWIDTH-1:0] m_axis_tdata,
    output wire              m_axis_tvalid,
    input  wire              m_axis_tready,
    output wire              m_axis_tlast  
);

    // Internal Signals
    wire [31:0] w_slv_reg0; 
    wire [10:0] w_fft_point_cfg;
    wire        w_fft_reset;
    wire        w_fft_reverse;
    wire        w_fft_start;
    wire  [9:0] w_fft_burst;

    assign w_fft_reset     = ~aresetn;
    assign w_fft_point_cfg = w_slv_reg0[10:0];
    assign w_fft_inverse   = w_slv_reg0[11];
    assign w_fft_start     = w_slv_reg0[12];
    assign w_fft_burst     = w_slv_reg0[22:13];


    // AXI4-Lite Slave Module Instantiation
    myip_v1_0_S00_AXI # ( 
        .C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
    ) u_axi_lite_ctrl (
        .o_fft_data    (w_slv_reg0),    

        .S_AXI_ACLK    (aclk),
        .S_AXI_ARESETN (aresetn),
        .S_AXI_AWADDR  (s00_axi_awaddr),
        .S_AXI_AWPROT  (s00_axi_awprot),
        .S_AXI_AWVALID (s00_axi_awvalid),
        .S_AXI_AWREADY (s00_axi_awready),
        .S_AXI_WDATA   (s00_axi_wdata),
        .S_AXI_WSTRB   (s00_axi_wstrb),
        .S_AXI_WVALID  (s00_axi_wvalid),
        .S_AXI_WREADY  (s00_axi_wready),
        .S_AXI_BRESP   (s00_axi_bresp),
        .S_AXI_BVALID  (s00_axi_bvalid),
        .S_AXI_BREADY  (s00_axi_bready),
        .S_AXI_ARADDR  (s00_axi_araddr),
        .S_AXI_ARPROT  (s00_axi_arprot),
        .S_AXI_ARVALID (s00_axi_arvalid),
        .S_AXI_ARREADY (s00_axi_arready),
        .S_AXI_RDATA   (s00_axi_rdata),
        .S_AXI_RRESP   (s00_axi_rresp),
        .S_AXI_RVALID  (s00_axi_rvalid),
        .S_AXI_RREADY  (s00_axi_rready)
    );

    // FFT core Module Instantiation
    fft_core #(
        .DWIDTH         (DWIDTH),
        .FIFO_DEPTH     (FIFO_DEPTH),
        .FIFO_DEPTH_LOG (FIFO_DEPTH_LOG),
        .ROM_DEPTH      (ROM_DEPTH),
        .ROM_DEPTH_LOG  (ROM_DEPTH_LOG),
        .ROM1_INIT_FILE (ROM1_INIT_FILE),
        .ROM2_INIT_FILE (ROM2_INIT_FILE),
        .ROM3_INIT_FILE (ROM3_INIT_FILE),
        .ROM4_INIT_FILE (ROM4_INIT_FILE)
    ) u_fft_core_top (
        .clk           (aclk),
        .reset         (w_fft_reset),
        
        // AXI4-Lite Slave
        .i_inverse     (w_fft_inverse),
        .i_point       (w_fft_point_cfg),
        .i_start       (w_fft_start),
        .i_burst       (w_fft_burst),

        // Slave Stream
        .s_axis_tdata  (s_axis_tdata),
        .s_axis_tvalid (s_axis_tvalid),
        .s_axis_tready (s_axis_tready),
        .s_axis_tlast  (s_axis_tlast),
        
        // Master Stream
        .m_axis_tdata  (m_axis_tdata),
        .m_axis_tvalid (m_axis_tvalid),
        .m_axis_tready (m_axis_tready),
        .m_axis_tlast  (m_axis_tlast)
    );

endmodule