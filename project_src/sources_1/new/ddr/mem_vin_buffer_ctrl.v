`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/06/20
// Design Name: songyuxin
// Module Name: mem_vin_buffer_ctrl
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


module mem_vin_buffer_ctrl #(
    parameter                               TCQ               = 0.1 ,  
    parameter                               ADDR_WIDTH        = 28  ,
    parameter                               DATA_WIDTH        = 64  ,
    parameter                               MEM_DATA_BITS     = 512 ,
    parameter                               BURST_LEN         = 64  ,
    parameter                               FRAME_DEPTH_WID   = 9   
)(
    // clk & rst 
    // input                                   xdma_user_clk_i         ,
    input                                   ddr_clk_i               ,
    input                                   ddr_rst_i               ,
    
    input                                   ddr_reset_flag_i        ,
    input                                   mem_vin_vld_i           ,
    input       [MEM_DATA_BITS-1:0]         mem_vin_data_i          ,
    output                                  mem_virtual_full_o      ,

    output      [FRAME_DEPTH_WID-1:0]       wr_frame_addr_o         ,
    input       [FRAME_DEPTH_WID-1:0]       rd_frame_addr_i         ,
    output                                  vin_fifo_almost_full_o  ,

    output                                  wr_ddr_req_o            , // 存储器接口：写请求 在写的过程中持续为1  
    output      [ 8-1:0]                    wr_ddr_len_o            , // 存储器接口：写长度
    output      [ADDR_WIDTH-1:0]            wr_ddr_addr_o           , // 存储器接口：写首地址 
    input                                   ddr_fifo_rd_req_i       , // 存储器接口：写数据数据读指示 ddr FIFO读使能, fwft
    output      [MEM_DATA_BITS - 1:0]       wr_ddr_data_o           , // 存储器接口：写数据
    input                                   wr_ddr_finish_i           // 存储器接口：本次写完成 
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

reg                             mem_virtual_full        = 'd0;

reg                             last_burst_state        = 'd0;
reg     [FRAME_DEPTH_WID-1:0]   wr_frame_addr           = 'd0;
reg     [11-1:0]                burst_line              = 'd0;

reg                             wr_ddr_req              = 'd0;  
reg     [ 8-1:0]                wr_ddr_len              = 'd0;  
reg     [ADDR_WIDTH-1:0]        wr_ddr_addr             = 'd0;

reg                             ddr_reset_flag          = 'd0;
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Wire Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
// wire    [ 8-1:0]                rd_frame_addr       ;
wire                            frame_last          ;

wire                            vin_fifo_full       ;
wire                            vin_fifo_empty      ;
wire    [10-1:0]                vin_data_count      ;

//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Instance Module
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
mem_buffer_fifo mem_vin_buffer_fifo_inst(
    .clk                    ( ddr_clk_i                     ),  // input wire clk
    .rst                    ( ddr_rst_i || ddr_reset_flag   ),  // input wire rst
    .din                    ( mem_vin_data_i                ),  // input wire [511 : 0] din
    .wr_en                  ( mem_vin_vld_i                 ),  // input wire wr_en
    .rd_en                  ( ddr_fifo_rd_req_i             ),  // input wire rd_en
    .dout                   ( wr_ddr_data_o                 ),  // output wire [511 : 0] dout
    .full                   ( vin_fifo_full                 ),  // output wire full
    .almost_full            ( vin_fifo_almost_full_o        ),  // output wire almost_full
    .empty                  ( vin_fifo_empty                ),  // output wire empty
    .data_count             ( vin_data_count                )   // output wire [9 : 0] data_count
);

// xpm_cdc_gray #(
//     .DEST_SYNC_FF(2),          // DECIMAL; range: 2-10
//     .INIT_SYNC_FF(0),          // DECIMAL; 0=disable simulation init values, 1=enable simulation init values
//     .REG_OUTPUT(1),            // DECIMAL; 0=disable registered output, 1=enable registered output
//     .SIM_ASSERT_CHK(0),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
//     .SIM_LOSSLESS_GRAY_CHK(0), // DECIMAL; 0=disable lossless check, 1=enable lossless check
//     .WIDTH(8)                  // DECIMAL; range: 2-32
//  )
//  rd_frame_addr_cdc_inst (
//     .dest_out_bin(rd_frame_addr),   // WIDTH-bit output: Binary input bus (src_in_bin) synchronized to
//                                     // destination clock domain. This output is combinatorial unless REG_OUTPUT
//                                     // is set to 1.

//     .dest_clk(ddr_clk_i),           // 1-bit input: Destination clock.
//     .src_clk(xdma_user_clk_i),      // 1-bit input: Source clock.
//     .src_in_bin(rd_frame_addr_i)    // WIDTH-bit input: Binary input bus that will be synchronized to the
//                                     // destination clock domain.

//  );

//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Logic Design
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
always @(posedge ddr_clk_i) begin
    if(ddr_reset_flag_i)
        ddr_reset_flag <= #TCQ 'd1;
    else if(burst_state==BURST_IDLE)
        ddr_reset_flag <= #TCQ 'd0;
end

`ifdef SIMULATE
assign frame_last = burst_line=='h2 && wr_ddr_req;  // the last burst req
`else
assign frame_last = burst_line=='h7ff && wr_ddr_req;  // the last burst req
`endif //SIMULATE

