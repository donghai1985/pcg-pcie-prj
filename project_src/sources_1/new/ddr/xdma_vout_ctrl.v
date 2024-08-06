`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: zas
// Engineer: songyuxin
// 
// Create Date: 2023/08/25
// Design Name: PCG
// Module Name: xdma_vout_ctrl
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


module xdma_vout_ctrl #(
    parameter                               TCQ                 = 0.1           ,  
    parameter                               C_M_AXI_ID_WIDTH    = 4             ,
    parameter                               C_DATA_WIDTH        = 128           ,
    parameter                               C_M_AXI_DATA_WIDTH  = C_DATA_WIDTH  ,
    parameter                               ADDR_WIDTH          = 28            ,
    parameter                               DATA_WIDTH          = 64            ,
    parameter                               MEM_DATA_BITS       = 512           ,
    parameter                               BURST_LEN           = 64            ,
    parameter                               FRAME_DEPTH_WID     = 9             
)(
    // clk & rst 
    input                                   ddr_clk_i               ,
    input                                   ddr_rst_i               ,
    input                                   xdma_user_clk_i         ,
    input                                   xdma_rst_i              ,

    input                                   ddr_reset_flag_i        ,
    input       [FRAME_DEPTH_WID-1:0]       wr_frame_addr_i         ,
    output      [FRAME_DEPTH_WID-1:0]       rd_frame_addr_o         ,

    // axi info, xdma
    input       [C_M_AXI_ID_WIDTH-1:0]      s_axi_arid_i            ,
    input       [64-1:0]                    s_axi_araddr_i          ,
    input       [7:0]                       s_axi_arlen_i           ,
    input       [2:0]                       s_axi_arsize_i          ,
    input       [1:0]                       s_axi_arburst_i         ,
    input                                   s_axi_arvalid_i         ,
    output                                  s_axi_arready_o         ,
    output      [C_M_AXI_ID_WIDTH-1:0]      s_axi_rid_o             ,
    output      [C_M_AXI_DATA_WIDTH-1:0]    s_axi_rdata_o           ,
    output      [1:0]                       s_axi_rresp_o           ,
    output                                  s_axi_rlast_o           ,
    output                                  s_axi_rvalid_o          ,
    input                                   s_axi_rready_i          ,
    output                                  up_irq_o                ,
    input                                   up_irq_ack_i            ,
    output      [32-1:0]                    up_check_irq_o          ,
    output      [32-1:0]                    up_check_frame_o        ,
    output      [32-1:0]                    irq_timeout_fault_cnt_o ,
    input                                   debug_register_rst_i    ,
    input                                   xdma_vout_state_rst_i   ,
    output      [32-1:0]                    xdma_idle_time_max_o    ,
    output      [32-1:0]                    xdma_hold_time_max_o    ,
    // input                                   pmt_rx_start_i          ,
    // output      [32-1:0]                    XDMA_Xencode_skip_cnt_o ,

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
localparam                          ST_IDLE                 = 'd0;
localparam                          ST_READ                 = 'd1;
localparam                          ST_END                  = 'd2;
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Register Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
reg     [1:0]                       state                   = ST_IDLE;
reg     [1:0]                       next_state              = ST_IDLE;

reg                                 s_axi_arready           = 'd0;
reg                                 s_axi_rlast             = 'd0;  
reg                                 s_axi_rvalid            = 'd0;
reg     [8-1:0]                     axi_arlen_r             = 'd0;
reg     [8-1:0]                     data_cnt                = 'd0;
reg                                 up_irq                  = 'd0;
reg     [4-1:0]                     wait_cnt                = 'd0;

reg                                 mem_virtual_empty       = 'd1;
reg                                 rd_burst_flag           = 'd0;
reg     [FRAME_DEPTH_WID-1:0]       rd_frame_addr           = 'd0;
reg     [11-1:0]                    rd_burst_line           = 'd0;

reg                                 xdma_rd_ready           = 'd0;
reg                                 first_rd_flag           = 'd0;
reg     [2-1:0]                     xdma_rd_cnt             = 'd0;
reg                                 axi_empty               = 'd1;
reg                                 axi_almost_empty        = 'd1;
reg                                 xdma_wr_finish          = 'd1;
reg     [512-1:0]                   xdma_wr_data_temp       = 'd0;
(*MAX_FANOUT = 256*)reg                                 pre_irq_flag            = 'd0;

reg                                 xdma_ddr_reset_flag     = 'd0;
reg                                 ddr_reset_flag_d0       = 'd0;
reg                                 ddr_reset_flag_d1       = 'd0;
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Wire Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
wire    [FRAME_DEPTH_WID-1:0]       wr_frame_addr       ;
wire                                xdma_reset_flag     ;
wire    [128-1:0]                   s_axi_rdata         ;  
wire                                axi_rd_en           ;
wire                                ddr_fifo_rd_en      ;
wire                                ddr_fifo_empty      ;
wire    [512-1:0]                   ddr_fifo_rd_data    ;

wire                                irq_timeout_flag    ;

//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Instance Module
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
mem_vout_buffer_ctrl #(
    .ADDR_WIDTH                     ( ADDR_WIDTH                    ),
    .DATA_WIDTH                     ( DATA_WIDTH                    ),
    .MEM_DATA_BITS                  ( MEM_DATA_BITS                 ),
    .BURST_LEN                      ( BURST_LEN                     ),
    .FRAME_DEPTH_WID                ( FRAME_DEPTH_WID               )
)mem_vout_buffer_ctrl_inst(
    // clk & rst 
    .ddr_clk_i                      ( ddr_clk_i                     ),
    .ddr_rst_i                      ( ddr_rst_i                     ),
    .xdma_user_clk_i                ( xdma_user_clk_i               ),
    .xdma_rst_i                     ( xdma_rst_i || xdma_reset_flag ),
    
    .burst_flag_i                   ( rd_burst_flag                 ),
    .frame_addr_i                   ( rd_frame_addr                 ),
    .burst_line_i                   ( rd_burst_line                 ),

    .ddr_fifo_empty_o               ( ddr_fifo_empty                ),
    .ddr_fifo_rd_en_i               ( ddr_fifo_rd_en                ),
    .ddr_fifo_rd_data_o             ( ddr_fifo_rd_data              ),

    .rd_ddr_req_o                   ( rd_ddr_req_o                  ),  
    .rd_ddr_len_o                   ( rd_ddr_len_o                  ),
    .rd_ddr_addr_o                  ( rd_ddr_addr_o                 ),
    .rd_ddr_data_valid_i            ( rd_ddr_data_valid_i           ),
    .rd_ddr_data_i                  ( rd_ddr_data_i                 ),
    .rd_ddr_finish_i                ( rd_ddr_finish_i               ) 
);

xpm_cdc_gray #(
    .DEST_SYNC_FF(2),          // DECIMAL; range: 2-10
    .INIT_SYNC_FF(0),          // DECIMAL; 0=disable simulation init values, 1=enable simulation init values
    .REG_OUTPUT(1),            // DECIMAL; 0=disable registered output, 1=enable registered output
    .SIM_ASSERT_CHK(0),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
    .SIM_LOSSLESS_GRAY_CHK(0), // DECIMAL; 0=disable lossless check, 1=enable lossless check
    .WIDTH(FRAME_DEPTH_WID)    // DECIMAL; range: 2-32
 )
 wr_frame_addr_cdc_inst (
    .dest_out_bin(wr_frame_addr),   // WIDTH-bit output: Binary input bus (src_in_bin) synchronized to
                                    // destination clock domain. This output is combinatorial unless REG_OUTPUT
                                    // is set to 1.

    .dest_clk(xdma_user_clk_i),     // 1-bit input: Destination clock.
    .src_clk(ddr_clk_i),            // 1-bit input: Source clock.
    .src_in_bin(wr_frame_addr_i)    // WIDTH-bit input: Binary input bus that will be synchronized to the
                                    // destination clock domain.

 );
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


//////////////////////////////////////////////////////////////////////////////////
// *********** Logic Design
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
always @(posedge xdma_user_clk_i) begin
    ddr_reset_flag_d0 <= #TCQ ddr_reset_flag_i;
    ddr_reset_flag_d1 <= #TCQ ddr_reset_flag_d0;
end

always @(posedge xdma_user_clk_i ) begin
    if(ddr_reset_flag_d1)
        xdma_ddr_reset_flag <= #TCQ 'd1;
    else if(next_state == ST_IDLE)
        xdma_ddr_reset_flag <= #TCQ 'd0;
end

assign xdma_reset_flag = xdma_ddr_reset_flag && (next_state==ST_IDLE);

always @(posedge xdma_user_clk_i ) begin
    if(xdma_rst_i || xdma_reset_flag)
        state <= #TCQ ST_IDLE;
    else if(xdma_vout_state_rst_i)
        state <= #TCQ ST_IDLE;
    else 
        state <= #TCQ next_state;
end

always @(*) begin
    next_state = state;
    case (state)
        ST_IDLE: begin
            if(s_axi_arvalid_i && s_axi_arready)
                next_state = ST_READ;
        end 
        
        ST_READ: begin
            if(s_axi_rvalid && s_axi_rready_i && s_axi_rlast)
                next_state = ST_END;
        end

        ST_END: begin
            if((up_irq && up_irq_ack_i) || ((~up_irq) && (&wait_cnt)))
                next_state = ST_IDLE;
        end
        default:next_state = ST_IDLE;
    endcase
end

always @(posedge xdma_user_clk_i) begin
    if(state==ST_END)
        wait_cnt <= #TCQ wait_cnt + 1;
    else 
        wait_cnt <= #TCQ 'd0;
end

always @(posedge xdma_user_clk_i) begin
    if(xdma_rst_i || xdma_reset_flag)
        mem_virtual_empty <= #TCQ 'd1;
    else if(mem_virtual_empty && wr_frame_addr != rd_frame_addr)
        mem_virtual_empty <= #TCQ 'd0; 
    else if(~mem_virtual_empty && (wr_frame_addr==(rd_frame_addr+1'd1)) && up_irq && up_irq_ack_i)
        mem_virtual_empty <= #TCQ 'd1; 
end

always @(posedge xdma_user_clk_i) begin
    if(xdma_rst_i || xdma_reset_flag)
        s_axi_arready <= #TCQ 'd0;
    else if(state==ST_IDLE)
        s_axi_arready <= #TCQ (~mem_virtual_empty);
    else if(state==ST_READ && next_state==ST_END)
        s_axi_arready <= #TCQ 'd0;
end

always @(posedge xdma_user_clk_i) begin
    if(xdma_rst_i || xdma_reset_flag)
        rd_frame_addr <= #TCQ 'd0;
    else if(up_irq && up_irq_ack_i)
        rd_frame_addr <= #TCQ rd_frame_addr + 1;
end

always @(posedge xdma_user_clk_i) begin
    if(xdma_rst_i || xdma_reset_flag)begin
        rd_burst_flag <= #TCQ 'd0;
        rd_burst_line <= #TCQ 'd0;
    end
    else if(state==ST_IDLE && next_state==ST_READ)begin
        rd_burst_flag <= #TCQ 'd1;
        rd_burst_line <= #TCQ s_axi_araddr_i[22:12];    // burst len = 256
    end
    else if(state==ST_END)begin
        rd_burst_flag <= #TCQ 'd0;
    end
end

always @(posedge xdma_user_clk_i) begin
    if(state==ST_IDLE && next_state==ST_READ)
        axi_arlen_r <= #TCQ s_axi_arlen_i;
end

assign axi_rd_en = s_axi_rready_i && s_axi_rvalid;

always @(posedge xdma_user_clk_i) begin
    if(state==ST_IDLE)
        data_cnt <= #TCQ 'd0;
    else if(state==ST_READ && axi_rd_en)begin
        data_cnt <= #TCQ data_cnt + 1;
    end
end

always @(posedge xdma_user_clk_i) begin
    if(state==ST_READ)begin
        if(s_axi_rready_i && s_axi_rvalid && s_axi_rlast)
            s_axi_rvalid <= #TCQ 'd0;
        else 
            s_axi_rvalid <= #TCQ ~axi_almost_empty;
    end 
    else begin
        s_axi_rvalid <= #TCQ 'd0;
    end
end

always @(posedge xdma_user_clk_i) begin
    if(state==ST_READ)begin
        if(axi_rd_en && s_axi_rlast)
            s_axi_rlast <= #TCQ 1'b0;
        else if(axi_rd_en && (data_cnt == axi_arlen_r - 1'b1))
            s_axi_rlast <= #TCQ 1'b1;
    end
    else begin
        s_axi_rlast <= #TCQ 1'b0;
    end
end

`ifdef SIMULATE
always @(posedge xdma_user_clk_i) begin
    if(s_axi_arvalid_i && s_axi_arready && s_axi_araddr_i[23:0]==24'h2000)
        pre_irq_flag <= #TCQ 'd1;
    else if(up_irq && up_irq_ack_i)
        pre_irq_flag <= #TCQ 'd0;
end
`else
reg [2048-1:0] vdma_flag0 = 'd0;
genvar i;
generate
    for(i=0;i<2048;i=i+1)begin: CHECK_VDMA
        always @(posedge xdma_user_clk_i) begin
            if(pre_irq_flag || xdma_vout_state_rst_i)
                vdma_flag0[i] <= #TCQ 'd0;
            else if(s_axi_arvalid_i && s_axi_arready && s_axi_araddr_i[22:12]==i)
                vdma_flag0[i] <= #TCQ 'd1;
        end
    end
endgenerate

reg [128-1:0] vdma_flag1 = 'd0; 
generate
    for(i=0;i<128;i=i+1)begin: CHECK_VDMA_DELAY0
        always @(posedge xdma_user_clk_i) begin
            vdma_flag1[i] <= #TCQ &vdma_flag0[(i+1)*16-1:i*16];
        end
    end
endgenerate

reg [8-1:0] vdma_flag2 = 'd0; 
generate
    for(i=0;i<8;i=i+1)begin: CHECK_VDMA_DELAY1
        always @(posedge xdma_user_clk_i) begin
            vdma_flag2[i] <= #TCQ &vdma_flag1[(i+1)*16-1:i*16];
        end
    end
endgenerate

always @(posedge xdma_user_clk_i) begin
    if(up_irq && up_irq_ack_i)
        pre_irq_flag <= #TCQ 'd0;
    else if(&vdma_flag2[8-1:0])
        pre_irq_flag <= #TCQ 'd1;
end
`endif // SIMULATE

always @(posedge xdma_user_clk_i) begin
    if(state==ST_READ && next_state==ST_END)begin
        if(pre_irq_flag)
            up_irq <= #TCQ 'd1;
        else 
            up_irq <= #TCQ 'd0;
    end
    else if(up_irq && up_irq_ack_i)begin
        up_irq <= #TCQ 'd0;
    end
end

// irq timeout check
reg [16-1:0] unit_time_cnt = 'd0;
always @(posedge xdma_user_clk_i) begin
    unit_time_cnt <= #TCQ unit_time_cnt + 1;
end

reg [16-1:0] irq_timeout_cnt = 'd0;
reg          irq_timeout_en  = 'd0;
always @(posedge xdma_user_clk_i) begin
    if(xdma_rst_i || xdma_reset_flag)
        irq_timeout_en <= #TCQ 'd0;
    else if(~irq_timeout_en && s_axi_arvalid_i && s_axi_arready)
        irq_timeout_en <= #TCQ 'd1;
    else if(irq_timeout_en && up_irq && up_irq_ack_i)
        irq_timeout_en <= #TCQ 'd0;
end

always @(posedge xdma_user_clk_i) begin
    if(irq_timeout_en)begin
        if(irq_timeout_flag)
            irq_timeout_cnt <= #TCQ irq_timeout_cnt;
        else if(&unit_time_cnt)
            irq_timeout_cnt <= #TCQ irq_timeout_cnt + 1;
    end
    else begin
        irq_timeout_cnt <= #TCQ 'd0;
    end
end

assign irq_timeout_flag = irq_timeout_cnt[8];

// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> read 512bit to 128bit
always @(posedge xdma_user_clk_i) begin
    if(xdma_rst_i || xdma_reset_flag)
        xdma_rd_ready <= 'd0;
    else 
        xdma_rd_ready <= ~ddr_fifo_empty;
end

always @(posedge xdma_user_clk_i) begin
    if(xdma_rst_i || xdma_reset_flag)
        xdma_wr_finish <= 'd1;
    else if(ddr_fifo_rd_en)
        xdma_wr_finish <= 'd0;
    else if(axi_rd_en && (xdma_rd_cnt==2))
        xdma_wr_finish <= 'd1;
end

always @(posedge xdma_user_clk_i) begin
    if(ddr_fifo_rd_en)
        first_rd_flag <= 'd1;
    else if(axi_empty)
        first_rd_flag <= 'd0;
end

assign ddr_fifo_rd_en = xdma_rd_ready && xdma_wr_finish && (~first_rd_flag^axi_rd_en);

always @(posedge xdma_user_clk_i) begin
    if(xdma_rst_i || xdma_reset_flag)
        xdma_rd_cnt <= 'd0;
    else if(axi_rd_en)
        xdma_rd_cnt <= xdma_rd_cnt + 1;
end

always @(posedge xdma_user_clk_i) begin
    if(ddr_fifo_rd_en)
        xdma_wr_data_temp <= ddr_fifo_rd_data;
    else if(axi_rd_en)
        xdma_wr_data_temp <= {128'd0,xdma_wr_data_temp[511:128]};
end

always @(posedge xdma_user_clk_i) begin
    if(xdma_rst_i || xdma_reset_flag)
        axi_almost_empty <= 'd1;
    else if(ddr_fifo_rd_en)
        axi_almost_empty <= 'd0;
    else if(xdma_rd_cnt==2 && axi_rd_en && ~xdma_rd_ready)
        axi_almost_empty <= 'd1;
end

always @(posedge xdma_user_clk_i) begin
    if(xdma_rst_i || xdma_reset_flag)
        axi_empty <= 'd1;
    else if(ddr_fifo_rd_en)
        axi_empty <= 'd0;
    else if(xdma_rd_cnt==3 && axi_rd_en && ~xdma_rd_ready)
        axi_empty <= 'd1;
end

assign s_axi_rdata = xdma_wr_data_temp[127:0];
// <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
assign s_axi_rid_o      = 'd0;
assign s_axi_rresp_o    = 'd0;

assign s_axi_arready_o  = s_axi_arready ;
assign s_axi_rvalid_o   = s_axi_rvalid  ;
assign s_axi_rdata_o    = s_axi_rdata   ;
assign s_axi_rlast_o    = s_axi_rlast   ;
assign up_irq_o         = up_irq        ;
assign rd_frame_addr_o  = rd_frame_addr ;

// check irq and 
reg up_irq_d        = 'd0;
reg up_irq_pose     = 'd0;
reg up_irq_ack_d    = 'd0;
reg up_irq_ack_pose = 'd0;

reg [16-1:0] up_irq_cnt      = 'd0;
reg [16-1:0] up_irq_ack_cnt  = 'd0;
always @(posedge xdma_user_clk_i) begin
    up_irq_d        <= #TCQ up_irq;
    up_irq_ack_d    <= #TCQ up_irq_ack_i;

    up_irq_pose     <= #TCQ (~up_irq_d) && up_irq;
    up_irq_ack_pose <= #TCQ (~up_irq_ack_d) && up_irq_ack_i;
end

always @(posedge xdma_user_clk_i) begin
    if(xdma_rst_i)
        up_irq_ack_cnt <= 'd0;
    else if(up_irq_ack_pose)
        up_irq_ack_cnt <= #TCQ up_irq_ack_cnt + 'd1;
end

always @(posedge xdma_user_clk_i) begin
    if(xdma_rst_i)
        up_irq_cnt  <= 'd0;
    else if(up_irq_pose)
        up_irq_cnt  <= #TCQ up_irq_cnt + 'd1;
end

assign up_check_irq_o   = {up_irq_cnt[15:0],up_irq_ack_cnt[15:0]};
assign up_check_frame_o = {s_axi_arready,7'd0,3'd0,wr_frame_addr[8:0],3'd0,rd_frame_addr[8:0]};

reg [32-1:0] irq_timeout_fault_cnt = 'd0;
always @(posedge xdma_user_clk_i) begin
    if(debug_register_rst_i)
        irq_timeout_fault_cnt <= #TCQ 'd0;
    else if(irq_timeout_flag && up_irq && up_irq_ack_i)
        irq_timeout_fault_cnt <= #TCQ irq_timeout_fault_cnt + 1;
end

assign irq_timeout_fault_cnt_o = irq_timeout_fault_cnt;

// check max time in 8M
reg [32-1:0] xdma_hold_time     = 'd0;
reg [32-1:0] xdma_hold_time_max = 'd0;
reg irq_timeout_en_d = 'd0;
always @(posedge xdma_user_clk_i) begin
    irq_timeout_en_d <= #TCQ irq_timeout_en;
end
always @(posedge xdma_user_clk_i) begin
    if(debug_register_rst_i)
        xdma_hold_time <= #TCQ 'd0;
    else if(irq_timeout_en_d)
        xdma_hold_time <= #TCQ xdma_hold_time + 1;
    else 
        xdma_hold_time <= #TCQ 'd0;
end

always @(posedge xdma_user_clk_i) begin
    if(debug_register_rst_i)
        xdma_hold_time_max <= #TCQ 'd0;
    else if((xdma_hold_time > xdma_hold_time_max) && irq_timeout_en_d)
        xdma_hold_time_max <= #TCQ xdma_hold_time;
end

reg [32-1:0] xdma_idle_time     = 'd0;
reg [32-1:0] xdma_idle_time_max = 'd0;

reg          xdma_idle_en  = 'd0;
reg          xdma_idle_en_d  = 'd0;
always @(posedge xdma_user_clk_i) begin
    xdma_idle_en_d <= #TCQ xdma_idle_en;
end
always @(posedge xdma_user_clk_i) begin
    if(debug_register_rst_i)
        xdma_idle_en <= #TCQ 'd0;
    else if(~xdma_idle_en && up_irq && up_irq_ack_i)
        xdma_idle_en <= #TCQ 'd1;
    else if(xdma_idle_en && s_axi_arvalid_i && s_axi_arready)
        xdma_idle_en <= #TCQ 'd0;
end

always @(posedge xdma_user_clk_i) begin
    if(debug_register_rst_i)
        xdma_idle_time <= #TCQ 'd0;
    else if(xdma_idle_en_d)
        xdma_idle_time <= #TCQ xdma_idle_time + 1;
    else 
        xdma_idle_time <= #TCQ 'd0;
end

always @(posedge xdma_user_clk_i) begin
    if(debug_register_rst_i)
        xdma_idle_time_max <= #TCQ 'd0;
    else if((xdma_idle_time > xdma_idle_time_max) && (~xdma_idle_en) && xdma_idle_en_d)
        xdma_idle_time_max <= #TCQ xdma_idle_time;
end

assign xdma_idle_time_max_o = xdma_idle_time_max;
assign xdma_hold_time_max_o = xdma_hold_time_max;

// debug code
// reg             dbg_s_axi_rvalid     = 'd0;
// reg [16-1:0]    dbg_s_axi_rdata0     = 'd0;
// reg [16-1:0]    dbg_s_axi_rdata1     = 'd0;
// always @(posedge xdma_user_clk_i) begin
//     dbg_s_axi_rvalid <= #TCQ s_axi_rvalid;
//     dbg_s_axi_rdata0 <= #TCQ s_axi_rdata[16-1:0];
//     dbg_s_axi_rdata1 <= #TCQ s_axi_rdata[80-1:64];
// end

// wire          dbg_Xencode_vld   = s_axi_rvalid;
// wire [18-1:0] dbg_Xencode       = s_axi_rdata[18 +: 18];

// reg          dbg_Xencode_vld_d  = 'd0;
// reg [18-1:0] dbg_Xencode_d      = 'd0;
// always @(posedge xdma_user_clk_i ) begin
//     dbg_Xencode_vld_d   <= #TCQ dbg_Xencode_vld;
//     dbg_Xencode_d       <= #TCQ dbg_Xencode;
// end

// reg          dbg_delta_vld      = 'd0;
// reg [18-1:0] dbg_Xencode_delta  = 'd0;
// always @(posedge xdma_user_clk_i ) begin
//     dbg_delta_vld       <= #TCQ dbg_Xencode_vld_d;
//     dbg_Xencode_delta   <= #TCQ dbg_Xencode - dbg_Xencode_d;
// end

// reg pmt_start_d0 = 'd0;
// reg pmt_start_d1 = 'd0;
// always @(posedge xdma_user_clk_i ) begin
//     pmt_start_d0 <= #TCQ pmt_rx_start_i;
//     pmt_start_d1 <= #TCQ pmt_start_d0;
// end

// reg [32-1:0] Xencode_skip_cnt = 'd0;
// always @(posedge xdma_user_clk_i ) begin
//     if(~pmt_start_d1 && pmt_start_d0)
//         Xencode_skip_cnt <= #TCQ 'd0;
//     else if(dbg_delta_vld)begin
//         if(dbg_Xencode_delta[17:2])
//             Xencode_skip_cnt <= #TCQ (&Xencode_skip_cnt) ? Xencode_skip_cnt : Xencode_skip_cnt + 1;
//     end
// end

// assign XDMA_Xencode_skip_cnt_o = Xencode_skip_cnt;
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


endmodule
