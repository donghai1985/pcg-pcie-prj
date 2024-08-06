//-----------------------------------------------------------------------------
//
// (c) Copyright 2012-2012 Xilinx, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
//
//-----------------------------------------------------------------------------
//
// Project    : The Xilinx PCI Express DMA 
// File       : xdma_app.v
// Version    : $IpVersion 
//-----------------------------------------------------------------------------

`timescale 1ps / 1ps
module xdma_app_v2 #(
    parameter   TCQ                 = 0.1           ,
    parameter   C_M_AXI_ID_WIDTH    = 4             ,
    parameter   C_DATA_WIDTH        = 128           ,
    parameter   C_M_AXI_DATA_WIDTH  = C_DATA_WIDTH
)(
    // AXI Memory Mapped interface
    input   wire    [C_M_AXI_ID_WIDTH-1:0]          s_axi_awid              ,
    input   wire    [64-1:0]                        s_axi_awaddr            ,
    input   wire    [7:0]                           s_axi_awlen             ,
    input   wire    [2:0]                           s_axi_awsize            ,
    input   wire    [1:0]                           s_axi_awburst           ,
    input   wire                                    s_axi_awvalid           ,
    output  reg                                     s_axi_awready    = 'd0  ,
    input   wire    [C_M_AXI_DATA_WIDTH-1:0]        s_axi_wdata             ,
    input   wire    [(C_M_AXI_DATA_WIDTH/8)-1:0]    s_axi_wstrb             ,
    input   wire                                    s_axi_wlast             ,
    input   wire                                    s_axi_wvalid            ,
    output  reg                                     s_axi_wready     = 'd0  ,
    output  wire    [C_M_AXI_ID_WIDTH-1:0]          s_axi_bid               ,
    output  wire    [1:0]                           s_axi_bresp             ,
    output  reg                                     s_axi_bvalid     = 'd0  ,
    input   wire                                    s_axi_bready            ,
    input   wire    [C_M_AXI_ID_WIDTH-1:0]          s_axi_arid              ,
    input   wire    [64-1:0]                        s_axi_araddr            ,
    input   wire    [7:0]                           s_axi_arlen             ,
    input   wire    [2:0]                           s_axi_arsize            ,
    input   wire    [1:0]                           s_axi_arburst           ,
    input   wire                                    s_axi_arvalid           ,
    output  reg                                     s_axi_arready    = 'd0  ,
    output  wire    [C_M_AXI_ID_WIDTH-1:0]          s_axi_rid               ,
    output  wire    [C_M_AXI_DATA_WIDTH-1:0]        s_axi_rdata             ,
    output  wire    [1:0]                           s_axi_rresp             ,
    output  reg                                     s_axi_rlast             ,
    output  reg                                     s_axi_rvalid            ,
    input   wire                                    s_axi_rready            ,

     // AXI Lite Master Interface connections
    input   wire    [31:0]                          s_axil_awaddr           ,
    input   wire                                    s_axil_awvalid          ,
    output  wire                                    s_axil_awready          ,
    input   wire    [31:0]                          s_axil_wdata            ,
    input   wire    [3:0]                           s_axil_wstrb            ,
    input   wire                                    s_axil_wvalid           ,
    output  wire                                    s_axil_wready           ,
    output  wire    [1:0]                           s_axil_bresp            ,
    output  wire                                    s_axil_bvalid           ,
    input   wire                                    s_axil_bready           ,
    input   wire    [31:0]                          s_axil_araddr           ,
    input   wire                                    s_axil_arvalid          ,
    output  wire                                    s_axil_arready          ,
    output  wire    [31:0]                          s_axil_rdata            ,
    output  wire    [1:0]                           s_axil_rresp            ,
    output  wire                                    s_axil_rvalid           ,
    input   wire                                    s_axil_rready           ,

    // System IO signals
    input   wire                                    user_clk                ,
    input   wire                                    user_rst_n              ,
    input   wire                                    user_lnk_up             ,
    input   wire                                    sys_rst_n               ,
    output  wire    [3:0]                           leds                    ,
      
    output  reg                                     dn_irq          = 'd0   ,
    input                                           dn_irq_ack              ,
    output  reg                                     up_irq          = 'd0   ,
    input                                           up_irq_ack              ,

    // up data signals
    input                                           eds_rx_start            ,
    input                                           eds_rx_end              ,
    output                                          pcie_eds_rx_end_o       ,

    input                                           pmt_rx_start            ,
    input                                           pmt_rx_end              ,
    output                                          pcie_pmt_rx_end_o       ,

    input                                           fbc_rx_start_i          ,
    input                                           fbc_rx_end_i            ,
    output                                          pcie_fbc_rx_end_o       ,

    output                                          up_fifo_wr              ,
    input       [127:0]                             up_fifo_data            ,
    input                                           ddr_fifo_empty_i        ,
    output                                          make_test_en            ,
  
    // down data signals
    input                                           dn_fifo_rd              ,
    output      [127:0]                             dn_fifo_q               ,
    output                                          dn_fifo_emp             ,
    
    // communication register
    output                                          soft_reset              ,
    input                                           CHANNEL_UP_DONE         ,
    input                                           CHANNEL_UP_DONE1        ,
    input                                           CHANNEL_UP_DONE2        ,
    input                                           ddr3_init_done          ,

    output      [31:0]                              read_reg_0x8            ,
    output      [31:0]                              read_reg_0xc            ,
    output      [31:0]                              read_reg_0x10           ,
    output      [31:0]                              read_reg_0x14           ,
    output      [31:0]                              read_reg_0x18           

);

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Parameter Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
localparam          DMA_SIZE                = 8388608;      //32'h800000 ,8MBytes
localparam          PCK_PAYLOAD_SIZE        = 24'd8388592;  //DMA_SIZE - 16Bytes
localparam          PCK_PAYLOAD_SIZE_DIV16  = 32'd524288;   //DMA_SIZE / 16Bytes  

localparam          UP_IDLE                 = 'b00000_0001; //up_state[0]
localparam          UP_EDS_PCK              = 'b00000_0010; //up_state[1]
localparam          UP_PMT_PCK              = 'b00000_0100; //up_state[2]
localparam          UP_FBC_PCK              = 'b00000_1000; //up_state[3]
localparam          UP_CHECK                = 'b00001_0000; //up_state[4]
localparam          UP_LAST                 = 'b00010_0000; //up_state[5]
localparam          UP_ERR_PCK              = 'b00100_0000; //up_state[6]
localparam          UP_END_WAIT             = 'b01000_0000; //up_state[7]
localparam          UP_ERR_LAST             = 'b10000_0000; //up_state[8]

//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Register Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

reg     [9-1:0]     up_state                = UP_IDLE;
reg     [9-1:0]     up_next_state           = UP_IDLE;


reg     [1:0]       axi_state               = 'd0;
reg     [7:0]       data_cnt                = 'd0;
reg     [31:0]      data_count1             = 'd0;
reg     [31:0]      data_count2             = 'd0;
reg     [7:0]       s_axi_awlen_r           = 'd0;
reg     [7:0]       s_axib_awlen_r          = 'd0;
reg     [7:0]       axi_wvalid_cnt          = 'd0;
reg     [7:0]       axib_wvalid_cnt         = 'd0;
reg     [7:0]       axib_arlen_r            = 'd0;
reg     [7:0]       axi_arlen_r             = 'd0;

reg                 up_fifo_wr_true         = 'd0;
reg     [127:0]     up_data_in_true         = 'd0;
reg     [31:0]      rx_cnt                  = 'd0;

reg                 eds_rx_start_d0         = 'd0;
reg                 eds_rx_start_d1         = 'd0;
reg                 eds_rx_end_d0           = 'd0;
reg                 eds_rx_end_d1           = 'd0;
reg                 fbc_rx_start_d0         = 'd0;
reg                 fbc_rx_start_d1         = 'd0;
reg                 fbc_rx_end_d0           = 'd0;
reg                 fbc_rx_end_d1           = 'd0;
reg                 pmt_rx_start_d0         = 'd0;
reg                 pmt_rx_start_d1         = 'd0;
reg                 pmt_rx_end_d0           = 'd0;
reg                 pmt_rx_end_d1           = 'd0;

reg                 eds_rx_start_flag       = 'd0;
reg                 eds_rx_end_flag         = 'd0;
reg                 fbc_rx_start_flag       = 'd0;
reg                 fbc_rx_end_flag         = 'd0;
reg                 pmt_rx_start_flag       = 'd0;
reg                 pmt_rx_end_flag         = 'd0;

reg                 up_state_reset_d0       = 'd0;
reg                 up_state_reset_d1       = 'd0;

reg                 up_state_reset_flag     = 'd0;
reg                 err_pck_finish          = 'd0;
reg                 check_finish_flag       = 'd1;
reg                 pre_irq_flag            = 'd0;

//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Wire Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
wire                user_resetn         ;
wire                up_fifo_reset       ;
wire                dn_fifo_wr          ;
wire                dn_fifo_full        ;

wire                up_fifo_empty       ;
wire                up_fifo_full        ;
wire                up_fifo_prog_full   ;
wire                up_fifo_prog_empty  ;
wire                up_fifo_rd          ;
wire                up_fifo_emp         ;
wire    [127:0]     up_fifo_q           ;
wire    [127:0]     up_fifo_trans       ;

wire                up_state_reset      ;
wire                up_vld_pck_end      ;
wire                up_invld_pck_end    ;

wire                eds_rx_start_pose   ;
wire                fbc_rx_start_pose   ;
wire                pmt_rx_start_pose   ;
wire                up_state_reset_pose ;

wire                pcie_eds_rx_end     ;
wire                pcie_pmt_rx_end     ;
wire                pcie_fbc_rx_end     ;

wire    [31:0]      in_reg0             ;
wire    [31:0]      in_reg1             ;
wire    [31:0]      in_reg2             ;
wire    [31:0]      in_reg3             ;
wire    [31:0]      read_reg_0x0        ;
wire    [31:0]      read_reg_0x4        ;
wire    [31:0]      read_reg_0x1c       ;
wire    [31:0]      read_reg_0x20       ;
wire    [31:0]      read_reg_0x24       ;

//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Instance Module
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

vio_0 vio_0_inst(
    .clk        ( user_clk          ),

    .probe_out0 ( up_state_reset    )
);

widen_enable #(
    .WIDEN_TYPE         ( 1                     ),  // 1 = posedge lock
    .WIDEN_NUM          ( 10                    )
)pcie_eds_rx_end_inst(
    .clk_i              ( user_clk              ),
    .rst_i              ( ~user_resetn          ),

    .src_signal_i       ( pcie_eds_rx_end       ),
    .dest_signal_o      ( pcie_eds_rx_end_o     )    
);

widen_enable #(
    .WIDEN_TYPE         ( 1                     ),  // 1 = posedge lock
    .WIDEN_NUM          ( 10                    )
)pcie_pmt_rx_end_inst(
    .clk_i              ( user_clk              ),
    .rst_i              ( ~user_resetn          ),

    .src_signal_i       ( pcie_pmt_rx_end       ),
    .dest_signal_o      ( pcie_pmt_rx_end_o     )    
);

widen_enable #(
    .WIDEN_TYPE         ( 1                     ),  // 1 = posedge lock
    .WIDEN_NUM          ( 10                    )
)pcie_fbc_rx_end_inst(
    .clk_i              ( user_clk              ),
    .rst_i              ( ~user_resetn          ),

    .src_signal_i       ( pcie_fbc_rx_end       ),
    .dest_signal_o      ( pcie_fbc_rx_end_o     )    
);

fifo_128_128 up (
    .rst                ( up_fifo_reset         ),  // input wire rst
    .wr_clk             ( user_clk              ),  // input wire wr_clk
    .rd_clk             ( user_clk              ),  // input wire rd_clk
    .din                ( up_data_in_true       ),  // input wire [127 : 0] din
    .wr_en              ( up_fifo_wr_true       ),  // input wire wr_en
    .rd_en              ( up_fifo_rd            ),  // input wire rd_en
    .dout               ( up_fifo_q             ),  // output wire [127 : 0] dout
    .full               ( up_fifo_empty         ),  // output wire full
    .empty              ( up_fifo_full          ),  // output wire empty
    .prog_empty         ( up_fifo_prog_empty    ),
    .prog_full          ( up_fifo_prog_full     )   // output wire prog_full
);
// assign   up_fifo_prog_full = 1'b0;    //test


//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Logic Design
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
// LEDs for observation
assign leds[0]          = sys_rst_n;
assign leds[1]          = user_resetn;
assign leds[2]          = user_lnk_up;

assign make_test_en     = read_reg_0x4[0];
assign soft_reset       = ~sys_rst_n;//~user_resetn;
assign user_resetn      = sys_rst_n /*& (!read_reg_0x0[0])*/;

assign in_reg0          = CHANNEL_UP_DONE   ? 'd100 : 'd0;
assign in_reg1          = ddr3_init_done    ? 'd100 : 'd0;
assign in_reg2          = CHANNEL_UP_DONE1  ? 'd100 : 'd0;
assign in_reg3          = CHANNEL_UP_DONE2  ? 'd100 : 'd0;

assign up_fifo_reset    = ~user_resetn || (up_state[6] && up_irq);  // UP_ERR_PCK
//==================================================================
//==================================================================
// down channel, dont care
//==================================================================
//==================================================================
assign dn_fifo_wr         = s_axi_wvalid & s_axi_wready ;
  
always @ (posedge user_clk) begin
    if(!user_resetn)
        s_axi_awready <= #TCQ 'd0;
    else if(s_axi_awvalid && s_axi_awready)
        s_axi_awready <= #TCQ 'd0;
    else if(s_axi_awvalid && (!dn_fifo_full) && (!s_axi_wready) && (!dn_irq)) ///////////////////////////////////
        s_axi_awready <= #TCQ 1;
    else
        s_axi_awready <= #TCQ 0;
end
  
  
always @ (posedge user_clk) begin
    if(!user_resetn)
        s_axi_awlen_r <= #TCQ 'd0;
    else if(s_axi_awvalid && s_axi_awready)
        s_axi_awlen_r <= #TCQ s_axi_awlen;
end
  

always @ (posedge user_clk) begin
    if(!user_resetn)
        axi_wvalid_cnt <= #TCQ 'd0;
    else if(s_axi_wready && s_axi_wvalid && (axi_wvalid_cnt >= s_axi_awlen_r))
        axi_wvalid_cnt <= #TCQ 'd0;
    else if(s_axi_wready && s_axi_wvalid)
        axi_wvalid_cnt <= #TCQ axi_wvalid_cnt + 1'b1;
end
  
always @ (posedge user_clk) begin
    if(!user_resetn)
        s_axi_wready <= #TCQ 'd0;
    // else if(s_axi_wready && s_axi_wvalid && s_axi_wlast)
    else if(s_axi_wready && s_axi_wvalid && (axi_wvalid_cnt >= s_axi_awlen_r))
        s_axi_wready <= #TCQ 0;
    else if(s_axi_awvalid && s_axi_awready)
        s_axi_wready <= #TCQ 1;
end
  
  
always @ (posedge user_clk) begin
    if(!user_resetn)
        s_axi_bvalid <= #TCQ 'd0;
    else if(s_axi_bvalid && s_axi_bready)
        s_axi_bvalid <= #TCQ 0;
    else if(s_axi_wvalid && s_axi_wready && s_axi_wlast)
        s_axi_bvalid <= #TCQ 1;
end

  
always @ (posedge user_clk) begin
    if(!user_resetn) begin
        data_count1 <= #TCQ 'd0;
        dn_irq <= #TCQ 'd0;
    end
    else if(dn_irq && dn_irq_ack) begin
        dn_irq <= #TCQ 0;
        data_count1 <= #TCQ 'd0;
    end
    else if(s_axi_wvalid && s_axi_wready && data_count1 == PCK_PAYLOAD_SIZE) begin
        data_count1 <= #TCQ 'd0;
        dn_irq <= #TCQ 1;
    end
    else if(s_axi_wvalid && s_axi_wready) begin
        data_count1 <= #TCQ data_count1 + 16;
        dn_irq <= #TCQ 0;
    end
end
  

  
fifo_128_128 dn (
    .rst(~user_resetn),              // input wire rst
    .wr_clk(user_clk),        // input wire wr_clk
    .rd_clk(user_clk),        // input wire rd_clk
    .din(s_axi_wdata),              // input wire [127 : 0] din
    .wr_en(dn_fifo_wr),          // input wire wr_en
    .rd_en(dn_fifo_rd),          // input wire rd_en
    .dout(dn_fifo_q),            // output wire [127 : 0] dout
    .full(),            // output wire full
    .empty(dn_fifo_emp),          // output wire empty
    .prog_empty(),
    .prog_full(dn_fifo_full)  // output wire prog_full
);

//=========================================================
//=========================================================
// up channel
//=========================================================
//=========================================================
always @ (posedge user_clk)
begin
    eds_rx_start_d0     <= #TCQ eds_rx_start;
    eds_rx_start_d1     <= #TCQ eds_rx_start_d0;
    eds_rx_end_d0       <= #TCQ eds_rx_end;
    eds_rx_end_d1       <= #TCQ eds_rx_end_d0;
    pmt_rx_start_d0     <= #TCQ pmt_rx_start;
    pmt_rx_start_d1     <= #TCQ pmt_rx_start_d0;
    pmt_rx_end_d0       <= #TCQ pmt_rx_end;
    pmt_rx_end_d1       <= #TCQ pmt_rx_end_d0;
    fbc_rx_start_d0     <= #TCQ fbc_rx_start_i;
    fbc_rx_start_d1     <= #TCQ fbc_rx_start_d0;
    fbc_rx_end_d0       <= #TCQ fbc_rx_end_i;
    fbc_rx_end_d1       <= #TCQ fbc_rx_end_d0;

    up_state_reset_d0   <= #TCQ up_state_reset || read_reg_0x1c[0];
    up_state_reset_d1   <= #TCQ up_state_reset_d0;
end

assign eds_rx_start_pose   = eds_rx_start_d0 && (~eds_rx_start_d1);
assign fbc_rx_start_pose   = fbc_rx_start_d0 && (~fbc_rx_start_d1);
assign pmt_rx_start_pose   = pmt_rx_start_d0 && (~pmt_rx_start_d1);
assign up_state_reset_pose = up_state_reset_d0 && (~up_state_reset_d1);
  
always @ (posedge user_clk) begin
    if(up_state[0] || up_state[7])  // UP_IDLE || UP_END_WAIT
        fbc_rx_end_flag <= #TCQ 'b0;
    else if(fbc_rx_end_d1)
        fbc_rx_end_flag <= #TCQ 'b1;
end

always @ (posedge user_clk) begin
    if(fbc_rx_end_flag || pcie_fbc_rx_end || up_state[6])  // UP_ERR_PCK 
        fbc_rx_start_flag <= #TCQ 'b0;
    else if(fbc_rx_start_pose) 
        fbc_rx_start_flag <= #TCQ 'b1;
end

always @ (posedge user_clk) begin
    if(up_state[0] || up_state[7])  // UP_IDLE || UP_END_WAIT
        eds_rx_end_flag <= #TCQ 'b0;
    else if(eds_rx_end_d1)
        eds_rx_end_flag <= #TCQ 'b1;
end

always @ (posedge user_clk) begin
    if(eds_rx_end_flag || pcie_eds_rx_end || up_state[6])  // UP_ERR_PCK 
        eds_rx_start_flag <= #TCQ 'b0;
    else if(eds_rx_start_pose) 
        eds_rx_start_flag <= #TCQ 'b1;
end

always @ (posedge user_clk) begin
    if(up_state[0] || up_state[7])  // UP_IDLE || UP_END_WAIT
        pmt_rx_end_flag <= #TCQ 'b0;
    else if(pmt_rx_end_d1)
        pmt_rx_end_flag <= #TCQ 'b1;
end

always @ (posedge user_clk) begin
    if(pmt_rx_end_flag || pcie_pmt_rx_end || up_state[6])  // UP_ERR_PCK 
        pmt_rx_start_flag <= #TCQ 'b0;
    else if(pmt_rx_start_pose) 
        pmt_rx_start_flag <= #TCQ 'b1;
end

always @ (posedge user_clk) begin
    if(up_state[0] || up_state[6])  // UP_IDLE || UP_ERR_PCK
        up_state_reset_flag <= #TCQ 'b0;
    else if(up_state_reset_pose) 
        up_state_reset_flag <= #TCQ 'b1;
end

always @(posedge user_clk) begin
    if(~user_resetn)
        up_state <= #TCQ UP_IDLE;
    else 
        up_state <= #TCQ up_next_state;
end

assign up_fifo_wr       = (up_state==UP_EDS_PCK || up_state==UP_PMT_PCK || up_state==UP_FBC_PCK) ? ((~ddr_fifo_empty_i) && (~up_fifo_prog_full)) : 1'b0;
assign up_vld_pck_end   = up_fifo_wr && (rx_cnt == PCK_PAYLOAD_SIZE_DIV16 - 'd1);
assign up_invld_pck_end = ~up_fifo_wr && ~up_fifo_prog_full && (rx_cnt == PCK_PAYLOAD_SIZE_DIV16 - 'd1);

always @(*) begin
    up_next_state = up_state;
    case (up_state)
        UP_IDLE: begin
            if(eds_rx_start_flag)
                up_next_state = UP_EDS_PCK;
            else if(pmt_rx_start_flag)
                up_next_state = UP_PMT_PCK;
            else if(fbc_rx_start_flag)
                up_next_state = UP_FBC_PCK;
        end 

        UP_EDS_PCK: begin
            if(up_vld_pck_end)
                up_next_state = UP_CHECK;
            else if(up_state_reset_flag)
                up_next_state = UP_ERR_PCK;
        end

        UP_PMT_PCK: begin
            if(up_vld_pck_end)
                up_next_state = UP_CHECK;
            else if(up_state_reset_flag)
                up_next_state = UP_ERR_PCK;
        end

        UP_FBC_PCK: begin
            if(up_vld_pck_end || (fbc_rx_end_flag && ddr_fifo_empty_i && up_invld_pck_end))
                up_next_state = UP_CHECK;
            else if(up_state_reset_flag)
                up_next_state = UP_ERR_PCK;
        end

        UP_CHECK: begin
            if(eds_rx_end_flag || pmt_rx_end_flag || fbc_rx_end_flag)
                up_next_state = UP_LAST;
            else if(eds_rx_start_flag)
                up_next_state = UP_EDS_PCK;
            else if(pmt_rx_start_flag)
                up_next_state = UP_PMT_PCK;
            else if(fbc_rx_start_flag)
                up_next_state = UP_FBC_PCK;
        end

        UP_LAST: begin
            if(up_invld_pck_end)
                up_next_state = UP_END_WAIT;
            else if(up_state_reset_flag)
                up_next_state = UP_ERR_PCK;
        end

        UP_ERR_PCK: begin
            if(up_invld_pck_end && err_pck_finish)
                up_next_state = UP_ERR_LAST;
        end

        UP_ERR_LAST: begin
            if(up_invld_pck_end)
                up_next_state = UP_END_WAIT;
        end

        UP_END_WAIT: begin
            if(check_finish_flag)
                up_next_state = UP_IDLE;
        end

        default:up_next_state = UP_IDLE;
    endcase
end

always @(posedge user_clk) begin
    if(up_state[1] || up_state[2])begin
        if(up_vld_pck_end)begin
            up_fifo_wr_true <= #TCQ  'b1;
            up_data_in_true <= #TCQ  up_fifo_trans;
            rx_cnt          <= #TCQ  'd0;
        end
        else if(up_fifo_wr)begin
            up_fifo_wr_true <= #TCQ  'b1;
            up_data_in_true <= #TCQ  up_fifo_trans;
            rx_cnt          <= #TCQ  rx_cnt + 1'd1;
        end
        else begin
            up_fifo_wr_true <= #TCQ  'b0;
        end
    end
    else if(up_state[3])begin  // UP_FBC_PCK
        if(up_vld_pck_end) begin
            up_fifo_wr_true <= #TCQ 1'b1;
            up_data_in_true <= #TCQ up_fifo_trans;
            rx_cnt          <= #TCQ 'd0;
        end
        else if(up_fifo_wr) begin
            up_fifo_wr_true <= #TCQ 1'b1;
            up_data_in_true <= #TCQ up_fifo_trans;
            rx_cnt          <= #TCQ rx_cnt + 1'd1;
        end
        else if(fbc_rx_end_flag && ddr_fifo_empty_i && up_invld_pck_end) begin
            up_fifo_wr_true <= #TCQ 'b1;
            up_data_in_true <= #TCQ 'h8000_0000_0000_0000_8000_0000_0000_0000;
            rx_cnt          <= #TCQ 'd0;
        end
        else if(fbc_rx_end_flag && ddr_fifo_empty_i && ~up_fifo_prog_full)begin
            up_fifo_wr_true <= #TCQ 'b1;
            up_data_in_true <= #TCQ 'h8000_0000_0000_0000_8000_0000_0000_0000;
            rx_cnt          <= #TCQ rx_cnt + 1'd1;
        end
        else begin
            up_fifo_wr_true <= #TCQ 1'b0;
        end
    end
    else if(up_state[5] || up_state[8])begin  // UP_LAST || UP_ERR_LAST
        if(up_invld_pck_end)begin
            up_fifo_wr_true <= #TCQ 'b1;
            up_data_in_true <= #TCQ 'h5A5A_DEAD_0000_FFFF_5A5A_DEAD_0000_FFFF;
            rx_cnt          <= #TCQ 'd0;
        end
        else if(~up_fifo_prog_full)begin
            up_fifo_wr_true <= #TCQ 'b1;
            up_data_in_true <= #TCQ 'd0;
            rx_cnt          <= #TCQ rx_cnt + 1'd1;
        end
        else begin
            up_fifo_wr_true <= #TCQ 'b0;
        end
    end
    else if(up_state[6])begin  // UP_ERR_PCK
        if(up_irq)begin
            up_fifo_wr_true <= #TCQ 'd0;
            up_data_in_true <= #TCQ 'd0;
            rx_cnt          <= #TCQ 'd0;
        end
        else if(up_invld_pck_end)begin
            up_fifo_wr_true <= #TCQ 'd1;
            up_data_in_true <= #TCQ 'h8000_0000_0000_0000_8000_0000_0000_0000;
            rx_cnt          <= #TCQ 'd0;
        end
        else if(~up_fifo_prog_full)begin
            up_fifo_wr_true <= #TCQ 'b1;
            up_data_in_true <= #TCQ 'h8000_0000_0000_0000_8000_0000_0000_0000;
            rx_cnt          <= #TCQ rx_cnt + 1'd1;
        end
        else begin
            up_fifo_wr_true <= #TCQ 'b0;
        end
    end
    else begin
        up_fifo_wr_true <= #TCQ 'b0;
    end
end

assign pcie_eds_rx_end = (up_state[5] && (~up_next_state[5]) && eds_rx_end_flag) || (up_state[1] && up_state_reset_flag);
assign pcie_pmt_rx_end = (up_state[5] && (~up_next_state[5]) && pmt_rx_end_flag) || (up_state[2] && up_state_reset_flag);
assign pcie_fbc_rx_end = (up_state[5] && (~up_next_state[5]) && fbc_rx_end_flag) || (up_state[3] && up_state_reset_flag);

always @(posedge user_clk) begin
    if(up_state==UP_ERR_PCK && up_irq)
        err_pck_finish <= #TCQ 'd1;
    else if(up_state==UP_IDLE)
        err_pck_finish <= #TCQ 'd0;
end

always @(posedge user_clk) begin
    if(up_irq && up_irq_ack)
        check_finish_flag <= #TCQ 'd1;
    else if(s_axi_arvalid && s_axi_arready && s_axi_araddr[23:0]==24'd0)
        check_finish_flag <= #TCQ 'd0;
end

always @(posedge user_clk) begin
    if(s_axi_arvalid && s_axi_arready && s_axi_araddr[23:0]==24'h7ff000)
        pre_irq_flag <= #TCQ 'd1;
    else if(up_irq && up_irq_ack)
        pre_irq_flag <= #TCQ 'd0;
end

reg right_avld = 'd0;
reg [23-1:0] next_addr = 'd0;
always @(posedge user_clk) begin
    if(up_state[0] || (up_irq && up_irq_ack))begin
        right_avld  <= #TCQ 'd0;
    end
    else if(next_addr > 'h2000)begin
        right_avld  <= #TCQ 'd1;
    end
    else if(s_axi_arvalid)begin
        if(next_addr[23-1:0] == s_axi_araddr[23-1:0])begin
            right_avld  <= #TCQ 'd1;
        end
        else begin
            right_avld  <= #TCQ 'd0;
        end
    end
end
always @(posedge user_clk) begin
    if(up_state[0] || (up_irq && up_irq_ack))begin
        next_addr   <= #TCQ 'd0;
    end
    else if(next_addr > 'h2000)begin
        next_addr  <= #TCQ next_addr;
    end
    else if(s_axi_arvalid && s_axi_arready)begin
        next_addr   <= #TCQ next_addr + 'h1000;
    end
end

assign up_fifo_trans    = up_fifo_data;
assign up_fifo_rd       = s_axi_rready && s_axi_rvalid;
assign s_axi_rdata      = up_fifo_q;

always @ (posedge user_clk) begin
    if(!user_resetn) begin
        axi_state <= #TCQ 'd0;
        s_axi_arready <= #TCQ 'd0;
        s_axi_rvalid <= #TCQ 'd0;
        s_axi_rlast <= #TCQ 'd0;
        data_cnt <= #TCQ 'd0;
        axi_arlen_r <= #TCQ 'd0;
        data_count2 <= #TCQ 'd0;
        up_irq <= #TCQ 'd0;
    end
    else begin
        case(axi_state)
            2'd0 : begin
                if(s_axi_arvalid && s_axi_arready) begin
                    axi_state <= #TCQ 'd1;
                    axi_arlen_r <= #TCQ s_axi_arlen;
                end
                else if(!up_fifo_prog_empty) begin
                    s_axi_arready <= #TCQ 1'b1;
                end
                else begin
                    axi_state <= #TCQ 'd0;
                end
                s_axi_rvalid <= #TCQ 'd0;
                s_axi_rlast <= #TCQ 'd0;
                data_cnt <= #TCQ 'd0;
                up_irq <= #TCQ 'd0;
            end

            2'd1 : begin
                if(s_axi_rready && s_axi_rvalid && s_axi_rlast)begin
                    s_axi_arready <= #TCQ 1'b0;
                    s_axi_rvalid <= #TCQ 1'b0;
                end
                else 
                    s_axi_rvalid <= #TCQ 1'b1;
                //-----------------------------------------    
                if(s_axi_rready && s_axi_rvalid && s_axi_rlast/* && (!up_irq)*/) begin
                    data_cnt <= #TCQ 'd0;
                    axi_state <= #TCQ 'd2;
                end
                else if(s_axi_rready && s_axi_rvalid)    begin
                    data_cnt <= #TCQ data_cnt + 1'b1;
                    axi_state <= #TCQ 'd1;
                end
                else begin
                    data_cnt <= #TCQ data_cnt;
                    axi_state <= #TCQ axi_state;
                end
                
                //-----------------------------------------------    
                if(s_axi_rready && s_axi_rvalid && s_axi_rlast)
                    s_axi_rlast <= #TCQ 1'b0;
                else if(s_axi_rready && s_axi_rvalid && (data_cnt == axi_arlen_r - 1'b1))
                    s_axi_rlast <= #TCQ 1'b1;
                else
                    s_axi_rlast <= #TCQ s_axi_rlast;
                //-----------------------------------    
                if(s_axi_rready && s_axi_rvalid && s_axi_rlast)begin
                    if(pre_irq_flag)
                        up_irq <= #TCQ 'd1;
                    else 
                        up_irq <= #TCQ 'd0;
                end
            end

            2'd2 : begin
                s_axi_arready <= #TCQ 1'b0;
                s_axi_rvalid <= #TCQ 1'b0;
                s_axi_rlast <= #TCQ 'd0;

                if(up_irq && up_irq_ack) begin
                    data_cnt <= #TCQ 'd0;
                    axi_state <= #TCQ 'd0;
                    up_irq <= #TCQ 1'b0;
                end
                else if(up_irq) begin
                    data_cnt <= #TCQ 'd0;
                    axi_state <= #TCQ axi_state;
                    up_irq <= #TCQ 1'b1;
                end
                else if(data_cnt >= 'd20) begin
                    data_cnt <= #TCQ 'd0;
                    axi_state <= #TCQ 'd0;
                    up_irq <= #TCQ 1'b0;
                end
                else begin
                    data_cnt <= #TCQ data_cnt + 1'b1;
                    axi_state <= #TCQ axi_state;
                    up_irq <= #TCQ 1'b0;
                end
            end
        default:axi_state <= #TCQ 'd0;
        endcase
    end    
end
  

   
assign s_axi_rid    = 'd0;
assign s_axi_bid    = 'd0;
assign s_axi_bresp  = 'd0;
assign s_axi_rresp  = 'd0;

myip_v1_0_S00_AXI myip_v1_0_S00_AXI(    
    .S_AXI_ACLK         ( user_clk          ),
    .S_AXI_ARESETN      ( user_rst_n        ),
    .S_AXI_AWADDR       ( s_axil_awaddr     ),
    .S_AXI_AWVALID      ( s_axil_awvalid    ),
    .S_AXI_AWREADY      ( s_axil_awready    ),
    .S_AXI_WDATA        ( s_axil_wdata      ),
    .S_AXI_WSTRB        ( s_axil_wstrb      ),
    .S_AXI_WVALID       ( s_axil_wvalid     ),
    .S_AXI_WREADY       ( s_axil_wready     ),
    .S_AXI_BRESP        ( s_axil_bresp      ),
    .S_AXI_BVALID       ( s_axil_bvalid     ),
    .S_AXI_BREADY       ( s_axil_bready     ),
    .S_AXI_ARADDR       ( s_axil_araddr     ),
    .S_AXI_ARVALID      ( s_axil_arvalid    ),
    .S_AXI_ARREADY      ( s_axil_arready    ),
    .S_AXI_RDATA        ( s_axil_rdata      ),
    .S_AXI_RRESP        ( s_axil_rresp      ),
    .S_AXI_RVALID       ( s_axil_rvalid     ),
    .S_AXI_RREADY       ( s_axil_rready     ),
    .read_reg_0x0       ( read_reg_0x0      ),
    .read_reg_0x4       ( read_reg_0x4      ),
    .read_reg_0x8       ( read_reg_0x8      ),
    .read_reg_0xc       ( read_reg_0xc      ),
    .read_reg_0x10      ( read_reg_0x10     ),
    .read_reg_0x14      ( read_reg_0x14     ),
    .read_reg_0x18      ( read_reg_0x18     ),
    .read_reg_0x1c      ( read_reg_0x1c     ),
    .read_reg_0x20      ( read_reg_0x20     ),
    .read_reg_0x24      ( read_reg_0x24     ),
    .in_reg0            ( in_reg0           ),
    .in_reg1            ( in_reg1           ),
    .in_reg2            ( in_reg2           ),
    .in_reg3            ( in_reg3           ),
    .in_reg4            (                   ),
    .in_reg5            (                   ) 
);

// debug code 
reg [16-1:0] pack_cnt = 'd0;
always @(posedge user_clk) begin
    if(up_fifo_reset)
        pack_cnt <= #TCQ 'd0;
    else if({up_fifo_wr_true,up_fifo_rd}=='b10)
        pack_cnt <= #TCQ pack_cnt + 1;
    else if({up_fifo_wr_true,up_fifo_rd}=='b01)
        pack_cnt <= #TCQ pack_cnt - 1;
end
endmodule
