module testbench();
//----------------------------------------------------------
// parameters
//----------------------------------------------------------
parameter DWIDTH         = 32                  ;
parameter FIFO_DEPTH     = 512                 ;
parameter FIFO_DEPTH_LOG = 9                   ;
parameter ROM_DEPTH      = 512                 ;
parameter ROM_DEPTH_LOG  = 9                   ;
parameter ROM1_INIT_FILE = "twiddle_ROM_1.hex" ;
parameter ROM2_INIT_FILE = "twiddle_ROM_2.hex" ;
parameter ROM3_INIT_FILE = "twiddle_ROM_3.hex" ;
parameter ROM4_INIT_FILE = "twiddle_ROM_4.hex" ;

//----------------------------------------------------------
// wire
//----------------------------------------------------------
wire              aclk            ;  // AXI clock
wire              areset_n        ;
wire              w_inverse       ;
wire [10:0]       w_point         ;
wire [DWIDTH-1:0] w_s_axis_tdata  ;
wire              w_s_axis_tvalid ;
wire              w_s_axis_tready ;
wire              w_s_axis_tlast  ;
wire [DWIDTH-1:0] w_m_axis_tdata  ;
wire              w_m_axis_tvalid ;
wire              w_m_axis_tready ;
wire              w_m_axis_tlast  ;

//----------------------------------------------------------
// clock, reset module
//----------------------------------------------------------
clk_rst u_clk_rst (
    .aclk       (aclk),
    .areset_n   (areset_n)
);

//----------------------------------------------------------
// test case stimulus module
//----------------------------------------------------------
test_case u_test_case (
    .aclk           ( aclk            ), // use aclk only
    .areset_n       ( areset_n        ), // use aclk only
    .o_inverse      ( w_inverse       ),
    .o_point        ( w_point         ),
    .o_axis_tdata   ( w_s_axis_tdata  ),
    .o_axis_tvalid  ( w_s_axis_tvalid ),
    .i_axis_tready  ( w_s_axis_tready ),
    .o_axis_tlast   ( w_s_axis_tlast  ),
    .i_axis_tdata   ( w_m_axis_tdata  ),
    .i_axis_tvalid  ( w_m_axis_tvalid ),
    .o_axis_tready  ( w_m_axis_tready ),
    .i_axis_tlast   ( w_m_axis_tlast  )
);

//----------------------------------------------------------
// DUT instantiation
//----------------------------------------------------------
fft_core #(
    .DWIDTH(DWIDTH),
    .FIFO_DEPTH(FIFO_DEPTH),
    .ROM_DEPTH(ROM_DEPTH),
    .ROM1_INIT_FILE(ROM1_INIT_FILE),
    .ROM2_INIT_FILE(ROM2_INIT_FILE),
    .ROM3_INIT_FILE(ROM3_INIT_FILE),
    .ROM4_INIT_FILE(ROM4_INIT_FILE)
) u_fft_core (
    .clk            (aclk           ),
    .reset          (~areset_n      ), // active high
    .i_inverse      (w_inverse      ),
    .i_point        (w_point        ),
    .s_axis_tdata   (w_s_axis_tdata ),
    .s_axis_tvalid  (w_s_axis_tvalid),
    .s_axis_tready  (w_s_axis_tready),
    .s_axis_tlast   (w_s_axis_tlast ),
    .m_axis_tdata   (w_m_axis_tdata ),
    .m_axis_tvalid  (w_m_axis_tvalid),
    .m_axis_tready  (w_m_axis_tready),
    .m_axis_tlast   (w_m_axis_tlast )
);

endmodule