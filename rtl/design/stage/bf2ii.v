module bf2ii
#(
    parameter DWIDTH = 32,
    parameter DEPTH_LOG = 3
)
(
    input                       clk,
    input                       reset,
    input       [DWIDTH-1:0]    i_half_data,
    input                       i_half_sel,
    input       [DWIDTH-1:0]    i_top_data,
    input                       i_top_valid,
    input       [DWIDTH-1:0]    i_bot_data,
    input                       i_bot_valid,

    output                      o_top_ready,
    output                      o_top_valid,
    output      [DWIDTH-1:0]    o_top_data,
    output      [DWIDTH-1:0]    o_bot_data,
    output                      o_bot_valid
);

    localparam HWIDTH = DWIDTH / 2;
    localparam S_IDLE = 3'b000;
    localparam S_PUSH = 3'b001;
    localparam S_CAL1 = 3'b010;
    localparam S_CAL2 = 3'b011;
    localparam S_PULL = 3'b100;

    reg [2:0] cs, ns;

    reg [DEPTH_LOG-1:0] r_cnt;
    reg                 r_j_cnt;
    
    // Data & Control Latch Registers
    reg [DWIDTH-1:0]    r_data;
    reg [DWIDTH-1:0]    r_half_data;
    reg                 r_half_sel;
    reg                 r_valid;
    
    wire                w_top_hs = i_top_valid && o_top_ready;

    // FSM
    always@(posedge clk) begin
        if(reset)
            cs <= S_IDLE;
        else
            cs <= ns;
    end

    always@(*) begin
        case(cs)
            S_IDLE: ns = (i_bot_valid) ? S_PUSH : S_IDLE;
            S_PUSH: ns = (r_cnt == {DEPTH_LOG{1'b1}}) ? S_CAL1 : S_PUSH;
            S_CAL1: begin
                        if(r_cnt == {DEPTH_LOG{1'b1}})
                            if(i_bot_valid)
                                ns = S_CAL2;
                            else
                                ns = S_PULL;
                        else
                            ns = S_CAL1;
                    end
             S_CAL2: ns = (r_cnt == {DEPTH_LOG{1'b1}}) ? S_CAL1 : S_CAL2;
             S_PULL: ns = (r_cnt == {DEPTH_LOG{1'b1}}) ? S_IDLE : S_PULL;
             default: ns = S_IDLE;
        endcase
    end

    // valid counter
    always@(posedge clk) begin
        if(reset)
            r_cnt <= {DEPTH_LOG{1'b0}};
        else if(r_valid)
            r_cnt <= r_cnt + 1'b1;
        else if(w_top_hs && cs == S_PULL)
            r_cnt <= r_cnt + 1'b1;
        else
            r_cnt <= r_cnt;
    end

    always@(posedge clk) begin
        if(reset)
            r_j_cnt <= 1'b0;
        else if(r_cnt == {DEPTH_LOG{1'b1}} && cs == S_CAL1)
            r_j_cnt <= ~r_j_cnt;
        else
            r_j_cnt <= r_j_cnt;
    end

    // Input Latch (Pipeline Stage)
    always@(posedge clk) begin
        if(reset) begin
            r_data      <= {DWIDTH{1'b0}};
            r_half_data <= {DWIDTH{1'b0}};
            r_half_sel  <= 1'b0;
            r_valid     <= 1'b0;
        end else begin
            r_data      <= i_bot_data;
            r_half_data <= i_half_data;
            r_half_sel  <= i_half_sel;
            r_valid     <= i_bot_valid;
        end
    end

    // input j mux
    wire w_j_sel;
    assign w_j_sel = (r_j_cnt == 1'b1) && (cs == S_CAL1);

    // Unpacking
    wire signed [HWIDTH-1:0] w_top_r  = i_top_data[DWIDTH-1:HWIDTH];
    wire signed [HWIDTH-1:0] w_top_i  = i_top_data[HWIDTH-1:0];
    wire signed [HWIDTH-1:0] w_bot_r  = r_data[DWIDTH-1:HWIDTH];
    wire signed [HWIDTH-1:0] w_bot_i  = r_data[HWIDTH-1:0];
    wire signed [HWIDTH-1:0] w_half_r = r_half_data[DWIDTH-1:HWIDTH];
    wire signed [HWIDTH-1:0] w_half_i = r_half_data[HWIDTH-1:0];

    // mult -j
    wire signed [HWIDTH-1:0] w_bot_j_r = w_bot_i;
    wire signed [HWIDTH-1:0] w_bot_j_i = ~w_bot_r + 1'b1;
    
    wire signed [HWIDTH-1:0] w_bot_j_mux_r = (w_j_sel)  ? w_bot_j_r : w_bot_r;
    wire signed [HWIDTH-1:0] w_bot_j_mux_i = (w_j_sel)  ? w_bot_j_i : w_bot_i;
    
    wire signed [HWIDTH-1:0] w_bot_mux_r = (r_half_sel) ? w_half_r : w_bot_j_mux_r;
    wire signed [HWIDTH-1:0] w_bot_mux_i = (r_half_sel) ? w_half_i : w_bot_j_mux_i;
    
    wire signed [DWIDTH-1:0] w_bot_data = {w_bot_mux_r, w_bot_mux_i};
    
    // adders for Butterfly
    wire signed [HWIDTH:0]   w_sum_r = w_top_r + w_bot_mux_r;
    wire signed [HWIDTH:0]   w_sum_i = w_top_i + w_bot_mux_i;
    
    // subtractors for Butterfly
    wire signed [HWIDTH:0]   w_diff_r = w_top_r - w_bot_mux_r;
    wire signed [HWIDTH:0]   w_diff_i = w_top_i - w_bot_mux_i;

    // Divide 2
    wire signed [HWIDTH-1:0] w_sum_r_scailed  = w_sum_r[HWIDTH:1];
    wire signed [HWIDTH-1:0] w_sum_i_scailed  = w_sum_i[HWIDTH:1];
    wire signed [HWIDTH-1:0] w_diff_r_scailed = w_diff_r[HWIDTH:1];
    wire signed [HWIDTH-1:0] w_diff_i_scailed = w_diff_i[HWIDTH:1];

    wire [DWIDTH-1:0] w_sum_out  = {w_sum_r_scailed, w_sum_i_scailed};
    wire [DWIDTH-1:0] w_diff_out = {w_diff_r_scailed, w_diff_i_scailed};

    // mux & cross
    assign w_sel = (cs == S_PUSH) || (cs == S_CAL2) || (cs == S_PULL);
    
    assign o_top_valid = r_valid;
    
    assign o_top_ready = (cs == S_CAL1) || (cs == S_CAL2) || (cs == S_PULL);
    assign o_top_data  = (w_sel) ? w_bot_data : w_diff_out;
    assign o_bot_valid = ((cs == S_CAL1 || cs == S_CAL2) && r_valid) || (cs == S_PULL);
    
    assign o_bot_data  = (w_sel) ? i_top_data : w_sum_out;
    
    wire signed [HWIDTH-1:0] w_debug_r = o_bot_data[DWIDTH-1:HWIDTH];
    wire signed [HWIDTH-1:0] w_debug_i = o_bot_data[HWIDTH-1:0];

endmodule