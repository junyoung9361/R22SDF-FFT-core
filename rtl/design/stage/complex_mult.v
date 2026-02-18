module complex_mult
#(
    parameter DEPTH     = 512,
    parameter DEPTH_LOG = 9,
    parameter DWIDTH    = 32,   
    parameter FL_twid   = 15, 
    parameter INIT_FILE = "twiddle.mem"
)
(
    input                clk,
    input                reset,
    input                i_half_sel,
    input  [DWIDTH-1:0]  i_data,
    input                i_valid,
    output [DWIDTH-1:0]  o_data,
    output               o_valid
);

    localparam HWIDTH = DWIDTH / 2;
    localparam S_IDLE = 3'b000;
    localparam S_0K   = 3'b001;
    localparam S_2K   = 3'b010;
    localparam S_1K   = 3'b011;
    localparam S_3K   = 3'b100;

    reg  [2:0] cs, ns;
    reg  [DEPTH_LOG-1:0]     r_cnt;
    reg  [DEPTH_LOG:0]       w_addr_full;
    wire  [DEPTH_LOG-1:0]    w_addr = w_addr_full[DEPTH_LOG-1:0];
    wire                     w_sign_inv = w_addr_full[DEPTH_LOG];
    reg                      r_half;
    reg  [DWIDTH-1:0]        r_data, r_data_d;
    reg                      r_valid, r_valid_d;
    wire [DWIDTH-1:0]        w_w;
    wire signed [HWIDTH-1:0] w_data_r = r_data[DWIDTH-1:HWIDTH];
    wire signed [HWIDTH-1:0] w_data_i = r_data[HWIDTH-1:0];
    wire signed [HWIDTH-1:0] w_w_r    = (w_sign_inv) ? (~w_w[DWIDTH-1:HWIDTH] + 1'b1) : w_w[DWIDTH-1:HWIDTH];
    wire signed [HWIDTH-1:0] w_w_i    = (w_sign_inv) ? (~w_w[HWIDTH-1:0] + 1'b1) : w_w[HWIDTH-1:0];
    reg  signed [DWIDTH-1:0] r_p1, r_p2, r_p3, r_p4;
    wire signed [DWIDTH:0]   w_sub, w_sum;
    wire signed [HWIDTH-1:0] w_sub_scailed;
    wire signed [HWIDTH-1:0] w_sum_scailed;
    wire        [DWIDTH-1:0] w_data_out;
    
    wire [DEPTH_LOG-1:0] block_size = (DEPTH/2);

    always @(posedge clk) begin
        if(reset) cs <= S_IDLE;
        else      cs <= ns;
    end

    always @(*) begin
        case(cs)
            S_IDLE: ns = (i_valid) ? S_0K : S_IDLE;
            S_0K  : ns = (r_valid && r_cnt == block_size-1) ? S_2K : S_0K;
            S_2K  : begin
                if (r_valid && r_cnt == block_size-1)
                    ns = i_half_sel ? (i_valid ? S_0K : S_IDLE) : S_1K;
                else
                    ns = S_2K;
            end
            S_1K  : ns = (r_valid && r_cnt == block_size-1) ? S_3K : S_1K;
            S_3K  : begin
                if (r_valid && r_cnt == block_size-1)
                    ns = i_valid ? S_0K : S_IDLE;
                else
                    ns = S_3K;
            end
            default: ns = S_IDLE;
        endcase
    end


    
    always@(posedge clk) begin
        if(reset) begin
            r_data   <= 0; r_data_d <= 0;
            r_valid  <= 0; r_valid_d <= 0;
        end else begin
            r_data    <= i_data;
            r_data_d  <= r_data;
            r_valid   <= i_valid;
            r_valid_d <= r_valid;
        end
    end

    always @(posedge clk) begin
        if(reset) 
            r_cnt <= 0;
        else if(r_valid) begin
            if (r_cnt == block_size - 1)
                r_cnt <= 0;
            else
                r_cnt <= r_cnt + 1'b1;
        end else 
            r_cnt <= 0;
    end

    always @(*) begin
        case(cs)
            S_0K: w_addr_full = 0;                     // W^0
            S_2K: w_addr_full = r_cnt << 1;            // W^2k
            S_1K: w_addr_full = r_cnt;                 // W^k
            S_3K: w_addr_full = (r_cnt << 1) + r_cnt;  // W^3k (2k+k)
            default: w_addr_full = 0;
        endcase
    end

    
    distributed_rom #(
        .DWIDTH(DWIDTH), 
        .DEPTH(DEPTH), 
        .DEPTH_LOG(DEPTH_LOG), 
        .INIT_FILE(INIT_FILE)
    ) u_rom (
        .i_addr(w_addr), 
        .o_data(w_w)
    );

    always@(posedge clk) begin
        if(reset) begin
            r_p1 <= {DWIDTH{1'b0}};
            r_p2 <= {DWIDTH{1'b0}};
            r_p3 <= {DWIDTH{1'b0}};
            r_p4 <= {DWIDTH{1'b0}};
        end else begin
            r_p1 <= w_data_r * w_w_r;
            r_p2 <= w_data_i * w_w_i;
            r_p3 <= w_data_r * w_w_i;
            r_p4 <= w_data_i * w_w_r;
        end
    end

    assign w_sub = r_p1 - r_p2;
    assign w_sum = r_p3 + r_p4;

    assign w_sub_scailed = w_sub[DWIDTH-1:FL_twid];
    assign w_sum_scailed = w_sum[DWIDTH-1:FL_twid];

    assign w_data_out = {w_sub_scailed, w_sum_scailed};
    assign o_data  = w_data_out;
    assign o_valid = r_valid_d;

endmodule