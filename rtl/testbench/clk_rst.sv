`define ACLK 100 // MHz

module clk_rst (
    output logic aclk       ,
    output logic areset_n
);


//--------------------------------------------------------------
// parameters
//--------------------------------------------------------------
parameter ACLK_FREQ = `ACLK; // MHz

parameter ACLK_PERIOD = (1000.0 / ACLK_FREQ); // ns


//--------------------------------------------------------------
// clock generation
//--------------------------------------------------------------
reg  aclk_int;

initial aclk_int = 1'b0;

always #(ACLK_PERIOD/2) aclk_int = ~aclk_int;

assign aclk = aclk_int;


//--------------------------------------------------------------
// reset generation
//--------------------------------------------------------------
reg int_reset_n ;

initial
begin
    $display("ACLK_FREQ = %d", ACLK_FREQ);

    int_reset_n = 2'b1;
    #101;
    int_reset_n = 2'b0;
    repeat (3) @(posedge aclk); // make sure clock edge passes
    #101;
    int_reset_n = 2'b1;
end

always @ (negedge aclk) areset_n <= int_reset_n;

endmodule