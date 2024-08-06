`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: zas
// Engineer: songyuxin
// 
// Create Date: 2023/09/12
// Design Name: PCG
// Module Name: xdma_vin_ctrl
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


module xdma_vin_ctrl #(
    parameter                               TCQ               = 0.1 ,
    parameter                               ADDR_WIDTH        = 30  ,
    parameter                               DATA_WIDTH        = 32  ,
    parameter                               MEM_DATA_BITS     = 256 ,
    parameter                               BURST_LEN         = 128 ,
    parameter                               FRAME_DEPTH_WID   = 9   
)(
    // clk & rst
    input                                   xdma_user_clk_i         ,
    input                                   sys_clk_i               ,
    input                                   sys_rst_i               ,
    input                                   ddr_clk_i               ,
    input                                   ddr_rst_i               ,

    // up data signals
    // input                                   eds_rx_start_i          ,
    // input                                   eds_rx_end_i            ,
    // output                                  pcie_eds_rx_end_o       ,
    // input                                   pmt_rx_start_i          ,
    // input                                   pmt_rx_end_i            ,
    // output                                  pcie_pmt_rx_end_o       ,
    // input                                   fbc_rx_start_i          ,
    // input                                   fbc_rx_end_i            ,
    // output                                  pcie_fbc_rx_end_o       ,
    input                                   aurora_wr_start_i       ,  // 三路数据传输合并成一路
    input                                   aurora_wr_en_i          ,
    input       [512-1:0]                   aurora_wr_data_i        ,
    input                                   xdma_err_reset_i        ,

    output      [32-1:0]                    pmt_lose_pack_cnt_o     ,
    output      [32-1:0]                    pmt_lose_pack_mem_cnt_o ,
    output      [32-1:0]                    wr_frame_cnt_o          ,
    output      [32-1:0]                    rd_frame_cnt_o          ,
    output      [32-1:0]                    err_state_cnt_o         ,
    output      [32-1:0]                    ddr_last_pack_cnt_o     ,
    output      [32-1:0]                    ddr_usage_max_o         ,

    output                                  ddr_reset_flag_o        ,
    output      [FRAME_DEPTH_WID-1:0]       wr_frame_addr_o         ,
    input       [FRAME_DEPTH_WID-1:0]       rd_frame_addr_i         ,

    output                                  wr_ddr_req_o            ,
    output      [ 8-1:0]                    wr_ddr_len_o            ,
    output      [ADDR_WIDTH-1:0]            wr_ddr_addr_o           ,
    input                                   ddr_fifo_rd_req_i       ,
    output      [MEM_DATA_BITS - 1:0]       wr_ddr_data_o           ,
    input                                   wr_ddr_finish_i          
);

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Parameter Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
localparam              DMA_SIZE                = 8388608;      //32'h800000 ,8MBytes
localparam              PCK_PAYLOAD_SIZE        = 24'd8388592;  //DMA_SIZE - 16Bytes
// localparam              PCK_PAYLOAD_SIZE_DIV16  = 32'd524288;   //DMA_SIZE / 16Bytes  , 128bits
localparam              PCK_PAYLOAD_SIZE_DIV64  = 32'd131072;   //DMA_SIZE / 64Bytes   , 512bits

localparam  [512-1:0]   ERR_TYPE_DATA           = {8{64'h8000_0000_0000_0000}};
localparam  [64-1:0]    LAST_VLD_TYPE_DATA      = {64'hA5A5_DADA_FFFF_0000};
localparam  [512-1:0]   LAST_TYPE_DATA          = {128'h5A5A_DEAD_0000_FFFF_5A5A_DEAD_0000_FFFF,{6{64'h8000_0000_0000_0000}}};

localparam              PCK_CNT                 = $clog2(PCK_PAYLOAD_SIZE_DIV64)+1;

localparam  [7-1:0]     UP_IDLE                 = 'b000_0001; //up_state[0]
localparam  [7-1:0]     UP_AURORA_PCK           = 'b000_0010; //up_state[1]
localparam  [7-1:0]     UP_CHECK                = 'b000_0100; //up_state[2]
localparam  [7-1:0]     UP_LAST                 = 'b000_1000; //up_state[3]
localparam  [7-1:0]     UP_ERR_PCK              = 'b001_0000; //up_state[4]
localparam  [7-1:0]     UP_END_WAIT             = 'b010_0000; //up_state[5]
localparam  [7-1:0]     UP_ERR_LAST             = 'b100_0000; //up_state[6]
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Register Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
(*mark_debug = "true"*)reg     [7-1:0]         up_state                = UP_IDLE;
(*mark_debug = "true"*)reg     [7-1:0]         up_next_state           = UP_IDLE;

reg                     aurora_wr_start_d0      = 'd0;
reg                     aurora_wr_start_d1      = 'd0;
(*mark_debug = "true"*)reg                     aurora_wr_start_flag    = 'd0;

reg                     up_state_reset_d0       = 'd0;
reg                     up_state_reset_d1       = 'd0;
reg                     up_state_reset_flag     = 'd0;

reg                     mem_vin_vld             = 'd0;
reg     [511:0]         mem_vin_data            = 'd0;
reg     [PCK_CNT-1:0]   rx_cnt                  = 'd0;
reg     [PCK_CNT-1:0]   last_rx_vld_num         = 'd0;
reg     [16-1:0]        xdma_pack_num           = 'd0;

reg                     xdma_vin_ddr_vaild      = 'd0;
reg                     ddr_reset_flag          = 'd0;
reg     [5-1:0]         ddr_reset_cnt           = 'd0;
(*ASYNC_REG = "true"*)reg                     ddr_reset_flag_d0       = 'd0;
(*ASYNC_REG = "true"*)reg                     ddr_reset_flag_d1       = 'd0;
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Wire Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
wire                    up_state_reset          ;
wire                    err_reset               ;
wire                    vin_fifo_almost_full    ;
wire                    mem_vin_wr              ;
wire                    up_vld_pck_end          ;
wire                    up_invld_pck_end        ;
wire                    mem_virtual_full        ;

wire                    aurora_wr_start_pose    ;
wire                    aurora_wr_start_nege    ;
wire                    up_state_reset_pose     ;

wire                    xdma_vin_ddr_almost_full;
wire                    xdma_vin_ddr_full       ;
wire                    xdma_vin_ddr_empty      ;
wire                    xdma_vin_ddr_rd_en      ;
wire    [512-1:0]       xdma_vin_ddr_dout       ;

wire    [FRAME_DEPTH_WID-1:0]   rd_frame_addr           ;
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Instance Module
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

xpm_cdc_pulse #(
    .DEST_SYNC_FF(2),   // DECIMAL; range: 2-10
    .INIT_SYNC_FF(1),   // DECIMAL; 0=disable simulation init values, 1=enable simulation init values
    .REG_OUTPUT(0),     // DECIMAL; 0=disable registered output, 1=enable registered output
    .RST_USED(1),       // DECIMAL; 0=no reset, 1=implement reset
    .SIM_ASSERT_CHK(0)  // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
 )
 xpm_cdc_pulse_inst (
    .dest_pulse(err_reset), // 1-bit output: Outputs a pulse the size of one dest_clk period when a pulse
                             // transfer is correctly initiated on src_pulse input. This output is
                             // combinatorial unless REG_OUTPUT is set to 1.

    .dest_clk(sys_clk_i),     // 1-bit input: Destination clock.
    .dest_rst(1'd0),     // 1-bit input: optional; required when RST_USED = 1
    .src_clk(xdma_user_clk_i),       // 1-bit input: Source clock.
    .src_pulse(xdma_err_reset_i),   // 1-bit input: Rising edge of this signal initiates a pulse transfer to the
                             // destination clock domain. The minimum gap between each pulse transfer must be
                             // at the minimum 2*(larger(src_clk period, dest_clk period)). This is measured
                             // between the falling edge of a src_pulse to the rising edge of the next
                             // src_pulse. This minimum gap will guarantee that each rising edge of src_pulse
                             // will generate a pulse the size of one dest_clk period in the destination
                             // clock domain. When RST_USED = 1, pulse transfers will not be guaranteed while
                             // src_rst and/or dest_rst are asserted.

    .src_rst(1'd0)        // 1-bit input: optional; required when RST_USED = 1
 );

 xpm_cdc_gray #(
    .DEST_SYNC_FF(2),          // DECIMAL; range: 2-10
    .INIT_SYNC_FF(0),          // DECIMAL; 0=disable simulation init values, 1=enable simulation init values
    .REG_OUTPUT(1),            // DECIMAL; 0=disable registered output, 1=enable registered output
    .SIM_ASSERT_CHK(0),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
    .SIM_LOSSLESS_GRAY_CHK(0), // DECIMAL; 0=disable lossless check, 1=enable lossless check
    .WIDTH(FRAME_DEPTH_WID)                  // DECIMAL; range: 2-32
 )
 rd_frame_addr_cdc_inst (
    .dest_out_bin(rd_frame_addr),   // WIDTH-bit output: Binary input bus (src_in_bin) synchronized to
                                    // destination clock domain. This output is combinatorial unless REG_OUTPUT
                                    // is set to 1.

    .dest_clk(ddr_clk_i),           // 1-bit input: Destination clock.
    .src_clk(xdma_user_clk_i),      // 1-bit input: Source clock.
    .src_in_bin(rd_frame_addr_i)    // WIDTH-bit input: Binary input bus that will be synchronized to the
                                    // destination clock domain.

 );

xdma_vin_ddr xdma_vin_ddr_inst (
    .rst                            ( sys_rst_i || ddr_reset_flag),  // input wire rst
    .wr_clk                         ( sys_clk_i                 ),  // input wire wr_clk
    .rd_clk                         ( ddr_clk_i                 ),  // input wire rd_clk
    .din                            ( mem_vin_data              ),  // input wire [511 : 0] din
    .wr_en                          ( mem_vin_vld               ),  // input wire wr_en
    .rd_en                          ( xdma_vin_ddr_rd_en        ),  // input wire rd_en
    .dout                           ( xdma_vin_ddr_dout         ),  // output wire [511 : 0] dout
    .almost_full                    ( xdma_vin_ddr_almost_full  ),
    .full                           ( xdma_vin_ddr_full         ),  // output wire full
    .empty                          ( xdma_vin_ddr_empty        )   // output wire empty
);

assign xdma_vin_ddr_rd_en = ~vin_fifo_almost_full && ~xdma_vin_ddr_empty;

always @(posedge ddr_clk_i) begin
    xdma_vin_ddr_vaild <= #TCQ xdma_vin_ddr_rd_en;
end


mem_vin_buffer_ctrl #(
    .ADDR_WIDTH                     ( ADDR_WIDTH                ),
    .DATA_WIDTH                     ( DATA_WIDTH                ),
    .MEM_DATA_BITS                  ( MEM_DATA_BITS             ),
    .BURST_LEN                      ( BURST_LEN                 ),
    .FRAME_DEPTH_WID                ( FRAME_DEPTH_WID           )
)mem_vin_buffer_ctrl_inst(
    // clk & rst
    // .xdma_user_clk_i                ( xdma_user_clk_i           ),
    .ddr_clk_i                      ( ddr_clk_i                 ),
    .ddr_rst_i                      ( ddr_rst_i                 ),

    .ddr_reset_flag_i               ( ddr_reset_flag_d1         ),
    .mem_vin_vld_i                  ( xdma_vin_ddr_vaild        ),
    .mem_vin_data_i                 ( xdma_vin_ddr_dout         ),
    .vin_fifo_almost_full_o         ( vin_fifo_almost_full      ),
    .mem_virtual_full_o             ( mem_virtual_full          ),

    .wr_frame_addr_o                ( wr_frame_addr_o           ),
    .rd_frame_addr_i                ( rd_frame_addr             ),

    .wr_ddr_req_o                   ( wr_ddr_req_o              ), // 存储器接口：写请求 在写的过程中持续为1  
    .wr_ddr_len_o                   ( wr_ddr_len_o              ), // 存储器接口：写长度
    .wr_ddr_addr_o                  ( wr_ddr_addr_o             ), // 存储器接口：写首地址 
    .ddr_fifo_rd_req_i              ( ddr_fifo_rd_req_i         ), // 存储器接口：写数据数据读指示 ddr FIFO读使能
    .wr_ddr_data_o                  ( wr_ddr_data_o             ), // 存储器接口：写数据
    .wr_ddr_finish_i                ( wr_ddr_finish_i           )  // 存储器接口：本次写完成 
);
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


//////////////////////////////////////////////////////////////////////////////////
// *********** Logic Design
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
always @ (posedge sys_clk_i)begin
    aurora_wr_start_d0  <= #TCQ aurora_wr_start_i;
    aurora_wr_start_d1  <= #TCQ aurora_wr_start_d0;

    up_state_reset_d0   <= #TCQ err_reset;// up_state_reset || err_reset;
    up_state_reset_d1   <= #TCQ up_state_reset_d0;
end

assign aurora_wr_start_pose = (aurora_wr_start_i)   && (~aurora_wr_start_d0);
assign aurora_wr_start_nege = (~aurora_wr_start_i)  && (aurora_wr_start_d0);
assign up_state_reset_pose  = (up_state_reset_d0) && (~up_state_reset_d1);
  
always @ (posedge sys_clk_i) begin
    if(aurora_wr_start_pose) 
        aurora_wr_start_flag <= #TCQ 'b1;
    else if(aurora_wr_start_nege || up_state[4])  // UP_ERR_PCK 
        aurora_wr_start_flag <= #TCQ 'b0;
end

always @ (posedge sys_clk_i) begin
    if(up_state[4])  // UP_ERR_PCK
        up_state_reset_flag <= #TCQ 'b0;
    else if(up_state_reset_pose) 
        up_state_reset_flag <= #TCQ 'b1;
end

assign mem_vin_wr       = (up_state[1]) ? (aurora_wr_en_i && (~xdma_vin_ddr_almost_full)) : 1'b0;
assign up_vld_pck_end   = mem_vin_wr && (rx_cnt == PCK_PAYLOAD_SIZE_DIV64 - 'd1);
assign up_invld_pck_end = ~mem_vin_wr && ~xdma_vin_ddr_almost_full && (rx_cnt == PCK_PAYLOAD_SIZE_DIV64 - 'd1);

always @(posedge sys_clk_i) begin
    if(sys_rst_i)
        up_state <= #TCQ UP_IDLE;
    else 
        up_state <= #TCQ up_next_state;
end

always @(*) begin
    up_next_state = up_state;
    case (up_state)
        UP_IDLE: begin
            if(aurora_wr_start_flag)
                up_next_state = UP_AURORA_PCK;
            else if(up_state_reset_flag)
                up_next_state = UP_ERR_PCK;
        end 

        UP_AURORA_PCK: begin
            if(up_vld_pck_end || ((~aurora_wr_start_flag) && up_invld_pck_end))
                up_next_state = UP_CHECK;
            else if(up_state_reset_flag)
                up_next_state = UP_ERR_PCK;
        end

        UP_CHECK: begin
            if(aurora_wr_start_flag)
                up_next_state = UP_AURORA_PCK;
            else 
                up_next_state = UP_LAST;
        end

        UP_LAST: begin
            if(up_invld_pck_end)
                up_next_state = UP_END_WAIT;
            else if(up_state_reset_flag)
                up_next_state = UP_ERR_PCK;
        end

        UP_ERR_PCK: begin
            if(up_invld_pck_end)
                up_next_state = UP_ERR_LAST;
        end

        UP_ERR_LAST: begin
            if(up_invld_pck_end)
                up_next_state = UP_END_WAIT;
        end

        UP_END_WAIT: begin
                up_next_state = UP_IDLE;
        end

        default:up_next_state = UP_IDLE;
    endcase
end

always @(posedge sys_clk_i) begin
    if(up_state[1] && mem_vin_wr && aurora_wr_start_flag)
        last_rx_vld_num <= #TCQ rx_cnt + 1;
end

always @(posedge sys_clk_i) begin
    if(up_state[0] && up_next_state[1])
        xdma_pack_num <= #TCQ 'd1;
    else if(up_state[2])
        xdma_pack_num <= #TCQ xdma_pack_num + 1;
end

always @(posedge sys_clk_i) begin
    if(up_state[0])begin
        mem_vin_vld     <= #TCQ  'd0;
        rx_cnt          <= #TCQ  'd0;
    end
    else if(up_state[1])begin
        if(up_vld_pck_end)begin
            mem_vin_vld     <= #TCQ  'b1;
            mem_vin_data    <= #TCQ  aurora_wr_data_i;
            rx_cnt          <= #TCQ  'd0;
        end
        else if(mem_vin_wr)begin
            mem_vin_vld     <= #TCQ  'b1;
            mem_vin_data    <= #TCQ  aurora_wr_data_i;
            rx_cnt          <= #TCQ  rx_cnt + 1'd1;
        end
        else if((~aurora_wr_start_flag) && up_invld_pck_end) begin
            mem_vin_vld     <= #TCQ 'b1;
            mem_vin_data    <= #TCQ {LAST_VLD_TYPE_DATA,{43'd0,last_rx_vld_num[18-1:0],3'd0},{48'd0,xdma_pack_num[15:0]},{5{64'h8000_0000_0000_0000}}};
            rx_cnt          <= #TCQ 'd0;
        end
        else if((~aurora_wr_start_flag) && ~xdma_vin_ddr_almost_full)begin
            mem_vin_vld     <= #TCQ 'b1;
            mem_vin_data    <= #TCQ ERR_TYPE_DATA;
            rx_cnt          <= #TCQ rx_cnt + 1'd1;
        end
        else begin
            mem_vin_vld     <= #TCQ  'b0;
        end
    end 
    else if(up_state[3] || up_state[6])begin  // UP_LAST || UP_ERR_LAST
        if(up_invld_pck_end)begin
            mem_vin_vld     <= #TCQ 'b1;
            mem_vin_data    <= #TCQ LAST_TYPE_DATA;
            rx_cnt          <= #TCQ 'd0;
        end
        else if(~xdma_vin_ddr_almost_full)begin
            mem_vin_vld     <= #TCQ 'b1;
            mem_vin_data    <= #TCQ ERR_TYPE_DATA;
            rx_cnt          <= #TCQ rx_cnt + 1'd1;
        end
        else begin
            mem_vin_vld     <= #TCQ 'b0;
        end
    end
    else if(up_state[4])begin  // UP_ERR_PCK
        if(ddr_reset_flag)begin
            mem_vin_vld     <= #TCQ 'b0;
            mem_vin_data    <= #TCQ ERR_TYPE_DATA;
            rx_cnt          <= #TCQ 'd0;
        end
        else if(up_invld_pck_end)begin
            mem_vin_vld     <= #TCQ 'd1;
            mem_vin_data    <= #TCQ ERR_TYPE_DATA;
            rx_cnt          <= #TCQ 'd0;
        end
        else if(~xdma_vin_ddr_almost_full)begin
            mem_vin_vld     <= #TCQ 'b1;
            mem_vin_data    <= #TCQ ERR_TYPE_DATA;
            rx_cnt          <= #TCQ rx_cnt + 1'd1;
        end
        else begin
            mem_vin_data    <= #TCQ ERR_TYPE_DATA;
            mem_vin_vld     <= #TCQ 'b0;
        end
    end
    else begin
        mem_vin_vld     <= #TCQ 'b0;
    end
end

always @(posedge sys_clk_i) begin
    if(~up_state[4] && up_next_state[4])  // FSM into UP_ERR_PCK
        ddr_reset_flag <= #TCQ 'd1;
    else if(ddr_reset_cnt >= 'd30)
        ddr_reset_flag <= #TCQ 'd0;
end
always @(posedge sys_clk_i) begin
    if(ddr_reset_flag)
        ddr_reset_cnt <= #TCQ ddr_reset_cnt + 1;
    else 
        ddr_reset_cnt <= #TCQ 'd0;
end

always @(posedge ddr_clk_i) begin
    ddr_reset_flag_d0 <= #TCQ ddr_reset_flag;
    ddr_reset_flag_d1 <= #TCQ ddr_reset_flag_d0;
end

assign ddr_reset_flag_o = ddr_reset_flag_d1;



// debug code, check 8M lose cnt
reg [PCK_CNT-1:0] lose_cnt = 'd0;
wire lose_pack_end   = aurora_wr_en_i && (xdma_vin_ddr_almost_full) && (lose_cnt == PCK_PAYLOAD_SIZE_DIV64 - 'd1);
always @(posedge sys_clk_i) begin
    if(up_state[0] && aurora_wr_start_flag)
        lose_cnt <= #TCQ 'd0;
    else if(lose_pack_end)
        lose_cnt <= #TCQ 'd0;
    else if(aurora_wr_en_i && (xdma_vin_ddr_almost_full))
        lose_cnt <= #TCQ lose_cnt + 1;
end

reg [32-1:0] lose_pack_cnt = 'd0;
always @(posedge sys_clk_i) begin
    if(up_state[0] && aurora_wr_start_flag)
        lose_pack_cnt <= #TCQ 'd0;
    else if(lose_pack_end)
        lose_pack_cnt <= #TCQ lose_pack_cnt + 1;
end

// wire mem_virtual_full_dest_out;
// xpm_cdc_single #(
//     .DEST_SYNC_FF(2),   // DECIMAL; range: 2-10
//     .INIT_SYNC_FF(0),   // DECIMAL; 0=disable simulation init values, 1=enable simulation init values
//     .SIM_ASSERT_CHK(0), // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
//     .SRC_INPUT_REG(1)   // DECIMAL; 0=do not register input, 1=register input
//  )
//  xpm_mem_virtual_full_inst (
//     .dest_out(mem_virtual_full_dest_out), // 1-bit output: src_in synchronized to the destination clock domain. This output is
//                          // registered.

//     .dest_clk(sys_clk_i), // 1-bit input: Clock signal for the destination clock domain.
//     .src_clk(ddr_clk_i),   // 1-bit input: optional; required when SRC_INPUT_REG = 1
//     .src_in(mem_virtual_full)      // 1-bit input: Input signal to be synchronized to dest_clk domain.
//  );

// reg [32-1:0] lose_pack_mem_cnt = 'd0;
// always @(posedge sys_clk_i) begin
//     if(up_state[0] && aurora_wr_start_flag)
//         lose_pack_mem_cnt <= #TCQ 'd0;
//     else if(lose_pack_end && mem_virtual_full_dest_out)
//         lose_pack_mem_cnt <= #TCQ lose_pack_mem_cnt + 1;
// end

assign pmt_lose_pack_cnt_o      = lose_pack_cnt;
assign pmt_lose_pack_mem_cnt_o  = lose_cnt;

(*mark_debug = "true"*)reg [FRAME_DEPTH_WID-1:0] wr_frame_addr_d = 'd0;
(*mark_debug = "true"*)reg [FRAME_DEPTH_WID-1:0] rd_frame_addr_d = 'd0;
always @(posedge ddr_clk_i ) begin
    wr_frame_addr_d <= #TCQ wr_frame_addr_o;
    rd_frame_addr_d <= #TCQ rd_frame_addr;
end

reg [32-1:0] wr_frame_cnt = 'd0;
reg [32-1:0] rd_frame_cnt = 'd0;
always @(posedge ddr_clk_i ) begin
    if(up_state[0] && aurora_wr_start_flag)begin
        wr_frame_cnt <= #TCQ 'd0;
    end 
    else if(wr_frame_addr_d != wr_frame_addr_o)
        wr_frame_cnt <= #TCQ wr_frame_cnt + 1;
end

always @(posedge ddr_clk_i ) begin
    if(up_state[0] && aurora_wr_start_flag)begin
        rd_frame_cnt <= #TCQ 'd0;
    end 
    else if(rd_frame_addr_d != rd_frame_addr)
        rd_frame_cnt <= #TCQ rd_frame_cnt + 1;
end
assign wr_frame_cnt_o = wr_frame_cnt;
assign rd_frame_cnt_o = rd_frame_cnt;


// check ddr memory max usage
reg [32-1:0] ddr_usage_cnt = 'd0;
reg [32-1:0] ddr_usage_max = 'd0;
always @(posedge ddr_clk_i) begin
    if(up_state[0] && aurora_wr_start_flag)
        ddr_usage_cnt <= #TCQ 'd0;
    else if((rd_frame_addr_d != rd_frame_addr) || (wr_frame_addr_d != wr_frame_addr_o))begin
        if(wr_frame_cnt > rd_frame_cnt)
            ddr_usage_cnt <= #TCQ wr_frame_cnt - rd_frame_cnt;
    end
end

always @(posedge ddr_clk_i) begin
    if(up_state[0] && aurora_wr_start_flag)
        ddr_usage_max <= #TCQ 'd0;
    else if(ddr_usage_cnt > ddr_usage_max)
        ddr_usage_max <= #TCQ ddr_usage_cnt;
end

assign ddr_usage_max_o = ddr_usage_max;


reg [16-1:0] err_reset_cnt = 'd0;
reg [16-1:0] err_state_cnt = 'd0;
always @(posedge sys_clk_i) begin
    if(up_state[4] && up_next_state[6])  // UP_ERR_PCK -> UP_ERR_LAST
        err_reset_cnt <= #TCQ err_reset_cnt + 1;
end

wire hot_state_flag = hot_judge(up_state);
always @(posedge sys_clk_i) begin
    if(~hot_state_flag)  //  -> ERR_STATE
        err_state_cnt <= #TCQ err_state_cnt + 1;
end

assign err_state_cnt_o = {err_state_cnt[16-1:0],err_reset_cnt[16-1:0]};

reg [32-1:0] ddr_last_pack_cnt = 'd0;
always @(posedge sys_clk_i) begin
    if(up_state_reset_flag)
        ddr_last_pack_cnt <= #TCQ 'd0;
    else if(mem_vin_vld && (mem_vin_data == LAST_TYPE_DATA))
        ddr_last_pack_cnt <= #TCQ ddr_last_pack_cnt + 1;
end
assign ddr_last_pack_cnt_o = ddr_last_pack_cnt;
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


// hot_judge function
// input width: 9
// output width: 1
function hot_judge;
    input[7-1:0]hot_judge_number; 
    reg  [7-1:0] sign;
    begin
        if(hot_judge_number == 'd0)begin
            hot_judge = 1'b0;
        end
        else begin
            sign[0] = hot_judge_number[0];
            sign[1] = sign[0] ^ hot_judge_number[1];
            sign[2] = sign[1] ^ hot_judge_number[2];
            sign[3] = sign[2] ^ hot_judge_number[3];
            sign[4] = sign[3] ^ hot_judge_number[4];
            sign[5] = sign[4] ^ hot_judge_number[5];
            sign[6] = sign[5] ^ hot_judge_number[6];
            // sign[7] = sign[6] ^ hot_judge_number[7];
            // sign[8] = sign[7] ^ hot_judge_number[8];
            hot_judge = &(~hot_judge_number | sign);
        end
    end
endfunction 
endmodule
