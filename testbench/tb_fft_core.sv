`timescale 1ns / 1ps

module tb_fft_core;
    parameter CLK_PERIOD = 10;          // 100MHz
    parameter DWIDTH     = 32;
    parameter POINT      = 512;         // POINT
    parameter IS_INVERSE    = 1;        // 1: IFFT, 0: FFT
    parameter IN_FILE_0   = "input_data_constant_1024.hex";
    parameter IN_FILE_1   = "input_data_impulse_1024.hex";
    parameter IN_FILE_2   = "input_data_tone4_1024.hex";
    parameter IN_FILE_3   = "input_data_nomarlized_random_1024.hex";
    parameter IN_FILE_4   = "input_data_nomarlized_fix_512.hex";
    parameter IN_FILE_5   = "input_data_ifft_verify_1024.hex";
    parameter GOLD_FILE_0 = "output_data_constant_1024.hex";
    parameter GOLD_FILE_1 = "output_data_impulse_1024.hex";
    parameter GOLD_FILE_2 = "output_data_tone4_1024.hex";
    parameter GOLD_FILE_3 = "output_data_nomarlized_random_1024.hex";
    parameter GOLD_FILE_4 = "output_data_nomarlized_fix_512.hex";
    parameter GOLD_FILE_5 = "output_data_ifft_verify_1024.hex";
    reg clk;
    reg reset;
    
    // DUT Interface (AXI-Stream & Config)
    reg [10:0] i_point;
    reg        i_inverse;
    
    reg [DWIDTH-1:0] s_axis_tdata;
    reg              s_axis_tvalid;
    wire             s_axis_tready;
    reg              s_axis_tlast;
    
    wire [DWIDTH-1:0] m_axis_tdata;
    wire              m_axis_tvalid;
    reg               m_axis_tready;
    wire              m_axis_tlast;

    // Testbench Memories
    reg [31:0] input_mem0  [0:POINT-1]; 
    reg [31:0] input_mem1  [0:POINT-1];
    reg [31:0] golden_mem0 [0:POINT-1]; 
    reg [31:0] golden_mem1 [0:POINT-1];

    // Status Variables
    integer i;
    integer out_cnt;
    integer err_cnt;
    integer pass_cnt;

    fft_core #(
        .DWIDTH(DWIDTH),
        .FIFO_DEPTH(512), 
        .ROM_DEPTH(512)
    ) u_dut (
        .clk(clk),
        .reset(reset),
        .i_inverse(i_inverse),
        .i_point(i_point),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast)
    );

    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    initial begin
        // --- [Step 1] File Loading ---
        $display("-------------------------------------------");
        $display(" RUNNING IN [%s] MODE", (IS_INVERSE) ? "IFFT" : "FFT");
        $display(" Loading Hex Files for Verification...");
        $readmemh(IN_FILE_4,   input_mem0);
        $readmemh(IN_FILE_4,   input_mem1);
        $readmemh(GOLD_FILE_4, golden_mem0);
        $readmemh(GOLD_FILE_4, golden_mem1);
        $display(" Load Complete.");
        $display("-------------------------------------------");

        reset = 1;
        s_axis_tvalid = 0;
        s_axis_tdata  = 0;
        s_axis_tlast  = 0;
        m_axis_tready = 1; // DMA always ready
        i_point = POINT;
        i_inverse = IS_INVERSE; 

        out_cnt = 0;
        err_cnt = 0;
        pass_cnt = 0;

        #(CLK_PERIOD * 10);
        reset = 0;
        #(CLK_PERIOD * 5);

        $display(" [TEST START] Dual Stream Simulation (N=%0d)", POINT);

        // --- Stream 0 Injection ---
        $display("[Time %t] Stream 0 Injecting...", $time);
        for (i = 0; i < POINT; i = i + 1) begin
            @(posedge clk);
            while (!s_axis_tready) @(posedge clk);
            s_axis_tvalid = 1;
            s_axis_tdata  = input_mem0[i];
            s_axis_tlast  = (i == POINT - 1);
        end

        // --- Stream 1 Injection ---
        $display("[Time %t] Stream 1 Injecting...", $time);
        for (i = 0; i < POINT; i = i + 1) begin
            @(posedge clk);
            while (!s_axis_tready) @(posedge clk);
            s_axis_tvalid = 1;
            s_axis_tdata  = input_mem1[i];
            s_axis_tlast  = (i == POINT - 1);
        end

        @(posedge clk);
        s_axis_tvalid = 0;
        s_axis_tlast  = 0;
        s_axis_tdata  = 0;

        $display(" All inputs injected. Monitoring outputs...");

        #(CLK_PERIOD * (POINT * 5));

        $display("\n===========================================");
        $display(" [SIMULATION TIMEOUT]");
        $display(" Total Received: %0d / %0d", out_cnt, POINT*2);
        $display(" [TEST FAILED]");
        $display("===========================================\n");
        $finish;
    end

    wire signed [15:0] dut_re = m_axis_tdata[31:16];
    wire signed [15:0] dut_im = m_axis_tdata[15:0];
    
    reg [31:0] expected_data;
    reg signed [15:0] gold_re;
    reg signed [15:0] gold_im;

    always @(posedge clk) begin
        if (m_axis_tvalid && m_axis_tready) begin
            if (out_cnt < POINT) begin
                expected_data = golden_mem0[out_cnt];
            end else if (out_cnt < POINT*2) begin
                expected_data = golden_mem1[out_cnt - POINT];
            end
            
            gold_re = expected_data[31:16];
            gold_im = expected_data[15:0];
            if (m_axis_tdata !== expected_data) begin
                $display("[ERROR] Mismatch at #%0d (Stream %0d)", out_cnt, out_cnt/POINT);
                $display("    DUT Output: %h (Re:%d, Im:%d)", m_axis_tdata, dut_re, dut_im);
                $display("    Golden Ref: %h (Re:%d, Im:%d)", expected_data, gold_re, gold_im);
                err_cnt = err_cnt + 1;
            end else begin
                pass_cnt = pass_cnt + 1;
                if (out_cnt % 200 == 0) $display("[PASS] Index #%0d Matched.", out_cnt);
            end

            if (m_axis_tlast) begin
                $display("[INFO] TLAST detected at Index #%0d", out_cnt);
                if (!((out_cnt == POINT-1) || (out_cnt == 2*POINT-1))) begin
                    $display("[ERROR] Unexpected TLAST at Index %0d", out_cnt);
                    err_cnt = err_cnt + 1;
                end
            end else begin
                if ((out_cnt == POINT-1) || (out_cnt == 2*POINT-1)) begin
                    $display("[ERROR] Missing TLAST at Index %0d", out_cnt);
                    err_cnt = err_cnt + 1;
                end
            end
            
            out_cnt = out_cnt + 1;
            
            if (out_cnt == POINT*2) begin
                #(CLK_PERIOD * 10);
                $display("\n===========================================");
                $display(" [TEST FINISHED]");
                $display(" Total Received: %0d / %0d", out_cnt, POINT*2);
                $display(" Correct Matches : %0d", pass_cnt);
                $display(" Mismatches      : %0d", err_cnt);
                $display(" -------------------------------------------");
                
                if (pass_cnt == POINT*2 && err_cnt == 0)
                    $display(" RESULT: [TEST PASSED] AXI-Stream FFT OK!");
                else
                    $display(" RESULT: [TEST FAILED] Mismatch detected.");
                $display("===========================================\n");
                $finish;
            end
        end
    end

endmodule