always @(posedge ddr_clk_i) begin
    if(ddr_rst_i || ddr_reset_flag)
        mem_virtual_full <= #TCQ 'd0;
    else if(mem_virtual_full && wr_frame_addr != rd_frame_addr_i)
        mem_virtual_full <= #TCQ 'd0;
    else if(~mem_virtual_full && ((wr_frame_addr+1'd1)==rd_frame_addr_i) && burst_state==BURST_FRAME_END)
        mem_virtual_full <= #TCQ 'd1;
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
    case(burst_state)
    
        BURST_IDLE:
                            /*如果FIFO有足够的数据则完成一次突发操作*/
                            if(vin_data_count >= BURST_LEN && ~mem_virtual_full)  //fifo中的数据>=128个, 且DDR非满
                                burst_state_next = BURST_FRAME_START; //开始突发
                            else
                                burst_state_next = BURST_IDLE;
                                        
        BURST_FRAME_START:
                            /*一次写操作开始*/
                            burst_state_next = BURSTING;
                                    
        BURSTING:
                            /*写DDR操作*/
                            if(wr_ddr_finish_i) //外部输入信号
                                burst_state_next = BURST_END;
                            else
                                burst_state_next = BURSTING;
                                
        BURST_END:
                            /*写操作完成时判断最后一次突发是否已经完全写入ddr，如果完成则进入空闲状态，等待下次突发*/
                            if(last_burst_state || ddr_reset_flag)
                                burst_state_next = BURST_FRAME_END;
                            else if(vin_data_count >= BURST_LEN) //等待fifo中数据为128个 开始突发128个数据
                                burst_state_next = BURSTING;
                            else
                                burst_state_next = BURST_END;
                                
        BURST_FRAME_END:
                            burst_state_next = BURST_IDLE;
                            
        default:
                            burst_state_next = BURST_IDLE;
    endcase
end

always@(posedge ddr_clk_i)begin
    wr_ddr_addr <= #TCQ {1'b0,wr_frame_addr[9-1:0],burst_line[11-1:0],9'd0};  // 通过burst line控制突发首地址, 共8MBytes
end

always @(posedge ddr_clk_i) begin  // frame addr 控制ddr分区
    if(ddr_rst_i || ddr_reset_flag)begin
        wr_frame_addr <= #TCQ 'd0;
    end
    else if(burst_state==BURST_FRAME_END)begin
        wr_frame_addr <= #TCQ wr_frame_addr + 1;
    end
end
always @(posedge ddr_clk_i) begin
    if(burst_state_next == BURST_FRAME_START)begin
        burst_line <= #TCQ 'd0;
    end
    else if(burst_state_next==BURST_END && burst_state==BURSTING)begin
        burst_line <= #TCQ burst_line + 1;
    end
end

always @(posedge ddr_clk_i) begin
    if(frame_last)begin
        last_burst_state <= #TCQ 'd1;
    end
    else if(burst_state==BURST_IDLE)begin
        last_burst_state <= #TCQ 'd0;
    end
end

always@(posedge ddr_clk_i)begin
    if(burst_state_next == BURSTING && burst_state != BURSTING)begin
        // if(last_burst_state)
        //     wr_ddr_len <= #TCQ last_burst_num;
        // else
            wr_ddr_len <= #TCQ BURST_LEN;
    end
end

always@(posedge ddr_clk_i)begin
    if(burst_state_next == BURSTING && burst_state != BURSTING)
        wr_ddr_req <= #TCQ 1'b1;
    else if(wr_ddr_finish_i  || ddr_fifo_rd_req_i || burst_state == BURST_IDLE) // ddr 仲裁响应后拉低
        wr_ddr_req <= #TCQ 1'b0;
end

// output burst line and last number, once frame number
// always @(posedge ddr_clk_i) begin
//     if(burst_state==BURST_FRAME_END)begin
//         frame_last_flag      <= #TCQ 'd1;
//         frame_last_burst_num <= #TCQ last_burst_data_num_d;
//         frame_burst_num      <= #TCQ burst_line;
//     end
//     else begin
//         frame_last_flag      <= #TCQ 'd0;
//     end
// end

assign mem_virtual_full_o       = mem_virtual_full;
assign wr_ddr_req_o             = wr_ddr_req  ;
assign wr_ddr_len_o             = wr_ddr_len  ;
assign wr_ddr_addr_o            = wr_ddr_addr ;
assign wr_frame_addr_o          = wr_frame_addr  ;
// assign frame_last_flag_o        = frame_last_flag;
// assign frame_last_burst_num_o   = frame_last_burst_num;
// assign frame_burst_num_o        = frame_burst_num     ;
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


endmodule
