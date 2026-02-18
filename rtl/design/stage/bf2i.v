module bf2i
#(
    parameter DWIDTH = 32,
    parameter DEPTH_LOG = 3
)
(
    input                       clk,
    input                       reset,
    input       [DWIDTH-1:0]    i_top_data,
    input                       i_top_valid,
    input       [DWIDTH-1:0]    i_bot_data,
    input                       i_bot_valid,

    output                      o_top_ready,
    output      [DWIDTH-1:0]    o_top_data,
    output                      o_top_valid,
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
    reg [DWIDTH-1:0]    r_data;
    reg [DWIDTH-1:0]    r_data_d;
    reg                 r_valid;
    reg                 r_valid_d;
    wire                w_top_hs = o_top_ready && i_top_valid;

    // FSM
    always@(posedge clk) begin
        if(reset)
            cs <= S_IDLE;
        else
            cs <= ns;
    end

    always@(*) begin
        case(cs)
            S_IDLE: ns = (r_valid) ? S_PUSH : S_IDLE;
            S_PUSH: ns = (r_cnt == {DEPTH_LOG{1'b1}}) ? S_CAL1 : S_PUSH;
            S_CAL1: begin
                        if(r_cnt == {DEPTH_LOG{1'b1}})
                            if(r_valid)
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
        else if(r_valid_d)
            r_cnt <= r_cnt + 1'b1;
        else if(w_top_hs && cs == S_PULL)
            r_cnt <= r_cnt + 1'b1;
        else
            r_cnt <= r_cnt;
    end

    // input latch
    always@(posedge clk) begin
        if(reset) begin
            r_data   <= {DWIDTH{1'b0}};
            r_data_d <= {DWIDTH{1'b0}};
        end else begin
            r_data   <= i_bot_data;
            r_data_d <= r_data;
        end
    end

    always@(posedge clk) begin
        if(reset) begin
            r_valid <= 1'b0;
            r_valid_d <= 1'b0;
        end else begin
            r_valid   <= i_bot_valid;
            r_valid_d <= r_valid;
        end
    end

    // Unpacking
    wire signed [HWIDTH-1:0] w_top_r = i_top_data[DWIDTH-1:HWIDTH];
    wire signed [HWIDTH-1:0] w_top_i = i_top_data[HWIDTH-1:0];
    wire signed [HWIDTH-1:0] w_bot_r = r_data_d[DWIDTH-1:HWIDTH];
    wire signed [HWIDTH-1:0] w_bot_i = r_data_d[HWIDTH-1:0];

    // adders for Butterfly
    wire signed [HWIDTH:0]   w_sum_r = w_top_r + w_bot_r;
    wire signed [HWIDTH:0]   w_sum_i = w_top_i + w_bot_i;
    
    // subtractors for Butterfly
    wire signed [HWIDTH:0]   w_diff_r = w_top_r - w_bot_r;
    wire signed [HWIDTH:0]   w_diff_i = w_top_i - w_bot_i;

    // Divide 2
    wire signed [HWIDTH-1:0] w_sum_r_scailed  = w_sum_r[HWIDTH:1];
    wire signed [HWIDTH-1:0] w_sum_i_scailed  = w_sum_i[HWIDTH:1];
    wire signed [HWIDTH-1:0] w_diff_r_scailed = w_diff_r[HWIDTH:1];
    wire signed [HWIDTH-1:0] w_diff_i_scailed = w_diff_i[HWIDTH:1];

    wire [DWIDTH-1:0] w_sum_out  = {w_sum_r_scailed, w_sum_i_scailed};
    wire [DWIDTH-1:0] w_diff_out = {w_diff_r_scailed, w_diff_i_scailed};

    // mux & cross
    assign w_sel = (cs == S_PUSH) || (cs == S_CAL2) || (cs == S_PULL);
    assign o_top_valid = r_valid_d;
    assign o_top_ready = (cs == S_CAL1) || (cs == S_CAL2) || (cs == S_PULL);
    assign o_top_data  = (w_sel) ? r_data_d : w_diff_out;
    
    assign o_bot_valid = (cs == S_CAL1) || (cs == S_CAL2) || (cs == S_PULL);
    assign o_bot_data  = (w_sel) ? i_top_data : w_sum_out;
    wire signed [HWIDTH-1:0] w_debug_r = o_bot_data[DWIDTH-1:HWIDTH];
    wire signed [HWIDTH-1:0] w_debug_i = o_bot_data[HWIDTH-1:0];
    
endmodule