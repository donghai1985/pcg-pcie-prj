`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: zas
// Engineer: songyuxin
// 
// Create Date: 2023/05/18
// Design Name: PCG
// Module Name: message_comm_tx
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


module widen_enable #(
    parameter                       TCQ         = 0.1   ,
    parameter   [1-1:0]             WIDEN_TYPE  = 1'b1  ,  // 1 = posedge lock
    parameter                       WIDEN_NUM   = 1     
)(
    // clk & rst
    input   wire                    clk_i               ,
    input   wire                    rst_i               ,

    input   wire                    src_signal_i        ,
    output  wire                    dest_signal_o           
);

localparam                          WIDEN_NUM_WIDTH     = $clog2(WIDEN_NUM);

reg         [WIDEN_NUM_WIDTH-1:0]   widen_cnt           = 'd0;
reg                                 src_signal_d        = 'd0;
reg                                 widen_flag          = 'd0;
reg                                 dest_signal         = 'd0;

wire                                src_signal_pose     ;
wire                                src_signal_nege     ;

always @(posedge clk_i) src_signal_d <= src_signal_i;
assign src_signal_pose = ~src_signal_d && src_signal_i;
assign src_signal_nege =  src_signal_d && ~src_signal_i;

always @(posedge clk_i) begin
    if(rst_i)
        widen_flag <= #TCQ 'd0;
    else if((src_signal_pose && WIDEN_TYPE) || (src_signal_nege && ~WIDEN_TYPE))
        widen_flag <= #TCQ 'd1;
    else if(widen_cnt == WIDEN_NUM -1)
        widen_flag <= #TCQ 'd0;
end

always @(posedge clk_i) begin
    if(widen_flag)
        widen_cnt <= #TCQ widen_cnt + 1;
    else 
        widen_cnt <= #TCQ 'd0;
end

always @(posedge clk_i) begin
    if((src_signal_pose && WIDEN_TYPE) || (src_signal_nege && ~WIDEN_TYPE))
        dest_signal <= #TCQ src_signal_i;
    else if(widen_cnt == WIDEN_NUM -1)
        dest_signal <= #TCQ ~dest_signal;
end

assign dest_signal_o = dest_signal;
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


endmodule
