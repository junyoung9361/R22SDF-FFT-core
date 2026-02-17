module mux
#(
    parameter DWIDTH = 32
)
(
    input  [DWIDTH-1:0] i_data0,
    input  [DWIDTH-1:0] i_data1,
    input               i_bank_sel,
    output [DWIDTH-1:0] o_data
);
    assign o_data = (i_bank_sel) ? i_data1 : i_data0;

endmodule