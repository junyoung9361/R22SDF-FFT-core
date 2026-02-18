`timescale 1 ps / 1 ps

module bit_reverse_top #(
    parameter DWIDTH = 32
)
(
    input                clk,
    input                reset,
    input  [DWIDTH-1:0]  i_data,
    input  [10:0]        i_point,
    input                i_valid,
    output [DWIDTH-1:0]  o_data,
    output               o_valid
);
    wire              w_bank_sel;
    wire [9:0]        w_raddr0;
    wire [9:0]        w_raddr1;
    wire              w_ren0;
    wire              w_ren1;
    wire [9:0]        w_waddr0;
    wire [9:0]        w_waddr1;
    wire [DWIDTH-1:0] w_wdin0;
    wire [DWIDTH-1:0] w_wdin1;
    wire              w_wen0;
    wire              w_wen1;
    wire              w_wwe0;
    wire              w_wwe1;
    wire [DWIDTH-1:0] w_dout0;
    wire [DWIDTH-1:0] w_dout1;

    bit_reverse #(
        .DWIDTH(DWIDTH)
    ) u_bit_reverse (
        .clk        (clk),
        .reset      (reset),
        .i_point    (i_point),
        .i_data     (i_data),
        .i_valid    (i_valid),
        .o_valid    (o_valid),
        .o_bank_sel (w_bank_sel),
        .o_waddr0   (w_waddr0),
        .o_wdin0    (w_wdin0),
        .o_wen0     (w_wen0),
        .o_wwe0     (w_wwe0),
        .o_raddr0   (w_raddr0),
        .o_ren0     (w_ren0),
        .o_waddr1   (w_waddr1),
        .o_wdin1    (w_wdin1),
        .o_wen1     (w_wen1),
        .o_wwe1     (w_wwe1),
        .o_raddr1   (w_raddr1),
        .o_ren1     (w_ren1)
    );

    true_sync_dpbram #(
        .DWIDTH   (DWIDTH),
        .AWIDTH   (10),
        .MEM_SIZE (1024)
    ) u_bank0 (
        .clk   (clk),
        .addr0 (w_waddr0),
        .ce0   (w_wen0),
        .we0   (w_wwe0),
        .q0    (),
        .d0    (w_wdin0),
        .addr1 (w_raddr0),
        .ce1   (w_ren0),
        .we1   (1'b0),
        .q1    (w_dout0),
        .d1    (32'b0)
    );

    true_sync_dpbram #(
        .DWIDTH  (DWIDTH),
        .AWIDTH  (10),
        .MEM_SIZE(1024)
    ) u_bank1 (
        .clk   (clk),
        .addr0 (w_waddr1),
        .ce0   (w_wen1),
        .we0   (w_wwe1),
        .q0    (),
        .d0    (w_wdin1),
        .addr1 (w_raddr1),
        .ce1   (w_ren1),
        .we1   (1'b0),
        .q1    (w_dout1),
        .d1    (32'b0)
    );

    assign o_data = (w_bank_sel) ? w_dout1 : w_dout0;

endmodule
