`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/05/22
// Design Name: 
// Module Name: reset_generate
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module reset_generate(
    input       nrst_i              ,

    input       clk_100m            ,
    output reg  rst_100m            ,
    
    input       ddr_ui_clk          ,
    output reg  ddr_rst             ,

    input       clk_50m             ,
    output reg  gt_rst              ,

    input       hmc7044_config_ok   ,

    input       aurora_log_clk_1    ,
    input       aurora_log_clk_2    ,
    input       aurora_log_clk_3    ,
    input       aurora_log_clk_4    ,
    output reg  aurora_rst_1        ,
    output reg  aurora_rst_2        ,
    output reg  aurora_rst_3        ,
    output reg  aurora_rst_4        
);

reg [15:0]      rst_100m_cnt = 'd0;
always @(posedge clk_100m) begin
    if(!nrst_i) begin
        rst_100m         <= 'd1;
        rst_100m_cnt     <= 'd0;
    end
    else if(rst_100m_cnt == 'd10000) begin        //100us
        rst_100m_cnt     <= rst_100m_cnt;
        rst_100m         <= 'd0;
    end
    else begin
        rst_100m         <= 'd1;
        rst_100m_cnt     <= rst_100m_cnt + 1'b1;
    end
end


reg [3:0]       ddr_rst_cnt = 'd0;
always @(posedge ddr_ui_clk) begin
    if(rst_100m) begin
        ddr_rst_cnt    <= 'd0;
        ddr_rst        <= 'b1;
    end
    else if(ddr_rst_cnt[3]) begin
        ddr_rst_cnt    <= ddr_rst_cnt;
        ddr_rst        <= 'b0;
    end
    else begin
        ddr_rst_cnt    <= ddr_rst_cnt + 'd1;
        ddr_rst        <= 'b1;
    end
end

reg [7:0]       aurora_rst_2_cnt = 'd0;
always @(posedge aurora_log_clk_2) begin
    if(~hmc7044_config_ok) begin
        aurora_rst_2_cnt    <= 'd0;
        aurora_rst_2        <= 'b1;
    end
    // else if(~hmc7044_config_ok) begin
    //     aurora_rst_2_cnt    <= 'd0;
    //     aurora_rst_2        <= 'b1;
    // end
    else if(aurora_rst_2_cnt[7]) begin
        aurora_rst_2_cnt<= aurora_rst_2_cnt;
        aurora_rst_2    <= 'b0;
    end
    else begin
        aurora_rst_2_cnt<= aurora_rst_2_cnt + 'd1;
        aurora_rst_2    <= 'b1;
    end
end

reg [7:0]       aurora_rst_3_cnt  = 'd0;
always @(posedge aurora_log_clk_3) begin
    if(~hmc7044_config_ok) begin
        aurora_rst_3_cnt    <= 'd0;
        aurora_rst_3        <= 'b1;
    end
    // else if(~hmc7044_config_ok) begin
    //     aurora_rst_3_cnt    <= 'd0;
    //     aurora_rst_3        <= 'b1;
    // end
    else if(aurora_rst_3_cnt[7]) begin
        aurora_rst_3_cnt    <= aurora_rst_3_cnt;
        aurora_rst_3        <= 'b0;
    end
    else begin
        aurora_rst_3_cnt    <= aurora_rst_3_cnt + 'd1;
        aurora_rst_3        <= 'b1;
    end
end

reg [7:0] aurora_rst_1_cnt = 'd0;
always @(posedge aurora_log_clk_1) begin
    if(~hmc7044_config_ok) begin
        aurora_rst_1_cnt    <= 'd0;
        aurora_rst_1        <= 'b1;
    end
    // else if(~hmc7044_config_ok) begin
    //     aurora_rst_1_cnt    <= 'd0;
    //     aurora_rst_1        <= 'b1;
    // end
    else if(aurora_rst_1_cnt[7]) begin
        aurora_rst_1_cnt    <= aurora_rst_1_cnt;
        aurora_rst_1        <= 'b0;
    end
    else begin
        aurora_rst_1_cnt    <= aurora_rst_1_cnt + 'd1;
        aurora_rst_1        <= 'b1;
    end
end

reg [7:0]   gt_rst_cnt = 'd0;
always @(posedge clk_50m) begin
    if(~hmc7044_config_ok) begin
        gt_rst      <= 'd1;
        gt_rst_cnt  <= 'd0;
    end
    else if(gt_rst_cnt[4]) begin
        gt_rst_cnt  <= gt_rst_cnt;
        gt_rst      <= 'd0;
    end
    else begin
        gt_rst      <= 'd1;
        gt_rst_cnt  <= gt_rst_cnt + 1'b1;
    end
end


endmodule