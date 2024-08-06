`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/06/25
// Design Name: songyuxin
// Module Name: mem_vout_buffer_ctrl
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


module mem_vout_buffer_ctrl #(
    parameter                               TCQ               = 0.1 ,  
    parameter                               ADDR_WIDTH        = 28  ,
    parameter                               DATA_WIDTH        = 64  ,
    parameter                               MEM_DATA_BITS     = 512 ,
    parameter                               BURST_LEN         = 64  ,
    parameter                               FRAME_DEPTH_WID   = 8   
)(
    // clk & rst 
    input                                   xdma_user_clk_i         ,
    input                                   xdma_rst_i              ,
    input                                   ddr_clk_i               ,
    input                                   ddr_rst_i               ,

    input                                   burst_flag_i            ,
    input       [FRAME_DEPTH_WID-1:0]       frame_addr_i            ,
    input       [11-1:0]                    burst_line_i            ,

    output                                  ddr_fifo_empty_o        ,
    input                                   ddr_fifo_rd_en_i        ,
    output      [MEM_DATA_BITS-1:0]         ddr_fifo_rd_data_o      ,

    output                                  rd_ddr_req_o            ,
    output      [ 8-1:0]                    rd_ddr_len_o            ,
    output      [ADDR_WIDTH-1:0]            rd_ddr_addr_o           ,
    input                                   rd_ddr_data_valid_i     ,
    input       [MEM_DATA_BITS - 1:0]       rd_ddr_data_i           ,
    input                                   rd_ddr_finish_i          
    
);

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Parameter Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
localparam                      BURST_IDLE              = 3'd0;    
localparam                      BURST_FRAME_START       = 3'd1;    
localparam                      BURSTING                = 3'd2;
localparam                      BURST_END               = 3'd3;    
localparam                      BURST_FRAME_END         = 3'd4;    
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Register Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
reg     [ 3-1:0]                burst_state             = BURST_IDLE;
reg     [ 3-1:0]                burst_state_next        = BURST_IDLE;

reg                             burst_flag_d0           = 'd0;
reg                             burst_flag_d1           = 'd0;
reg                             burst_flag_latch        = 'd0;
reg     [FRAME_DEPTH_WID-1:0]   frame_addr              = 'd0;
reg     [11-1:0]                burst_line              = 'd0;

reg                             rd_ddr_req              = 'd0;  
reg     [ 8-1:0]                rd_ddr_len              = 'd0;  
reg     [ADDR_WIDTH-1:0]        rd_ddr_addr             = 'd0;
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Wire Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
wire                            ddr_fifo_full       ;
wire    [ 9-1:0]                wr_data_count       ;

//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Instance Module
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
mem_vout_buffer_fifo mem_vout_buffer_fifo_inst(
    .rst                    ( xdma_rst_i                ),
    .wr_clk                 ( ddr_clk_i                 ),
    .rd_clk                 ( xdma_user_clk_i           ),
    .din                    ( rd_ddr_data_i             ),
    .wr_en                  ( rd_ddr_data_valid_i       ),
    .rd_en                  ( ddr_fifo_rd_en_i          ),
    .dout                   ( ddr_fifo_rd_data_o        ),
    .full                   ( ddr_fifo_full             ),
    .empty                  ( ddr_fifo_empty_o          ),
    .wr_data_count          ( wr_data_count             ),
    .sbiterr                ( ),
    .dbiterr                ( )
);
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Logic Design
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
always @(posedge ddr_clk_i) begin
    burst_flag_d0 <= #TCQ burst_flag_i;
    burst_flag_d1 <= #TCQ burst_flag_d0;
end

always @(posedge ddr_clk_i)begin
    if(~burst_flag_d1 && burst_flag_d0)
        burst_flag_latch <= #TCQ 'd1;
    else if(burst_state==BURST_END)
        burst_flag_latch <= #TCQ 'd0;
end 

always @(posedge ddr_clk_i) begin
    if(~burst_flag_d1 && burst_flag_d0)begin
        frame_addr      <= #TCQ frame_addr_i;
        burst_line      <= #TCQ burst_line_i;
    end
end

always@(posedge ddr_clk_i)
begin
    if(ddr_rst_i)
        burst_state <= #TCQ BURST_IDLE;
    else
        burst_state <= #TCQ burst_state_next;
end

always@(*)
begin
    burst_state_next = burst_state;
    case(burst_state)
        BURST_IDLE:
            if(burst_flag_latch)
                burst_state_next = BURST_FRAME_START;
        BURST_FRAME_START:
            if(wr_data_count < 'h1ff - BURST_LEN[7:0])  //  判断fifo空间
            // if(ddr_fifo_empty_o && ~ddr_fifo_full)   //  fifo reset finish
                burst_state_next = BURSTING;
        BURSTING: //  完成一次突发读操作
            if(rd_ddr_finish_i) //外部输入信号
                burst_state_next = BURST_END;
        BURST_END:
            // if(burst_line == 'h800)
                burst_state_next = BURST_FRAME_END;
            // else if(wr_data_count < 8'hff - BURST_LEN[7:0])/
            //     burst_state_next = BURSTING;
        BURST_FRAME_END:
                burst_state_next = BURST_IDLE;
        default:
            burst_state_next = BURST_IDLE;
    endcase
end

always@(posedge ddr_clk_i)begin
    rd_ddr_addr <= #TCQ {1'b0,frame_addr[9-1:0],burst_line[11-1:0],9'd0};  // 通过burst line控制突发首地址
end

// always @(posedge ddr_clk_i) begin
//     if(burst_state_next == BURST_FRAME_START)begin
//         burst_line <= #TCQ 'd0;
//     end
//     else if(burst_state_next==BURST_END && burst_state==BURSTING)begin
//         burst_line <= #TCQ burst_line + 1;
//     end
// end

always@(posedge ddr_clk_i)begin
    if(burst_state_next == BURSTING && burst_state != BURSTING)begin
        // if(burst_line == frame_burst_num-1)
        //     rd_ddr_len <= #TCQ last_burst_num;
        // else
            rd_ddr_len <= #TCQ BURST_LEN;
    end
end

always@(posedge ddr_clk_i)begin
    if(burst_state_next == BURSTING && burst_state != BURSTING)
        rd_ddr_req <= #TCQ 1'b1;
    else if(rd_ddr_finish_i || rd_ddr_data_valid_i || burst_state == BURST_IDLE)
        rd_ddr_req <= #TCQ 1'b0;
end


assign rd_ddr_req_o             = rd_ddr_req  ;
assign rd_ddr_len_o             = rd_ddr_len  ;
assign rd_ddr_addr_o            = rd_ddr_addr ;
// assign frame_burst_end_o        = burst_state == BURST_FRAME_END;
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


endmodule
