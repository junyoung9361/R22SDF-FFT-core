module last_stage
#(
    parameter DWIDTH         = 32,
    parameter FIFO_DEPTH     = 512,
    parameter FIFO_DEPTH_LOG = 9
)
(
    input                   clk,
    input                   reset,
    input                   i_half_sel,
    input  [DWIDTH-1:0]     i_half_data,
    input  [DWIDTH-1:0]     i_data,
    input                   i_valid,
    output [DWIDTH-1:0]     o_data,
    output                  o_valid
);
//////////////////////////BF1 Signal//////////////////////////
    wire [DWIDTH-1:0] w_bf1_s_data;
    wire              w_bf1_s_valid;
    wire [DWIDTH-1:0] w_bf1_m_data;
    wire              w_bf1_m_valid;
    
//////////////////////////BF1 OUTPUT Signal//////////////////////////
    wire [DWIDTH-1:0] w_bf2_s_data;
    wire              w_bf2_s_valid;
    wire [DWIDTH-1:0] w_bf2_m_data;
    wire              w_bf2_m_valid;

//////////////////////////BF1 FIFO Signal//////////////////////////
    wire [DWIDTH-1:0] w_bf1_fifo_s_data;
    wire              w_bf1_fifo_s_valid;
    wire              w_bf1_fifo_s_ready;
    wire [DWIDTH-1:0] w_bf1_fifo_m_data;
    wire              w_bf1_fifo_m_valid;
    wire              w_bf1_fifo_m_ready;

//////////////////////////BF2 FIFO Signal//////////////////////////
    wire [DWIDTH-1:0] w_bf2_fifo_s_data;
    wire              w_bf2_fifo_s_valid;
    wire              w_bf2_fifo_s_ready;
    wire [DWIDTH-1:0] w_bf2_fifo_m_data;
    wire              w_bf2_fifo_m_valid;
    wire              w_bf2_fifo_m_ready;

    assign w_bf1_s_valid = (i_half_sel) ? 1'b0 : i_valid;
    assign w_bf1_s_data  = i_data;
    
    bf2i #(
        .DWIDTH    (DWIDTH),
        .DEPTH_LOG (FIFO_DEPTH_LOG)
    ) u_bf2i (
        .clk         (clk),
        .reset       (reset),
        .i_top_data  (w_bf1_fifo_m_data),
        .i_top_valid (w_bf1_fifo_m_valid),
        .i_bot_data  (w_bf1_s_data),
        .i_bot_valid (w_bf1_s_valid),
        .o_top_ready (w_bf1_fifo_m_ready),
        .o_top_data  (w_bf1_fifo_s_data),
        .o_top_valid (w_bf1_fifo_s_valid),
        .o_bot_data  (w_bf1_m_data),
        .o_bot_valid (w_bf1_m_valid)
    );

    assign w_bf2_s_valid = (i_half_sel) ? i_valid : w_bf1_m_valid;
    assign w_bf2_s_data = w_bf1_m_data;

    bf2ii_last #(
        .DWIDTH    (DWIDTH),
        .DEPTH_LOG (FIFO_DEPTH_LOG-1)
    ) u_bf2ii_last (
        .clk         (clk),
        .reset       (reset),
        .i_half_data (i_half_data),
        .i_half_sel  (i_half_sel),
        .i_top_data  (w_bf2_fifo_m_data),
        .i_top_valid (w_bf2_fifo_m_valid),
        .i_bot_data  (w_bf2_s_data),
        .i_bot_valid (w_bf2_s_valid),
        .o_top_ready (w_bf2_fifo_m_ready),
        .o_top_data  (w_bf2_fifo_s_data),
        .o_top_valid (w_bf2_fifo_s_valid),
        .o_bot_data  (o_data),
        .o_bot_valid (o_valid)
    );

    fifo #(
        .DWIDTH    (DWIDTH),
        .DEPTH     (FIFO_DEPTH+1),
        .DEPTH_LOG (FIFO_DEPTH_LOG+1)
    ) u_bf2i_fifo (
        .clk     (clk),
        .reset   (reset),
        .i_valid (w_bf1_fifo_s_valid),
        .o_ready (w_bf1_fifo_s_ready), 
        .i_data  (w_bf1_fifo_s_data), 
        .o_valid (w_bf1_fifo_m_valid), 
        .i_ready (w_bf1_fifo_m_ready), 
        .o_data  (w_bf1_fifo_m_data)   
    );

    fifo #(
        .DWIDTH    (DWIDTH),
        .DEPTH     (FIFO_DEPTH/2+1),
        .DEPTH_LOG (FIFO_DEPTH_LOG)
    ) u_bf2ii_fifo (
        .clk     (clk),
        .reset   (reset),
        .i_valid (w_bf2_fifo_s_valid), 
        .o_ready (w_bf2_fifo_s_ready), 
        .i_data  (w_bf2_fifo_s_data),  
        .o_valid (w_bf2_fifo_m_valid), 
        .i_ready (w_bf2_fifo_m_ready), 
        .o_data  (w_bf2_fifo_m_data)   
    );

endmodule