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
module xdma_app_ctrl #(
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
    // input   wire                                    sys_rst_n               ,
      
    output  reg                                     dn_irq          = 'd0   ,
    input                                           dn_irq_ack              ,
  
    // down data signals
    input                                           dn_fifo_rd              ,
    output      [127:0]                             dn_fifo_q               ,
    output                                          dn_fifo_emp             ,
    
    // startup flash
    output                                          erase_multiboot_o       ,
    input                                           erase_finish_i          ,
    output                                          startup_rst_o           ,
    output                                          startup_finish_o        ,
    output                                          startup_pack_vld_o      ,
    output      [15:0]                              startup_pack_cnt_o      ,
    output      [15:0]                              startup_pack_finish_cnt_o   ,
    output                                          startup_vld_o           ,
    output      [31:0]                              startup_data_o          ,
    output                                          read_flash_o            ,
    input                                           startup_ack_i           ,
    input                                           startup_finish_ack_i    ,

    // communication register
    input       [31:0]                              up_check_irq_i          ,
    input       [31:0]                              up_check_frame_i        ,
    input       [31:0]                              irq_timeout_fault_cnt_i ,
    output                                          debug_register_rst_o    ,
    output                                          xdma_vout_state_rst_o   ,
    input       [31:0]                              xdma_idle_time_max_i    ,
    input       [31:0]                              xdma_hold_time_max_i    ,
    input                                           CHANNEL_UP_DONE1        ,
    input                                           CHANNEL_UP_DONE2        ,
    input                                           ddr3_init_done          ,
    input       [32-1:0]                            aurora_pmt_soft_err_i   ,
    input       [32-1:0]                            aurora_timing_soft_err_i,
    input       [32-1:0]                            pmt_overflow_cnt_i      ,
    input       [32-1:0]                            encode_overflow_cnt_i   ,
    input       [32-1:0]                            pmt_lose_pack_cnt_i     ,
    input       [32-1:0]                            pmt_lose_pack_mem_cnt_i ,
    input       [32-1:0]                            wr_frame_cnt_i          ,
    input       [32-1:0]                            rd_frame_cnt_i          ,
    input       [32-1:0]                            err_state_cnt_i         ,
    input       [32-1:0]                            Xencode_skip_cnt_i      ,
    input       [32-1:0]                            ddr_last_pack_cnt_i     ,
    input       [32-1:0]                            ddr_usage_max_i         ,
    input       [32-1:0]                            eds_aurora_pack_cnt_i   ,
    input       [32-1:0]                            pmt_aurora_pack_cnt_i   ,
    input       [32-1:0]                            fbc_aurora_pack_cnt_i   ,
    input       [32-1:0]                            eds_xdma_pack_cnt_i     ,
    input       [32-1:0]                            pmt_xdma_pack_cnt_i     ,
    input       [32-1:0]                            fbc_xdma_pack_cnt_i     ,

    output                                          aurora_soft_rst_o       ,
    output                                          up_err_reset_o          

);

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Parameter Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
localparam          DMA_SIZE                = 8388608;      //32'h800000 ,8MBytes
localparam          PCK_PAYLOAD_SIZE        = 24'd8388592;  //DMA_SIZE - 16Bytes
localparam          PCK_PAYLOAD_SIZE_DIV16  = 32'd524288;   //DMA_SIZE / 16Bytes  
localparam [31:0]   verision                = 'h0704;       // PCIE version
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Register Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

reg     [31:0]      data_count1             = 'd0;
reg     [7:0]       s_axi_awlen_r           = 'd0;
reg     [7:0]       axi_wvalid_cnt          = 'd0;
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Wire Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
wire                user_resetn         ;
wire                dn_fifo_wr          ;
wire                dn_fifo_full        ;

wire    [31:0]      in_reg0             ;
wire    [31:0]      in_reg1             ;
wire    [31:0]      in_reg2             ;
wire    [31:0]      in_reg3             ;
wire    [31:0]      read_reg_0x0        ;
wire    [31:0]      read_reg_0x4        ;
wire    [31:0]      read_reg_0x1c       ;
wire    [31:0]      read_reg_0x20       ;
wire    [31:0]      read_reg_0x24       ;
wire    [31:0]      read_reg_0x28       ;

