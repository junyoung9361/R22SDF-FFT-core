`timescale 1ns / 1ps

module tb_fft_core;
    parameter CLK_PERIOD = 10;
    parameter DWIDTH     = 32;
    parameter MAX_POINT  = 1024;

    reg clk, reset;
    
    // DUT Control Interface
    reg [10:0] i_point;
    reg        i_inverse;
    reg        i_start;
    reg [9:0]  i_burst;
    wire       o_done;

    // AXI-Stream Interface
    reg [DWIDTH-1:0] s_axis_tdata;
    reg              s_axis_tvalid;
    wire             s_axis_tready;
    reg              s_axis_tlast;
    
    wire [DWIDTH-1:0] m_axis_tdata;
    wire              m_axis_tvalid;
    reg               m_axis_tready;
    wire              m_axis_tlast;

    reg [31:0] input_mem  [0:MAX_POINT-1]; 
    reg [31:0] golden_mem [0:MAX_POINT-1];

    integer test_case_idx;
    integer pass_cnt, err_cnt;
    integer cur_point;

    fft_core #(.DWIDTH(DWIDTH)) u_dut (
        .clk(clk),
        .reset(reset),
        .i_inverse(i_inverse),
        .i_point(i_point),
        .i_start(i_start),
        .i_burst(i_burst),
        .o_done(o_done),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast)
    );

    // Clock Generation
    initial begin clk = 0; forever #(CLK_PERIOD/2) clk = ~clk; end

    // --- [Main Test Loop (While문 역할)] ---
    initial begin
        // 초기화
        reset = 1; i_start = 0; s_axis_tvalid = 0; m_axis_tready = 1;
        pass_cnt = 0; err_cnt = 0;
        #(CLK_PERIOD * 10);
        reset = 0;
        #(CLK_PERIOD * 5);

        // 시나리오 반복 실행 (C의 while문과 동일)
        for (test_case_idx = 0; test_case_idx < 4; test_case_idx = test_case_idx + 1) begin
            $display("\n[CASE #%0d] Starting New Test Scenario...", test_case_idx);
            
            // 1. 시나리오별 설정 및 파일 로드 (여기서 원하는 세팅을 바꿉니다)
            case(test_case_idx)
                0: begin
                    cur_point = 1024;
                    i_point = 11'b100_0000_0000;
                    i_inverse = 0;
                    i_burst = 1;
                    $readmemh("input_data_constant_1024.hex", input_mem);
                    $readmemh("output_data_constant_1024.hex", golden_mem);
                end
                1: begin                    
                    cur_point = 512;
                    i_point = 11'b010_0000_0000;
                    i_inverse = 0; i_burst = 1;
                    $readmemh("input_data_nomarlized_fix_512.hex", input_mem);
                    $readmemh("output_data_nomarlized_fix_512.hex", golden_mem);
                end
                2: begin
                    cur_point = 1024; i_point = 11'b100_0000_0000;
                    i_inverse = 1;
                    i_burst = 1;
                    $readmemh("input_data_impulse_1024.hex", input_mem);
                    $readmemh("output_data_impulse_1024.hex", golden_mem);
                end
                3: begin
                    cur_point = 1024;
                    i_point = 11'b100_0000_0000;
                    i_inverse = 1;
                    i_burst = 1;
                    $readmemh("input_data_impulse_1024.hex", input_mem);
                    $readmemh("output_data_impulse_1024.hex", golden_mem);
                end
            endcase

            @(posedge clk);
            i_start = 1;
            #(CLK_PERIOD);
            i_start = 0;

            fork
                begin
                    integer p;
                    for (p = 0; p < cur_point; p = p + 1) begin
                        @(posedge clk);
                        while (!s_axis_tready) @(posedge clk);
                        s_axis_tvalid = 1;
                        s_axis_tdata  = input_mem[p];
                        s_axis_tlast  = (p == cur_point - 1);
                    end
                    @(posedge clk);
                    s_axis_tvalid = 0; s_axis_tlast = 0;
                end
                
                begin
                    wait(o_done);
                    $display("[CASE #%0d] Done Signal Detected!", test_case_idx);
                end
            join

            #(CLK_PERIOD * 20);
        end

        $display("\n===========================================");
        $display(" ALL TEST SCENARIOS FINISHED");
        $display(" Total Matches: %0d, Total Errors: %0d", pass_cnt, err_cnt);
        $display("===========================================");
        $finish;
    end

    integer out_ptr = 0;
    always @(posedge clk) begin
        if (reset) begin
            out_ptr <= 0;
        end else if (m_axis_tvalid && m_axis_tready) begin
            if (m_axis_tdata !== golden_mem[out_ptr]) begin
                $display("[ERR] Case:%0d, Idx:%0d | DUT:%h, GOLD:%h", test_case_idx, out_ptr, m_axis_tdata, golden_mem[out_ptr]);
                err_cnt = err_cnt + 1;
            end else begin
                pass_cnt = pass_cnt + 1;
            end
            
            if (m_axis_tlast) out_ptr <= 0;
            else              out_ptr <= out_ptr + 1;
        end
    end

endmodule