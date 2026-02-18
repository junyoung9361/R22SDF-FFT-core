module fifo 
# (
    parameter   DWIDTH    = 32,
    parameter   DEPTH     = 4,
    parameter   DEPTH_LOG = 2
)
(
    input                 clk,
    input                 reset,

    // Slave Port
    input                 i_valid,
    output                o_ready,
    input   [DWIDTH-1:0]  i_data,

    // Master Port
    output                o_valid,
    input                 i_ready,
    output  [DWIDTH-1:0]  o_data
);

    wire is_empty;
    wire is_full;

    wire push_en = i_valid & o_ready; // Write Enable
    wire pop_en  = o_valid & i_ready; // Read Enable

	// Slave (Write Pointer)
    reg [DEPTH_LOG-1:0] w_addr;
	reg [DEPTH_LOG-1:0] w_addr_next;
    reg                 w_msb;
	reg                 w_msb_next;

	// Master (Read Pointer)
    reg [DEPTH_LOG-1:0] r_addr;
	reg [DEPTH_LOG-1:0] r_addr_next;
    reg                 r_msb;
	reg                 r_msb_next;

    (* ram_style = "distributed" *) reg [DWIDTH-1:0] mem[DEPTH-1:0];

    integer i;
    always @(posedge clk) begin
        if (reset) begin
            w_addr <= {DEPTH_LOG{1'b0}};
            w_msb <= 1'b0;
            for (i = 0; i < DEPTH; i = i + 1)
                mem[i] <= {DWIDTH{1'b0}};
        end else if (push_en) begin
            mem[w_addr] <= i_data;
            w_addr <= w_addr_next;
            w_msb  <= w_msb_next;
        end
    end

    always @(*) begin
        if (w_addr == (DEPTH - 1)) begin 	// ROM Table의 수가 2의 배수가 아니라서
            w_addr_next = {DEPTH_LOG{1'b0}};
            w_msb_next  = ~w_msb;
        end else begin
            w_addr_next = w_addr + 1'b1;
            w_msb_next  = w_msb;
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            r_addr <= {DEPTH_LOG{1'b0}};
            r_msb <= 1'b0;
        end else if (pop_en) begin
            r_addr <= r_addr_next;
            r_msb  <= r_msb_next;
        end
    end

    always @(*) begin
        if (r_addr == (DEPTH - 1)) begin	// ROM Table의 수가 2의 배수가 아니라서
            r_addr_next = {DEPTH_LOG{1'b0}};
            r_msb_next = ~r_msb;
        end else begin
            r_addr_next = r_addr + 1'b1;
            r_msb_next = r_msb;
        end
    end

    assign o_data = mem[r_addr];
    assign is_empty = (w_addr == r_addr) && (w_msb == r_msb);
    assign is_full  = (w_addr == r_addr) && (w_msb != r_msb);

    assign o_ready = !is_full;
    assign o_valid = !is_empty;

endmodule