//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Instance Module
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
myip_v1_0_S00_AXI myip_v1_0_S00_AXI(    
    .S_AXI_ACLK                 ( user_clk                  ),
    .S_AXI_ARESETN              ( user_rst_n                ),
    .S_AXI_AWADDR               ( s_axil_awaddr             ),
    .S_AXI_AWVALID              ( s_axil_awvalid            ),
    .S_AXI_AWREADY              ( s_axil_awready            ),
    .S_AXI_WDATA                ( s_axil_wdata              ),
    .S_AXI_WSTRB                ( s_axil_wstrb              ),
    .S_AXI_WVALID               ( s_axil_wvalid             ),
    .S_AXI_WREADY               ( s_axil_wready             ),
    .S_AXI_BRESP                ( s_axil_bresp              ),
    .S_AXI_BVALID               ( s_axil_bvalid             ),
    .S_AXI_BREADY               ( s_axil_bready             ),
    .S_AXI_ARADDR               ( s_axil_araddr             ),
    .S_AXI_ARVALID              ( s_axil_arvalid            ),
    .S_AXI_ARREADY              ( s_axil_arready            ),
    .S_AXI_RDATA                ( s_axil_rdata              ),
    .S_AXI_RRESP                ( s_axil_rresp              ),
    .S_AXI_RVALID               ( s_axil_rvalid             ),
    .S_AXI_RREADY               ( s_axil_rready             ),
    // .read_reg_0x0               ( read_reg_0x0              ),
    // .read_reg_0x4               ( read_reg_0x4              ),
    // .read_reg_0x8               ( read_reg_0x8              ),
    // .read_reg_0xc               ( read_reg_0xc              ),
    // .read_reg_0x10              ( read_reg_0x10             ),
    // .read_reg_0x14              ( read_reg_0x14             ),
    // .read_reg_0x18              ( read_reg_0x18             ),
    .read_reg_0x1c              ( read_reg_0x1c             ),
    // .read_reg_0x24              ( read_reg_0x24             ),
    .read_reg_0x28              ( read_reg_0x28             ),

    .erase_multiboot_o          ( erase_multiboot_o         ),
    .erase_finish_i             ( erase_finish_i            ),
    .startup_rst_o              ( startup_rst_o             ),
    .startup_finish_o           ( startup_finish_o          ),
    .startup_pack_vld_o         ( startup_pack_vld_o        ),
    .startup_pack_cnt_o         ( startup_pack_cnt_o        ),
    .startup_pack_finish_cnt_o  ( startup_pack_finish_cnt_o ),
    .startup_vld_o              ( startup_vld_o             ),
    .startup_data_o             ( startup_data_o            ),
    .read_flash_o               ( read_flash_o              ),
    .startup_ack_i              ( startup_ack_i             ),
    .startup_finish_ack_i       ( startup_finish_ack_i      ),

    .in_reg0                    ( in_reg0                   ),
    .in_reg1                    ( in_reg1                   ),
    .in_reg2                    ( in_reg2                   ),
    .in_reg3                    ( in_reg3                   ),
    .in_reg4                    ( verision                  ),
    .up_check_irq_i             ( up_check_irq_i            ),
    .up_check_frame_i           ( up_check_frame_i          ),
    .irq_timeout_fault_cnt_i    ( irq_timeout_fault_cnt_i   ),
    .debug_register_rst_o       ( debug_register_rst_o      ),
    .xdma_vout_state_rst_o      ( xdma_vout_state_rst_o     ),
    .xdma_idle_time_max_i       ( xdma_idle_time_max_i      ),
    .xdma_hold_time_max_i       ( xdma_hold_time_max_i      ),
    .aurora_pmt_soft_err_i      ( aurora_pmt_soft_err_i     ),
    .aurora_timing_soft_err_i   ( aurora_timing_soft_err_i  ),
    .pmt_overflow_cnt_i         ( pmt_overflow_cnt_i        ),
    .encode_overflow_cnt_i      ( encode_overflow_cnt_i     ),
    .pmt_lose_pack_cnt_i        ( pmt_lose_pack_cnt_i       ),
    .pmt_lose_pack_mem_cnt_i    ( pmt_lose_pack_mem_cnt_i   ),
    .wr_frame_cnt_i             ( wr_frame_cnt_i            ),
    .rd_frame_cnt_i             ( rd_frame_cnt_i            ),
    .err_state_cnt_i            ( err_state_cnt_i           ),
    .Xencode_skip_cnt_i         ( Xencode_skip_cnt_i        ),
    .ddr_last_pack_cnt_i        ( ddr_last_pack_cnt_i       ),
    .ddr_usage_max_i            ( ddr_usage_max_i           ),
    .eds_aurora_pack_cnt_i      ( eds_aurora_pack_cnt_i     ),
    .pmt_aurora_pack_cnt_i      ( pmt_aurora_pack_cnt_i     ),
    .fbc_aurora_pack_cnt_i      ( fbc_aurora_pack_cnt_i     ),
    .eds_xdma_pack_cnt_i        ( eds_xdma_pack_cnt_i       ),
    .pmt_xdma_pack_cnt_i        ( pmt_xdma_pack_cnt_i       ),
    .fbc_xdma_pack_cnt_i        ( fbc_xdma_pack_cnt_i       ),
    .in_reg5                    (                           ) 
);

fifo_128_128 dn (
    .rst                        ( ~user_resetn              ),      // input wire rst
    .wr_clk                     ( user_clk                  ),      // input wire wr_clk
    .rd_clk                     ( user_clk                  ),      // input wire rd_clk
    .din                        ( s_axi_wdata               ),      // input wire [127 : 0] din
    .wr_en                      ( dn_fifo_wr                ),      // input wire wr_en
    .rd_en                      ( dn_fifo_rd                ),      // input wire rd_en
    .dout                       ( dn_fifo_q                 ),      // output wire [127 : 0] dout
    .full                       (                           ),      // output wire full
    .empty                      ( dn_fifo_emp               ),      // output wire empty
    .prog_empty                 (                           ),
    .prog_full                  ( dn_fifo_full              )       // output wire prog_full
);
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Logic Design
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

assign up_err_reset_o   = read_reg_0x1c[0];
assign aurora_soft_rst_o = read_reg_0x28[0];
// assign soft_reset       = ~sys_rst_n;//~user_resetn;
assign user_resetn      = user_rst_n /*& (!read_reg_0x0[0])*/;

assign in_reg0          = 'd1;
assign in_reg1          = {31'd0,ddr3_init_done}  ;
assign in_reg2          = {31'd0,CHANNEL_UP_DONE1};
assign in_reg3          = {31'd0,CHANNEL_UP_DONE2};

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


assign s_axi_bid    = 'd0;
assign s_axi_bresp  = 'd0;

endmodule
