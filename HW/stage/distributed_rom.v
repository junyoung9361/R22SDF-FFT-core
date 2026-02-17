module distributed_rom #(
    parameter DWIDTH = 32,
    parameter DEPTH  = 512,
    parameter DEPTH_LOG = 9,
    parameter INIT_FILE = "twiddle.mem"
)

 (
    input  [DEPTH_LOG-1:0] i_addr,
    output [DWIDTH-1:0]    o_data    
);

    (* rom_style = "distributed" *) reg [DWIDTH-1:0] rom [0:DEPTH-1];
    
    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, rom);
        end
    end

    assign o_data = rom[i_addr];

endmodule