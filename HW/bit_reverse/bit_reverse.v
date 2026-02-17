module bit_reversal
#(
    parameter DWIDTH = 32
)
(
    input              clk,
    input              reset,
    input [10:0]       i_point,
    input [DWIDTH-1:0] i_data,
    input              i_valid,
    output             o_valid,
    output             o_bank_sel,

    // BANK 0
    // WRITE PORT
    output reg [9:0]        o_waddr0,
    output reg [DWIDTH-1:0] o_wdin0,
    output reg              o_wen0,
    output reg              o_wwe0,

    // READ PORT
    output reg [9:0]        o_raddr0,
    output reg              o_ren0,

    // BANK 1
    // WRITE PORT
    output reg [9:0]        o_waddr1,
    output reg [DWIDTH-1:0] o_wdin1,
    output reg              o_wen1,
    output reg              o_wwe1,

    // READ PORT
    output reg [9:0]        o_raddr1,
    output reg              o_ren1
);
    localparam S_IDLE  = 2'b00;
    localparam S_BANK0 = 2'b01;
    localparam S_BANK1 = 2'b10;
    localparam S_READ  = 2'b11;

    reg  [1:0] cs, ns;
    reg  [DWIDTH-1:0] r_data;
    reg               r_valid;
    reg  [9:0] r_cnt;
    wire [9:0] w_max_cnt = i_point - 1'b1;
    reg  [9:0] w_cnt_rev;
    reg        r_bank_full;
    reg        r_bank_sel;
    reg        r_bank_sel_d;
    reg        r_valid_out;

    always@(*) begin
        case(cs)
            S_IDLE : ns = (i_valid) ? S_BANK0 : S_IDLE;
            S_BANK0: begin
                    if(r_cnt == w_max_cnt)
                        if(i_valid)
                            ns = S_BANK1;
                        else
                            ns = S_READ;
                    else
                        ns = S_BANK0;
                    end
            S_BANK1: begin
                    if(r_cnt == w_max_cnt)
                        if(i_valid)
                            ns = S_BANK0;
                        else
                            ns = S_READ;
                    else  
                        ns = S_BANK1;
                    end
            S_READ: ns = (r_cnt == w_max_cnt) ? S_IDLE : S_READ;
            default: ns = S_IDLE;
        endcase
    end
    
    always@(posedge clk) begin
        if(reset)
            cs <= S_IDLE;
        else
            cs <= ns;
    end

    always@(posedge clk) begin
        if(reset)
            r_data <= {DWIDTH{1'b0}};
        else
            r_data <= i_data;
    end

    always@(posedge clk) begin
        if(reset)
            r_valid <= 1'b0;
        else
            r_valid <= i_valid;
    end

    always@(posedge clk) begin
        if(reset)
            r_cnt <= 10'b0;
        else if(r_cnt == w_max_cnt)
            r_cnt <= 10'b0;
        else if(r_valid || cs == S_READ)
            r_cnt <= r_cnt + 1'b1;
        else
            r_cnt <= r_cnt;
    end

    always@(posedge clk) begin
        if(reset)
            r_bank_sel <= 1'b0;
        else if((r_cnt == w_max_cnt) && (cs == S_BANK0))
            r_bank_sel <= 0;
        else if((r_cnt == w_max_cnt) && (cs == S_BANK1))
            r_bank_sel <= 1;
        else
            r_bank_sel <= r_bank_sel;
    end

    always@(posedge clk) begin
        if(reset)
            r_bank_sel_d <= 1'b0;
        else
            r_bank_sel_d <= r_bank_sel;
    end

    always @(*) begin
        case (i_point)
            11'd1024 : w_cnt_rev = {r_cnt[0], r_cnt[1], r_cnt[2], r_cnt[3], r_cnt[4], r_cnt[5], r_cnt[6], r_cnt[7], r_cnt[8], r_cnt[9]};
            11'd512  : w_cnt_rev = {1'b0, r_cnt[0], r_cnt[1], r_cnt[2], r_cnt[3], r_cnt[4], r_cnt[5], r_cnt[6], r_cnt[7], r_cnt[8]};
            11'd256  : w_cnt_rev = {2'b00, r_cnt[0], r_cnt[1], r_cnt[2], r_cnt[3], r_cnt[4], r_cnt[5], r_cnt[6], r_cnt[7]};
            11'd128  : w_cnt_rev = {3'b000, r_cnt[0], r_cnt[1], r_cnt[2], r_cnt[3], r_cnt[4], r_cnt[5], r_cnt[6]};
            11'd64   : w_cnt_rev = {4'b0000, r_cnt[0], r_cnt[1], r_cnt[2], r_cnt[3], r_cnt[4], r_cnt[5]};
            11'd32   : w_cnt_rev = {5'b00000, r_cnt[0], r_cnt[1], r_cnt[2], r_cnt[3], r_cnt[4]};
            11'd16   : w_cnt_rev = {6'b000000, r_cnt[0], r_cnt[1], r_cnt[2], r_cnt[3]};
            11'd8    : w_cnt_rev = {7'b0000000, r_cnt[0], r_cnt[1], r_cnt[2]};
            11'd4    : w_cnt_rev = {8'b00000000, r_cnt[0], r_cnt[1]};
            11'd2    : w_cnt_rev = {9'b000000000, r_cnt[0]};
            default: w_cnt_rev = 0;
        endcase
    end

    always@(posedge clk) begin
        if(reset)
            r_bank_full <= 1'b0;
        else if(cs == S_IDLE)
            r_bank_full <= 1'b0;
        else if((r_cnt == w_max_cnt) && i_valid && (cs == S_BANK0 || cs == S_BANK1))
            r_bank_full <= 1'b1;
        else
            r_bank_full <= r_bank_full;
    end

    always@(*) begin
        case(cs)
            S_IDLE : begin
                        o_wdin0  = {DWIDTH{1'b0}};
                        o_wen0   = 1'b0;
                        o_wwe0   = 1'b0;
                        o_waddr0 = 10'b0;
                        
                        o_wdin1   = {DWIDTH{1'b0}};
                        o_wen1    = 1'b0;
                        o_wwe1    = 1'b0;
                        o_waddr1  = 10'b0;

                        o_raddr0  = 10'b0;
                        o_ren0    = 1'b0;
                        o_raddr1 = 10'b0;
                        o_ren1    = 1'b0;
                    end
            S_BANK0: begin
                        o_wdin0  = r_data;
                        o_wen0   = 1'b1;
                        o_wwe0   = 1'b1;
                        o_waddr0 = w_cnt_rev;

                        o_wdin1  = {DWIDTH{1'b0}};
                        o_wen1   = 1'b0;
                        o_wwe1   = 1'b0;
                        o_waddr1 = 10'b0;

                        if(r_bank_full) begin
                            o_raddr0  = 10'b0;
                            o_ren0    = 1'b0;
                            o_raddr1 = r_cnt;
                            o_ren1    = 1'b1;
                        end

                    end
            S_BANK1: begin
                        o_wdin0  = {DWIDTH{1'b0}};
                        o_wen0   = 1'b0;
                        o_wwe0   = 1'b0;
                        o_waddr0 = 10'b0;
                        
                        o_wdin1  = r_data;
                        o_wen1   = 1'b1;
                        o_wwe1   = 1'b1;
                        o_waddr1 = w_cnt_rev;

                        if(r_bank_full) begin
                            o_raddr0  = r_cnt;
                            o_ren0    = 1'b1;
                            o_raddr1 = 10'b0;
                            o_ren1    = 1'b0;
                        end
                    end
            S_READ: begin
                        o_wdin0  = {DWIDTH{1'b0}};
                        o_wen0   = 1'b0;
                        o_wwe0   = 1'b0;
                        o_waddr0 = 10'b0;

                        o_wdin1  = {DWIDTH{1'b0}};
                        o_wen1   = 1'b0;
                        o_wwe1   = 1'b0;
                        o_waddr1 = 10'b0;

                        if(r_bank_sel) begin
                            o_raddr0  = 10'b0;
                            o_ren0    = 1'b0;
                            o_raddr1  = r_cnt;
                            o_ren1    = 1'b1;
                        end else begin
                            o_raddr0  = r_cnt;
                            o_ren0    = 1'b1;
                            o_raddr1  = 10'b0;
                            o_ren1    = 1'b0;
                        end
                    end
            default: begin
                        o_wdin0  = {DWIDTH{1'b0}};
                        o_wen0   = 1'b0;
                        o_wwe0   = 1'b0;
                        o_waddr0 = 10'b0;

                        o_wdin1  = {DWIDTH{1'b0}};
                        o_wen1   = 1'b0;
                        o_wwe1   = 1'b0;
                        o_waddr1 = 10'b0;

                        o_raddr0  = 10'b0;
                        o_ren0    = 1'b0;
                        o_raddr1 = 10'b0;
                        o_ren1    = 1'b0;
                    end
        endcase
    end

    always@(posedge clk) begin
        if(reset)
            r_valid_out <= 1'b0;
        else if(o_ren0 || o_ren1)
            r_valid_out <= 1'b1;
        else
            r_valid_out <= 1'b0;
    end

    assign o_valid = r_valid_out;
    assign o_bank_sel = r_bank_sel_d;

endmodule