`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: zas
// Engineer: songyuxin
// 
// Create Date: 2023/06/27
// Design Name: base module
// Module Name: handshake
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


module handshake #(
    parameter                       TCQ         = 0.1 ,
    parameter                       DATA_WIDTH  = 32
)(
    // clk & rst
    input   wire                    src_clk_i       ,
    input   wire                    src_rst_i       ,
    input   wire                    dest_clk_i      ,
    input   wire                    dest_rst_i      ,
    
    input   wire  [DATA_WIDTH-1:0]  src_data_i      ,
    input   wire                    src_vld_i       ,

    output  reg   [DATA_WIDTH-1:0]  dest_data_o     ,
    output  reg                     dest_vld_o      
);


//////////////////////////////////////////////////////////////////////////////////
// *********** Define Parameter Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Register Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

reg [DATA_WIDTH-1:0]    handshake_data  = 'd0;
reg [2-1:0]             src_ff          = 'd0;
reg                     handshake_flag  = 'd0;
reg [2-1:0]             dest_ff         = 'd0;

//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<



//////////////////////////////////////////////////////////////////////////////////
// *********** Define Wire Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>


//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<





//////////////////////////////////////////////////////////////////////////////////
// *********** Instance Module
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>


always @(posedge src_clk_i) begin
    if(src_rst_i)
        handshake_data <= #TCQ 'd0;
    else if(src_vld_i)begin
        handshake_data <= #TCQ src_data_i;
    end
end

always @(posedge src_clk_i) begin
    if(src_rst_i)
        src_ff <= #TCQ 'd0;
    else 
        src_ff <= #TCQ {src_ff[0],src_vld_i};
end

always @(posedge src_clk_i) begin
    if(src_ff[1])
        handshake_flag <= #TCQ 'd1;
    else if(dest_ff[1])
        handshake_flag <= #TCQ 'd0;
end

always @(posedge dest_clk_i) begin
    if(dest_rst_i)
        dest_ff <= #TCQ 'd0;
    else
        dest_ff <= #TCQ {dest_ff[0],handshake_flag};
end

always @(posedge dest_clk_i) begin
    if(dest_ff==2'b01)begin
        dest_data_o <= #TCQ handshake_data;
    end
end

always @(posedge dest_clk_i) begin
    dest_vld_o <= #TCQ dest_ff==2'b01;
end
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


//////////////////////////////////////////////////////////////////////////////////
// *********** Logic Design
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>


//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


endmodule
