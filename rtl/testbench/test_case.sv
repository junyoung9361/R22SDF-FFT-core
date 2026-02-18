`include "testbench_defines.v"
module test_case #(
    parameter DWIDTH = 32
) 
(
    input                aclk           ,
    input                areset_n       ,
    output               o_inverse      ,
    output  [10:0]       o_point        ,
    output  [DWIDTH-1:0] o_axis_tdata   ,
    output               o_axis_tvalid  ,
    input                i_axis_tready  ,
    output               o_axis_tlast   ,
    input   [DWIDTH-1:0] i_axis_tdata   ,
    input                i_axis_tvalid  ,
    output               o_axis_tready  ,
    input                i_axis_tlast
);

//--------------------------------------------------------------
// input files
//--------------------------------------------------------------
integer input_vector;
integer output_vector;
logic [DWIDTH-1:0] input_que[$];
logic [DWIDTH-1:0] output_que[$];
wire s_hs;
wire m_hs;
reg [DWIDTH-1:0] r_s_axis_tdata;
reg              r_s_axis_tvalid;
//--------------------------------------------------------------
// open input Vector file
//--------------------------------------------------------------
task automatic t_open_vector_file;
input string fname;
output int vector;
begin
    vector = $fopen(fname,"rb");
    if (!vector) begin
        $display("*E: cannot open %s. Exit...", fname);
        $finish;
    end else begin
        $display("[%m] *N: file %s is opened.", fname);
    end
end
endtask

//--------------------------------------------------------------
// read input Vector
//--------------------------------------------------------------
task automatic t_read_vector;
input string fname;
input int vector;
ref logic [DWIDTH-1:0] vector_que[$];
logic [DWIDTH-1:0] input_data;
int ret;
begin
    // input vector file open
    if (!vector) begin
        $display("*E: cannot open %s. Exit...", fname);
        $finish;
    end
    ret = $fseek (vector, 0, `SEEK_SET);
    $display ("[%m] Read Vector file : %s", fname);

    vector_que.delete();

    for (int i = 0; i < `FFT_POINT; i++) begin
        ret = $fread(input_data, vector);
        if (ret != (DWIDTH/8)) begin
            $display("[%m] *E: vector file read error (ret=%0d)", ret);
            $finish;
        end
        vector_que.push_back(input_data);
    end
    $display ("[%m] Vector Que size : %d", vector_que.size());
end
endtask

//--------------------------------------------------------------
// AXIS handshake
//--------------------------------------------------------------
assign s_hs = o_axis_tvalid  && i_axis_tready  ;
assign m_hs = i_axis_tvalid  && o_axis_tready  ;

// input (AXIS rule: hold data stable while valid=1 and ready=0)
always_ff @ (posedge aclk or negedge areset_n) begin
    if (~areset_n) begin
        r_s_axis_tdata  <= 'd0;
        r_s_axis_tvalid <= 1'b0;
    end else begin
        if (!r_s_axis_tvalid) begin
            if (input_que.size()) begin
                r_s_axis_tdata  <= input_que.pop_front();
                r_s_axis_tvalid <= 1'b1;
            end
        end else if (s_hs) begin
            if (input_que.size()) begin
                r_s_axis_tdata  <= input_que.pop_front();
                r_s_axis_tvalid <= 1'b1;
            end else begin
                r_s_axis_tvalid <= 1'b0;
            end
        end
    end
end

// output
assign o_axis_tdata  = r_s_axis_tdata;
assign o_axis_tvalid = r_s_axis_tvalid;
assign o_axis_tlast  = (input_que.size() == 1) ? 1'b1 : 1'b0;
assign o_axis_tready = 1'b1;
assign o_inverse     = `FFT_TYPE;
assign o_point       = `FFT_POINT;

//--------------------------------------------------------------
// main test case
//--------------------------------------------------------------
initial begin
    int out_idx;
    
    // wait for reset released
    @(negedge areset_n);
    @(posedge areset_n);
    repeat(10) @(posedge aclk);

    // main control
    $display("*N: Simulation Start.");

    $display("==========================");
    $display("  FFT Simulation start.");
    $display("  FFT Type : %s", (`FFT_TYPE == 1) ? "IFFT" : "FFT");
    $display("  FFT Point : %d", `FFT_POINT);
    $display("  Test Type : %s", (`TEST_TYPE == 0) ? "Random" : (`TEST_TYPE == 1) ? "Sine wave" : "Image");
    $display("==========================");

    t_open_vector_file ("input_data_tone4_1024.bin", input_vector);
    t_open_vector_file ("output_data_tone4_1024.bin", output_vector);

    t_read_vector ("input_data_tone4_1024", input_vector, input_que);
    t_read_vector ("output_data_tone4_1024", output_vector, output_que);

    out_idx = 0;
    while (output_que.size() > 0) begin
        @(posedge aclk);
        if (m_hs) begin
            if (i_axis_tdata !== output_que[0]) begin
                $display("[%m] *E: output mismatch at idx=%0d ref : %h, dut : %h", out_idx, output_que[0], i_axis_tdata);
                $finish;
            end
        output_que.pop_front();
        out_idx++;
        end
    end

    $display("\n===========================================");
    $display("  FFT SIMULATION FINISHED.");
    $display("===========================================\n");
 
    repeat (100) @(posedge aclk);
    $finish;
end

//--------------------------------------------------------------
// hang up detection (idle cycle watchdog)
//--------------------------------------------------------------
parameter int MAX_IDLE_CYCLES = 100000;
int idle_cnt;

always_ff @ (posedge aclk or negedge areset_n) begin
    if (~areset_n) begin
        idle_cnt <= 0;
    end else if (s_hs || m_hs) begin
        idle_cnt <= 0;
    end else if (idle_cnt < MAX_IDLE_CYCLES + 1) begin
        idle_cnt <= idle_cnt + 1;
    end
end

always_ff @ (posedge aclk) begin
    if (idle_cnt > MAX_IDLE_CYCLES) begin
        $display("\n Hang Detected!!! Exiting...\n");
        $finish;
    end
end

endmodule
