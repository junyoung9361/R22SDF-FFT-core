module controller (
    input         clk,
    input         reset,

    // PS control signal
    input         i_start,
    input  [9:0]  i_burst,
    input  [10:0] i_point,

    // Slave signal
    input         s_axis_tlast,
    input         s_axis_tvalid,
    output        s_axis_tready,

    // Master signal
    input         m_axis_tready,
    input         m_axis_tvalid,
    input         m_axis_tlast,
    output [10:0] o_point

);

    localparam S_IDLE = 2'b00;
    localparam S_LOAD = 2'b01;
    localparam S_RUN  = 2'b10;
    localparam S_DONE = 2'b11;

    reg [1:0] cs, ns;
    reg       r_stat_d;
    reg [9:0] r_cnt;
    wire      w_start_pulse = i_start & ~r_start_d;

    always@(posedge clk) begin
        if(reset)
            cs <= S_IDLE;
        else
            cs <= ns;
    end

    always@(*) begin
        case(cs)
            S_IDLE : ns = (w_start_pulse) ? S_RUN : S_IDLE;
            S_LOAD : ns = (s_axis_tvalid && s_axis_tready && s_axis_tlast && (r_in_cnt  == r_burst)) ? S_RUN : S_LOAD;
            S_RUN  : ns = (m_axis_tvalid && m_axis_tready && m_axis_tlast && (r_out_cnt == r_burst)) ? S_DONE : S_RUN;
            S_DONE : ns = S_IDLE;
            default: ns = S_IDLE;
        endcase
    end

    always@(posedge clk) begin
        if(reset)
            r_in_cnt <= 10'b0;
        else if(r_cnt == r_burst)
            r_in_cnt <= 10'b0;
        else if(cs == S_LOAD && m_axis_tvalid && m_axis_tready && m_axis_tlast)
            r_in_cnt <= r_cnt + 1'b1;
        else    
            r_in_cnt <= r_cnt;
    end

    always@(posedge clk) begin
        if(reset)
            r_out_cnt <= 10'b0;
        else if(r_cnt == r_burst)
            r_out_cnt <= 10'b0;
        else if(cs == S_RUN && m_axis_tvalid && m_axis_tready && m_axis_tlast)
            r_out_cnt <= r_cnt + 1'b1;
        else    
            r_out_cnt <= r_cnt;
    end

    always@(posedge clk) begin
        if(reset)
            r_stat_d <= 1'b0;
        else
            r_stat_d <= i_start;
    end

    always@(posedge clk) begin
        if(reset) begin
            r_point <= 11'b0;
            r_burst <= 10'b0;
        end else if(cs == S_DONE) begin
            r_point <= 11'b0;
            r_burst <= 10'b0;
        end else if(w_start_pulse) begin
            r_point <= i_point;
            r_burst <= i_burst;
        end else begin
            r_point <= r_point;
            r_burst <= r_burst;
        end
    end

    assign o_point = r_point;
    assign s_axis_tready = (cs == S_LOAD);

endmodule