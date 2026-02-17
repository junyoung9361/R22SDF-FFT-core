module fft_core
#(
    parameter DWIDTH         = 32,
    parameter FIFO_DEPTH     = 512,
    parameter FIFO_DEPTH_LOG = 9,
    parameter ROM_DEPTH      = 512,
    parameter ROM_DEPTH_LOG  = 9,
    parameter ROM1_INIT_FILE = "twiddle_ROM_1.hex",
    parameter ROM2_INIT_FILE = "twiddle_ROM_2.hex",
    parameter ROM3_INIT_FILE = "twiddle_ROM_3.hex",
    parameter ROM4_INIT_FILE = "twiddle_ROM_4.hex"
)
(
    input                  clk,
    input                  reset,

    input wire               i_inverse,
    input wire [10:0]        i_point,

    input wire [DWIDTH-1:0]  s_axis_tdata,
    input wire               s_axis_tvalid,
    output wire              s_axis_tready,
    input wire               s_axis_tlast,
    
    output wire [DWIDTH-1:0] m_axis_tdata,
    output wire              m_axis_tvalid,
    input wire               m_axis_tready,
    output wire              m_axis_tlast  
);
    localparam HWIDTH = DWIDTH / 2;

    wire [HWIDTH-1:0] w_s_axis_tdata_r;
    wire [HWIDTH-1:0] w_s_axis_tdata_i;
    wire [DWIDTH-1:0] w_fft_s_data;
    wire [HWIDTH-1:0] w_fft_s_data_r;
    wire [HWIDTH-1:0] w_fft_s_data_i;
    wire [DWIDTH-1:0] w_fft_m_data;
    wire [HWIDTH-1:0] w_fft_m_data_r;
    wire [HWIDTH-1:0] w_fft_m_data_i;

    wire [DWIDTH-1:0] w_s1_s_data;
    wire              w_s1_s_valid;
    wire [DWIDTH-1:0] w_s1_m_data;
    wire              w_s1_m_valid;
    wire              w_s1_sel   = i_point[10];
    wire [DWIDTH-1:0] w_s1_half_data;
    wire              w_s1_half  = i_point[9];

    wire [DWIDTH-1:0] w_s2_s_data;
    wire              w_s2_s_valid;
    wire [DWIDTH-1:0] w_s2_m_data;
    wire              w_s2_m_valid;
    wire              w_s2_sel   = i_point[8];
    wire [DWIDTH-1:0] w_s2_half_data;
    wire              w_s2_half  = i_point[7];

    wire [DWIDTH-1:0] w_s3_s_data;
    wire              w_s3_s_valid;
    wire [DWIDTH-1:0] w_s3_m_data;
    wire              w_s3_m_valid;
    wire              w_s3_sel   = i_point[6];
    wire [DWIDTH-1:0] w_s3_half_data;
    wire              w_s3_half  = i_point[5];

    wire [DWIDTH-1:0] w_s4_s_data;
    wire              w_s4_s_valid;
    wire [DWIDTH-1:0] w_s4_m_data;
    wire              w_s4_m_valid;
    wire              w_s4_sel   = i_point[4];
    wire [DWIDTH-1:0] w_s4_half_data;
    wire              w_s4_half  = i_point[3];

    wire [DWIDTH-1:0] w_ls_s_data;
    wire              w_ls_s_valid;
    wire [DWIDTH-1:0] w_ls_m_data;
    wire              w_ls_m_valid;
    wire              w_ls_sel   = i_point[2];
    wire [DWIDTH-1:0] w_ls_half_data;
    wire              w_ls_half  = i_point[1];
    wire [HWIDTH-1:0] w_ls_m_data_r;
    wire [HWIDTH-1:0] w_ls_m_data_i;

    wire [DWIDTH-1:0] w_br_m_data;
    wire              w_br_m_valid;    

    assign s_axis_tready    = m_axis_tready;
    assign w_s_axis_tdata_r = s_axis_tdata[DWIDTH-1:HWIDTH];
    assign w_s_axis_tdata_i = s_axis_tdata[HWIDTH-1:0];
    
    assign w_fft_s_data_r  = w_s_axis_tdata_r; 
    assign w_fft_s_data_i  = (i_inverse) ? (~w_s_axis_tdata_i + 1'b1) : w_s_axis_tdata_i;
    assign w_fft_s_data    = {w_fft_s_data_r, w_fft_s_data_i};


    assign w_s1_s_data    = (w_s1_sel) ? w_fft_s_data  : {DWIDTH{1'b0}};
    assign w_s1_half_data = (w_s1_half) ? w_fft_s_data : {DWIDTH{1'b0}};
    assign w_s1_s_valid   = (w_s1_sel || w_s1_half) ? s_axis_tvalid : 1'b0;

    stage #(
        .DWIDTH         (DWIDTH),
        .FIFO_DEPTH     (FIFO_DEPTH),
        .FIFO_DEPTH_LOG (FIFO_DEPTH_LOG),
        .ROM_DEPTH      (ROM_DEPTH),
        .ROM_DEPTH_LOG  (ROM_DEPTH_LOG),
        .ROM_INIT_FILE  (ROM1_INIT_FILE)
    ) u_stage1 (
        .clk         (clk),
        .reset       (reset),
        .i_half_data (w_s1_half_data),
        .i_half_sel  (w_s1_half),
        .i_data      (w_s1_s_data),
        .i_valid     (w_s1_s_valid),
        .o_data      (w_s1_m_data),
        .o_valid     (w_s1_m_valid)
    );

    assign w_s2_s_data    = (w_s2_sel) ? w_fft_s_data : w_s1_m_data;
    assign w_s2_half_data = (w_s2_half) ? w_fft_s_data : {DWIDTH{1'b0}};
    assign w_s2_s_valid   = (w_s2_sel || w_s2_half) ? s_axis_tvalid : w_s1_m_valid;

    stage #(
        .DWIDTH         (DWIDTH),
        .FIFO_DEPTH     (FIFO_DEPTH/4),
        .FIFO_DEPTH_LOG (FIFO_DEPTH_LOG-2),
        .ROM_DEPTH      (ROM_DEPTH/4),
        .ROM_DEPTH_LOG  (ROM_DEPTH_LOG-2),
        .ROM_INIT_FILE  (ROM2_INIT_FILE)
    ) u_stage2 (
        .clk         (clk),
        .reset       (reset),
        .i_half_data (w_s2_half_data),
        .i_half_sel  (w_s2_half),
        .i_data      (w_s2_s_data),
        .i_valid     (w_s2_s_valid),
        .o_data      (w_s2_m_data),
        .o_valid     (w_s2_m_valid)
    );

    assign w_s3_s_data    = (w_s3_sel) ? w_fft_s_data : w_s2_m_data;
    assign w_s3_half_data = (w_s3_half) ? w_fft_s_data : {DWIDTH{1'b0}};
    assign w_s3_s_valid   = (w_s3_sel || w_s3_half) ? s_axis_tvalid : w_s2_m_valid;

    stage #(
        .DWIDTH         (DWIDTH),
        .FIFO_DEPTH     (FIFO_DEPTH/16),
        .FIFO_DEPTH_LOG (FIFO_DEPTH_LOG-4),
        .ROM_DEPTH      (ROM_DEPTH/16),
        .ROM_DEPTH_LOG  (ROM_DEPTH_LOG-4),
        .ROM_INIT_FILE  (ROM3_INIT_FILE)
    ) u_stage3 (
        .clk         (clk),
        .reset       (reset),
        .i_half_data (w_s3_half_data),
        .i_half_sel  (w_s3_half),
        .i_data      (w_s3_s_data),
        .i_valid     (w_s3_s_valid),
        .o_data      (w_s3_m_data),
        .o_valid     (w_s3_m_valid)
    );

    assign w_s4_s_data    = (w_s4_sel) ? w_fft_s_data : w_s3_m_data;
    assign w_s4_half_data = (w_s4_half) ? w_fft_s_data : {DWIDTH{1'b0}};
    assign w_s4_s_valid   = (w_s4_sel || w_s4_half) ? s_axis_tvalid : w_s3_m_valid;

    stage #(
        .DWIDTH         (DWIDTH),
        .FIFO_DEPTH     (FIFO_DEPTH/64),
        .FIFO_DEPTH_LOG (FIFO_DEPTH_LOG-6),
        .ROM_DEPTH      (ROM_DEPTH/64),
        .ROM_DEPTH_LOG  (ROM_DEPTH_LOG-6),
        .ROM_INIT_FILE  (ROM4_INIT_FILE)
    ) u_stage4 (
        .clk         (clk),
        .reset       (reset),
        .i_half_data (w_s4_half_data),
        .i_half_sel  (w_s4_half),
        .i_data      (w_s4_s_data),
        .i_valid     (w_s4_s_valid),
        .o_data      (w_s4_m_data),
        .o_valid     (w_s4_m_valid)
    );

    assign w_ls_s_data    = (w_ls_sel) ? w_fft_s_data : w_s4_m_data;
    assign w_ls_half_data = (w_ls_half) ? w_fft_s_data : {DWIDTH{1'b0}};
    assign w_ls_s_valid   = (w_ls_sel || w_ls_half) ? s_axis_tvalid : w_s4_m_valid;

    last_stage #(
        .DWIDTH         (DWIDTH),
        .FIFO_DEPTH     (FIFO_DEPTH/256),
        .FIFO_DEPTH_LOG (FIFO_DEPTH_LOG-8)
    ) u_last_stage (
        .clk         (clk),
        .reset       (reset),
        .i_half_data (w_ls_half_data),
        .i_half_sel  (w_ls_half),
        .i_data      (w_ls_s_data),
        .i_valid     (w_ls_s_valid),
        .o_data      (w_ls_m_data),
        .o_valid     (w_ls_m_valid)
    );

    assign w_ls_m_data_r  = w_ls_m_data[DWIDTH-1:HWIDTH];
    assign w_ls_m_data_i  = w_ls_m_data[HWIDTH-1:0];
    assign w_fft_m_data_r = w_ls_m_data_r;
    assign w_fft_m_data_i = (i_inverse) ? (~w_ls_m_data_i + 1'b1) : w_ls_m_data_i;
    assign w_fft_m_data   = {w_fft_m_data_r, w_fft_m_data_i};

    bit_reverse_top_0 u_bit_reverse(
        .clk     (clk),
        .reset   (reset),
        .i_data  (w_fft_m_data),
        .i_valid (w_ls_m_valid),
        .i_point (i_point),
        .o_data  (w_br_m_data),
        .o_valid (w_br_m_valid)
    );
    
    assign m_axis_tdata  = w_br_m_data;
    assign m_axis_tvalid = w_br_m_valid;

    reg [10:0] r_out_cnt;
    reg [10:0] r_target_cnt;

    always @(*) begin
        case (i_point)
            11'b100_0000_0000: r_target_cnt = 1024;
            11'b010_0000_0000: r_target_cnt = 512;
            11'b001_0000_0000: r_target_cnt = 256;
            11'b000_1000_0000: r_target_cnt = 128;
            11'b000_0100_0000: r_target_cnt = 64;
            11'b000_0010_0000: r_target_cnt = 32;
            11'b000_0001_0000: r_target_cnt = 16;
            11'b000_0000_1000: r_target_cnt = 8;
            11'b000_0000_0100: r_target_cnt = 4;
            11'b000_0000_0010: r_target_cnt = 2;
            default:           r_target_cnt = 1024;
        endcase
    end

    always @(posedge clk) begin
        if (reset) begin
            r_out_cnt <= 0;
        end else if (m_axis_tvalid && m_axis_tready) begin
            if (r_out_cnt == r_target_cnt - 1)
                r_out_cnt <= 0;
            else
                r_out_cnt <= r_out_cnt + 1;
        end
    end

    assign m_axis_tlast = (m_axis_tvalid && (r_out_cnt == r_target_cnt - 1));

endmodule