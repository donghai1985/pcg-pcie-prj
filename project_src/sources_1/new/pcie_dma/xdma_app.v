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
module xdma_app #(
  parameter TCQ = 1,
  parameter C_M_AXI_ID_WIDTH = 4,
  parameter C_DATA_WIDTH = 128,
  parameter C_M_AXI_DATA_WIDTH = C_DATA_WIDTH
)
(

  // AXI Memory Mapped interface
  input  wire  [C_M_AXI_ID_WIDTH-1:0] s_axi_awid,
  input  wire  [64-1:0] s_axi_awaddr,
  input  wire   [7:0] s_axi_awlen,
  input  wire   [2:0] s_axi_awsize,
  input  wire   [1:0] s_axi_awburst,
  input  wire         s_axi_awvalid,
  output reg         s_axi_awready = 'd0,
  input  wire [C_M_AXI_DATA_WIDTH-1:0]        s_axi_wdata,
  input  wire [(C_M_AXI_DATA_WIDTH/8)-1:0]    s_axi_wstrb,
  input  wire         s_axi_wlast,
  input  wire         s_axi_wvalid,
  output reg         s_axi_wready = 'd0,
  output wire [C_M_AXI_ID_WIDTH-1:0]          s_axi_bid,
  output wire   [1:0] s_axi_bresp,
  output reg         s_axi_bvalid = 'd0,
  input  wire         s_axi_bready,
  input  wire [C_M_AXI_ID_WIDTH-1:0]          s_axi_arid,
  input  wire  [64-1:0] s_axi_araddr,
  input  wire   [7:0] s_axi_arlen,
  input  wire   [2:0] s_axi_arsize,
  input  wire   [1:0] s_axi_arburst,
  input  wire         s_axi_arvalid,
  output reg         s_axi_arready = 'd0,
  output wire   [C_M_AXI_ID_WIDTH-1:0]        s_axi_rid,
  output wire   [C_M_AXI_DATA_WIDTH-1:0]      s_axi_rdata,
  output wire   [1:0] s_axi_rresp,
  output reg         s_axi_rlast,
  output reg         s_axi_rvalid,
  input  wire         s_axi_rready,
  
  
   // AXI Lite Master Interface connections
  input  wire  [31:0] s_axil_awaddr,
  input  wire         s_axil_awvalid,
  output wire         s_axil_awready,
  input  wire  [31:0] s_axil_wdata,
  input  wire   [3:0] s_axil_wstrb,
  input  wire         s_axil_wvalid,
  output wire         s_axil_wready,
  output wire   [1:0] s_axil_bresp,
  output wire         s_axil_bvalid,
  input  wire         s_axil_bready,
  input  wire  [31:0] s_axil_araddr,
  input  wire         s_axil_arvalid,
  output wire         s_axil_arready,
  output wire  [31:0] s_axil_rdata,
  output wire   [1:0] s_axil_rresp,
  output wire         s_axil_rvalid,
  input  wire         s_axil_rready,

  

  // System IO signals
  input  wire         user_clk,
  input  wire         user_rst_n,
  input  wire         user_lnk_up,
  input  wire         sys_rst_n,
  output wire   [3:0] leds,
  
  output	reg		dn_irq = 'd0,
  input				dn_irq_ack,
  output	reg		up_irq = 'd0,
  input				up_irq_ack,
  
  //////////////
  input             eds_rx_start        ,
  input             eds_rx_end          ,
  output            pcie_eds_rx_end_out ,

  input             fbc_rx_start_i      ,
  input             fbc_rx_end_i        ,
  output            pcie_fbc_rx_end_o   ,

  input             pmt_rx_start        ,
  input             pmt_rx_end          ,
  output            pcie_pmt_rx_end_out ,

  input          ddr_xdma_emp    ,
  output         up_fifo_wr      ,
  input		[127:0]	up_fifo_data	,
//   input             up_fifo_empty_i ,
  output			up_fifo_full	,
  input          up_fifo_empty   ,
  output			make_test_en	,
  
  input				dn_fifo_rd,
  output	[127:0]	dn_fifo_q,
  output			dn_fifo_emp,
  output			last_dma_en,
  
  output			soft_reset,
  input				CHANNEL_UP_DONE,
  input				CHANNEL_UP_DONE1,
  input				CHANNEL_UP_DONE2,
  input				ddr3_init_done,
 
  
  output	[31:0]		read_reg_0x8,
  output	[31:0]		read_reg_0xc,
  output	[31:0]		read_reg_0x10,
  output	[31:0]		read_reg_0x14,
  output	[31:0]		read_reg_0x18


  
);

localparam		DMA_SIZE 				= 	8388608; 		//8MB
localparam		EDS_MSG_TYPE			=	8'd2;
localparam		EDS_PAYLOAD_SIZE		=	24'd8388576;	//包头长度4*64bit   (8388608 - 32)/
localparam		EDS_PAYLOAD_SIZE_DIV16	=	32'd524286;		//EDS_PAYLOAD_SIZE/(128/8)=524286

localparam		PMT_MSG_TYPE			=	8'd1;
// localparam		PMT_PAYLOAD_SIZE		=	24'd8388592;	//包头长度2*64bit   (8388608 - 16)/
localparam		PMT_PAYLOAD_SIZE_DIV16	=	32'd524288;     //32'h80000 * 16 * 8bits 无包头

localparam      FBC_MSG_TYPE			=	8'd3;
// localparam      FBC_PAYLOAD_SIZE		=	24'd8388592;	//包头长度2*64bit   (8388608 - 16)/
localparam      FBC_PAYLOAD_SIZE_DIV16	=	32'd524288;     //32'h80000 * 16 * 8bits 无包头
// wire/reg declarations
wire			user_resetn;
reg  [25:0]     user_clk_heartbeat;

wire 			dn_fifo_wr,dn_fifo_full;


wire  			up_prog_empty;
  
wire 			up_fifo_rd;
wire up_fifo_emp;
wire [127:0] 	up_fifo_q;
wire [127:0]    up_fifo_trans;

wire [31:0]		in_reg0 ;
wire [31:0]		in_reg1 ;
wire [31:0]		in_reg2 ;
wire [31:0]		in_reg3 ;



reg  [1:0]		up_state = 'd0;
reg  [7:0]		data_cnt = 'd0;
reg  [31:0]		data_count1 = 'd0;
reg  [31:0]		data_count2 = 'd0;
reg  [7:0]		s_axi_awlen_r = 'd0;
reg  [7:0]		s_axib_awlen_r = 'd0;
reg  [7:0] 		axi_wvalid_cnt = 'd0;
reg  [7:0] 		axib_wvalid_cnt = 'd0;
reg  [7:0] 		axib_arlen_r = 'd0;
reg  [7:0] 		axi_arlen_r = 'd0;

reg  [127:0] 	dn_fifo_q_r = 'd0;
reg 	 		dn_fifo_q_error = 'd0;
wire [31:0]  	read_reg_0x0,read_reg_0x4,read_reg_0x1c,read_reg_0x20,read_reg_0x24;

reg  [31:0] 	last_dma_size = 'd0;
reg  [31:0] 	dma_wr_cnt = 'd0;
reg  			up_fifo_wr_true;
reg  [127:0] 	up_data_in_true;
reg  [4:0] 		up_fifo_wr_state;
  
reg  			up_wr_done = 'd0;
// The sys_rst_n input is active low based on the core configuration
  
// assign	last_dma_en	=	read_reg_0x1c[0];

// Create a Clock Heartbeat
always @(posedge user_clk) begin
    if(!sys_rst_n) begin
		user_clk_heartbeat <= #TCQ 26'd0;
    end else begin
		user_clk_heartbeat <= #TCQ user_clk_heartbeat + 1'b1;
    end
end


// LEDs for observation
assign leds[0] 			= sys_rst_n;
assign leds[1] 			= user_resetn;
assign leds[2] 			= user_lnk_up;
assign leds[3] 			= user_clk_heartbeat[25];

assign make_test_en 	= read_reg_0x4[0];
assign soft_reset 		= ~sys_rst_n;//~user_resetn;
assign user_resetn 		= sys_rst_n /*& (!read_reg_0x0[0])*/;

assign in_reg0 			= CHANNEL_UP_DONE 	? 'd100 : 'd0;
assign in_reg1 			= ddr3_init_done 	? 'd100 : 'd0;
assign in_reg2[31:0]    = CHANNEL_UP_DONE1 	? 'd100 : 'd0;
// assign in_reg2[31:16]   = {13'd0,pmt_fifo_biterr_state_i[1:0]};
assign in_reg3 			= CHANNEL_UP_DONE2 	? 'd100 : 'd0;
  
  
// assign up_fifo_trans	=		{up_fifo_data[7:0],up_fifo_data[15:8],up_fifo_data[23:16],up_fifo_data[31:24],
								 // up_fifo_data[39:32],up_fifo_data[47:40],up_fifo_data[55:48],up_fifo_data[63:56],
								 // up_fifo_data[71:64],up_fifo_data[79:72],up_fifo_data[87:80],up_fifo_data[95:88],
								 // up_fifo_data[103:96],up_fifo_data[111:104],up_fifo_data[119:112],up_fifo_data[127:120]
								 // };
assign up_fifo_trans	= up_fifo_data;  
   //==================================================================
  //==================================================================
  //===================================================================
  
  //==================================================================
  //==================================================================
  //===================================================================
assign dn_fifo_wr 		= s_axi_wvalid & s_axi_wready ;
  
always @ (posedge user_clk) begin
	if(!user_resetn)
		s_axi_awready <= 'd0;
	else if(s_axi_awvalid && s_axi_awready)
		s_axi_awready <= 'd0;
	else if(s_axi_awvalid && (!dn_fifo_full) && (!s_axi_wready) && (!dn_irq)) ///////////////////////////////////
		s_axi_awready <= 1;
	else
		s_axi_awready <= 0;
end
  
  
always @ (posedge user_clk) begin
	if(!user_resetn)
		s_axi_awlen_r <= 'd0;
	else if(s_axi_awvalid && s_axi_awready)
		s_axi_awlen_r <= s_axi_awlen;
end
  

always @ (posedge user_clk) begin
	if(!user_resetn)
		axi_wvalid_cnt <= 'd0;
	else if(s_axi_wready && s_axi_wvalid && (axi_wvalid_cnt >= s_axi_awlen_r))
		axi_wvalid_cnt <= 'd0;
	else if(s_axi_wready && s_axi_wvalid)
		axi_wvalid_cnt <= axi_wvalid_cnt + 1'b1;
end
  
always @ (posedge user_clk) begin
	if(!user_resetn)
		s_axi_wready <= 'd0;
	// else if(s_axi_wready && s_axi_wvalid && s_axi_wlast)
	else if(s_axi_wready && s_axi_wvalid && (axi_wvalid_cnt >= s_axi_awlen_r))
		s_axi_wready <= 0;
	else if(s_axi_awvalid && s_axi_awready)
		s_axi_wready <= 1;
end
  
  
always @ (posedge user_clk) begin
	if(!user_resetn)
		s_axi_bvalid <= 'd0;
	else if(s_axi_bvalid && s_axi_bready)
		s_axi_bvalid <= 0;
	else if(s_axi_wvalid && s_axi_wready && s_axi_wlast)
		s_axi_bvalid <= 1;
end

  
always @ (posedge user_clk) begin
	if(!user_resetn) begin
		data_count1 <= 'd0;
		dn_irq <= 'd0;
	end
	else if(dn_irq && dn_irq_ack) begin
		dn_irq <= 0;
		data_count1 <= 'd0;
	end
	else if(s_axi_wvalid && s_axi_wready && data_count1 == 'd8388592) begin
		data_count1 <= 'd0;
		dn_irq <= 1;
	end
	else if(s_axi_wvalid && s_axi_wready) begin
		data_count1 <= data_count1 + 16;
		dn_irq <= 0;
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
//=========================================================
//=========================================================
//=========================================================

reg			eds_rx_start_reg1;
reg			eds_rx_start_reg2;
wire		eds_rx_start_pose;
reg			eds_rx_end_reg1;
reg			eds_rx_end_reg2;
reg			eds_rx_end_flag;

reg			fbc_rx_start_reg1;
reg			fbc_rx_start_reg2;
wire		fbc_rx_start_pose;
reg			fbc_rx_end_reg1;
reg			fbc_rx_end_reg2;
reg			fbc_rx_end_flag = 'd0;

reg			pmt_rx_start_reg1;
reg			pmt_rx_start_reg2;
wire		pmt_rx_start_pose;
reg			pmt_rx_end_reg1;
reg			pmt_rx_end_reg2;
reg			pmt_rx_end_flag;
reg	[30:0]	seq_id;
reg	[31:0]	rx_cnt;

reg	[15:0]	exp_cnt;

reg	[3:0]	time_out_state;
reg	[31:0]	time_out_cnt;
reg			pcie_eds_rx_end;
reg			pcie_eds_rx_end2;
reg			pcie_pmt_rx_end;
reg			pcie_pmt_rx_end2;
reg         pcie_fbc_rx_end;
reg         pcie_fbc_rx_end2;

assign      pcie_eds_rx_end_out = pcie_eds_rx_end || pcie_eds_rx_end2;
assign      pcie_pmt_rx_end_out = pcie_pmt_rx_end || pcie_pmt_rx_end2;
assign      pcie_fbc_rx_end_o   = pcie_fbc_rx_end || pcie_fbc_rx_end2;

always @ (posedge user_clk)
begin
	// if(!user_resetn) begin
	// 	eds_rx_start_reg1	<=	1'b0;
	// 	eds_rx_start_reg2	<=	1'b0;
	// 	eds_rx_end_reg1		<=	1'b0;
	// 	eds_rx_end_reg2		<=	1'b0;
	// 	pmt_rx_start_reg1	<=	1'b0;
	// 	pmt_rx_start_reg2	<=	1'b0;
	// 	pmt_rx_end_reg1		<=	1'b0;
	// 	pmt_rx_end_reg2		<=	1'b0;
	// end
	// else begin
		eds_rx_start_reg1	<=	eds_rx_start;
		eds_rx_start_reg2	<=	eds_rx_start_reg1;
		eds_rx_end_reg1		<=	eds_rx_end;
		eds_rx_end_reg2		<=	eds_rx_end_reg1;
		pmt_rx_start_reg1	<=	pmt_rx_start;
		pmt_rx_start_reg2	<=	pmt_rx_start_reg1;
		pmt_rx_end_reg1		<=	pmt_rx_end;
		pmt_rx_end_reg2		<=	pmt_rx_end_reg1;
        
        fbc_rx_start_reg1   <=  fbc_rx_start_i;
        fbc_rx_start_reg2   <=  fbc_rx_start_reg1;
        fbc_rx_end_reg1     <=  fbc_rx_end_i;
        fbc_rx_end_reg2     <=  fbc_rx_end_reg1;
	// end
end

assign	eds_rx_start_pose	=	eds_rx_start_reg1 && (~eds_rx_start_reg2);
assign	fbc_rx_start_pose	=	fbc_rx_start_reg1 && (~fbc_rx_start_reg2);
assign	pmt_rx_start_pose	=	pmt_rx_start_reg1 && (~pmt_rx_start_reg2);

wire  up_fifo_reset = (~user_resetn);
wire  pcie_state_start = eds_rx_start_pose || pmt_rx_start_pose;

fifo_128_128 up (
	.rst(up_fifo_reset),              // input wire rst
	.wr_clk(user_clk),        // input wire wr_clk
	.rd_clk(user_clk),        // input wire rd_clk
	.din(up_data_in_true),              // input wire [127 : 0] din
	.wr_en(up_fifo_wr_true),          // input wire wr_en
	.rd_en(up_fifo_rd),          // input wire rd_en
	.dout(up_fifo_q),            // output wire [127 : 0] dout
	.full(),            // output wire full
	.empty(up_fifo_emp),          // output wire empty
	.prog_empty(up_prog_empty),
	.prog_full(up_fifo_full)  // output wire prog_full
);

// assign	up_fifo_full = 1'b0;		//test
  
always @ (posedge user_clk) begin
	if(up_fifo_reset) 
		dma_wr_cnt <= 'd0;
	else if(up_fifo_wr_true && dma_wr_cnt >= DMA_SIZE - 'd16)
		dma_wr_cnt <= 'd0;
	else if(up_fifo_wr_true)
		dma_wr_cnt <= dma_wr_cnt + 'd16;
end
  
  
reg [31:0] 	delay_cnt = 'd0;
reg  		rd_start  = 'd0;
 
  
always @ (posedge user_clk) begin
	if(up_fifo_reset || eds_rx_start_reg2 || pmt_rx_start_reg2)
		rd_start <= 'd0;
	else if(up_fifo_rd)
		rd_start <= 1;	
end
  
always @ (posedge user_clk) begin
	if(up_fifo_reset || eds_rx_start_reg2 || pmt_rx_start_reg2)
		delay_cnt <= 'd0;
	else if(rd_start) begin
		if(up_fifo_rd)
			delay_cnt <= 0;
		else 
			delay_cnt <= delay_cnt + 1'b1;
	end
	else
		delay_cnt <= 0;
			
end


always @ (posedge user_clk) begin
    if(fbc_rx_end_reg2) begin
        fbc_rx_end_flag <=  1'b1;
    end
    else if(up_fifo_wr_state == 'd14)begin
        fbc_rx_end_flag <=  'b0;
    end
end

always @ (posedge user_clk) begin
	if(up_fifo_reset || eds_rx_start_reg2 || pmt_rx_start_reg2)
		up_wr_done <= 'd0;
	else if(delay_cnt[26])
		up_wr_done <= 1;
			
end


always @ (posedge user_clk)
begin
	if(!user_resetn) begin
		up_fifo_wr_state	<=	'd0;
	end
	else if(pcie_state_start) begin
		up_fifo_wr_state	<=	'd0;
	end
	else begin
		case(up_fifo_wr_state)
		'd0: begin
			if(eds_rx_start_reg2) begin
				up_fifo_wr_state	<=	'd1;
			end
			else if(pmt_rx_start_reg2) begin
				up_fifo_wr_state	<=	'd9;
			end
            else if(fbc_rx_start_reg2) begin
                up_fifo_wr_state    <=  'd13;
            end
			else begin
				up_fifo_wr_state	<=	'd0;
			end
		end
		'd1: begin
			if(eds_rx_end_reg2) begin
				up_fifo_wr_state	<=	'd5;
			end
			else if((~up_fifo_empty) && (~up_fifo_full)) begin
				up_fifo_wr_state	<=	up_fifo_wr_state + 1'd1;
			end
			else begin
				up_fifo_wr_state	<=	up_fifo_wr_state;
			end
		end
		'd2: begin
			if(~up_fifo_full) begin
				up_fifo_wr_state	<= up_fifo_wr_state + 1'd1;
			end
			else begin
				up_fifo_wr_state	<= up_fifo_wr_state;
			end
		end
		'd3: begin
			if(up_fifo_wr && (rx_cnt == EDS_PAYLOAD_SIZE_DIV16 - 1'd1)) begin
				up_fifo_wr_state	<= up_fifo_wr_state + 1'd1;
			end
			else begin
				up_fifo_wr_state	<= up_fifo_wr_state;
			end
		end
		'd4: begin
			if(eds_rx_end_flag || eds_rx_end_reg2) begin
				up_fifo_wr_state	<= up_fifo_wr_state + 1'd1;
			end
			else begin
				up_fifo_wr_state	<= 'd1;
			end
		end
		'd5: begin
			if(~up_fifo_full) begin
				up_fifo_wr_state	<=	up_fifo_wr_state + 1'd1;
			end
			else begin
				up_fifo_wr_state	<=	up_fifo_wr_state;
			end
		end
		'd6: begin
			if(~up_fifo_full) begin
				up_fifo_wr_state	<= up_fifo_wr_state + 1'd1;
			end
			else begin
				up_fifo_wr_state	<= up_fifo_wr_state;
			end
		end
		'd7: begin
			if((~up_fifo_full) && (rx_cnt == EDS_PAYLOAD_SIZE_DIV16 - 1'd1)) begin
				up_fifo_wr_state	<= up_fifo_wr_state + 1'd1;
			end
			else begin
				up_fifo_wr_state	<= up_fifo_wr_state;
			end
		end
		'd8: begin
			if(exp_cnt == 'd30) begin
				up_fifo_wr_state	<=	'd0;
			end
			else begin
				up_fifo_wr_state	<=	up_fifo_wr_state;
			end
		end
		
		'd9: begin
			if(up_fifo_wr && (rx_cnt == PMT_PAYLOAD_SIZE_DIV16 - 1'd1)) begin
				up_fifo_wr_state	<= up_fifo_wr_state + 1'd1;
			end
			else begin
				up_fifo_wr_state	<= up_fifo_wr_state;
			end
		end
		'd10: begin
			if(pmt_rx_end_flag || pmt_rx_end_reg2) begin
				up_fifo_wr_state	<= up_fifo_wr_state + 1'd1;
			end
			else begin
				up_fifo_wr_state	<= 'd9;
			end
		end
		'd11: begin
			if((~up_fifo_full) && (rx_cnt == PMT_PAYLOAD_SIZE_DIV16 - 1'd1)) begin
				up_fifo_wr_state	<= up_fifo_wr_state + 1'd1;
			end
			else begin
				up_fifo_wr_state	<= up_fifo_wr_state;
			end
		end
        'd12: begin
            if(exp_cnt == 'd30) begin
                up_fifo_wr_state    <=  'd0;
            end
            else begin
                up_fifo_wr_state    <=  up_fifo_wr_state;
            end
        end

        'd13: begin
            if((up_fifo_wr || (fbc_rx_end_flag && ddr_xdma_emp && ~up_fifo_full)) && (rx_cnt == FBC_PAYLOAD_SIZE_DIV16 - 1'd1)) begin
                up_fifo_wr_state    <=  up_fifo_wr_state + 1'd1;
            end
            else begin
                up_fifo_wr_state    <=  up_fifo_wr_state;
            end
        end
        'd14: begin
            if(fbc_rx_end_flag || fbc_rx_end_reg2) begin
                up_fifo_wr_state    <=  up_fifo_wr_state + 1'd1;
            end
            else begin
                up_fifo_wr_state    <=  'd13;
            end
        end
        'd15: begin
            if((~up_fifo_full) && (rx_cnt == FBC_PAYLOAD_SIZE_DIV16 - 1'd1)) begin
                up_fifo_wr_state    <=  up_fifo_wr_state + 1'd1;
            end
            else begin
                up_fifo_wr_state    <=  up_fifo_wr_state;
            end
        end
        'd16: begin
            if(exp_cnt == 'd30) begin
                up_fifo_wr_state    <=  'd0;
            end
            else begin
                up_fifo_wr_state    <=  up_fifo_wr_state;
            end
        end

        default: begin
            up_fifo_wr_state    <=  'd0;
        end
        endcase
    end
end

assign	up_fifo_wr = ((up_fifo_wr_state == 'd3) || (up_fifo_wr_state == 'd9) || (up_fifo_wr_state == 'd13)) ? ((~up_fifo_empty) && (~up_fifo_full)) : 1'b0;

always @ (posedge user_clk)
begin
	if(!user_resetn) begin
		up_fifo_wr_true <= 	1'b0;
		up_data_in_true <= 	'd0;
		seq_id		<=	'd0;
		rx_cnt		<=	'd0;
		pcie_eds_rx_end	<=	1'b0;
		pcie_pmt_rx_end	<=	1'b0;
		eds_rx_end_flag	<=	1'b0;
		pmt_rx_end_flag	<=	1'b0;
		exp_cnt			<=	'd0;
	end
	else if(pcie_state_start) begin
		up_fifo_wr_true <= 	1'b0;
		up_data_in_true <= 	'd0;
		seq_id		<=	'd0;
		rx_cnt		<=	'd0;
		pcie_eds_rx_end	<=	1'b0;
		pcie_pmt_rx_end	<=	1'b0;
		eds_rx_end_flag	<=	1'b0;
		pmt_rx_end_flag	<=	1'b0;
		exp_cnt			<=	'd0;
	end
	else begin
		case(up_fifo_wr_state)
		'd0: begin
			up_fifo_wr_true <= 	1'b0;
			up_data_in_true <= 	'd0;
			seq_id		<=	'd0;
			rx_cnt		<=	'd0;
			pcie_eds_rx_end	<=	1'b0;
			pcie_pmt_rx_end	<=	1'b0;
			eds_rx_end_flag	<=	1'b0;
			pmt_rx_end_flag	<=	1'b0;
			exp_cnt			<=	'd0;
		end
		'd1: begin
			rx_cnt		<=	'd0;
			eds_rx_end_flag	<=	1'b0;
			exp_cnt			<=	'd0;
			pcie_eds_rx_end	<=	1'b0;
			if(eds_rx_end_reg2) begin
				up_fifo_wr_true <= 1'b0;
				seq_id		<=	seq_id;
				up_data_in_true <= 'd0;
			end
			else if((~up_fifo_empty) && (~up_fifo_full)) begin
				up_fifo_wr_true <= 1'b1;
				seq_id		<=	seq_id + 1'd1;
				up_data_in_true <= 	{64'd0,1'b1,seq_id,EDS_MSG_TYPE,EDS_PAYLOAD_SIZE};		// 1bit TB + 31bit ID + 8bit msgtype + 24bit payloadsize
			end
			else begin
				up_fifo_wr_true <= 1'b0;
				seq_id		<=	seq_id;
				up_data_in_true <= 'd0;
			end
		end
		'd2: begin
			up_data_in_true	<=	'd0;
			seq_id		<=	seq_id;
			rx_cnt		<=	'd0;
			exp_cnt			<=	'd0;
			if(~up_fifo_full) begin
				up_fifo_wr_true <=  1'b1;
			end
			else begin
				up_fifo_wr_true <=  1'b0;
			end
			
			if(eds_rx_end_reg2) begin
				eds_rx_end_flag	<=	1'b1;
			end
			else begin
				eds_rx_end_flag	<=	eds_rx_end_flag;
			end
		end
		'd3: begin
			seq_id		<=	seq_id;
			exp_cnt			<=	'd0;
			if(up_fifo_wr && (rx_cnt == EDS_PAYLOAD_SIZE_DIV16 - 1'd1)) begin
				up_fifo_wr_true <= 	1'b1;
				up_data_in_true	<=	up_fifo_trans;
				rx_cnt		<=	'd0;
			end
			else if(up_fifo_wr) begin
				up_fifo_wr_true <= 	1'b1;
				up_data_in_true	<=	up_fifo_trans;
				rx_cnt		<=	rx_cnt + 1'd1;
			end
			else begin
				up_fifo_wr_true <= 	1'b0;
				up_data_in_true	<=	'd0;
				rx_cnt		<=	rx_cnt;
			end
			
			if(eds_rx_end_reg2) begin
				eds_rx_end_flag	<=	1'b1;
			end
			else begin
				eds_rx_end_flag	<=	eds_rx_end_flag;
			end
		end	
		'd4: begin
			up_fifo_wr_true <= 	1'b0;
			up_data_in_true	<=	'd0;
			rx_cnt		<=	'd0;
			seq_id	<=	seq_id;
			exp_cnt			<=	'd0;
			eds_rx_end_flag	<= 1'b0;
		end
		'd5: begin
			eds_rx_end_flag	<=	1'b0;
			rx_cnt		<=	'd0;
			exp_cnt			<=	'd0;
			if(~up_fifo_full) begin
				up_fifo_wr_true <= 1'b1;
				seq_id		<=	'd0;
				up_data_in_true <= {64'd0,1'b0,seq_id,EDS_MSG_TYPE,EDS_PAYLOAD_SIZE};		// 1bit TB + 31bit ID + 8bit msgtype + 24bit payloadsize
			end
			else begin
				up_fifo_wr_true <= 1'b0;
				seq_id		<=	seq_id;
				up_data_in_true <= 'd0;
			end
		end
		'd6: begin
			up_data_in_true	<=	'd0;
			seq_id		<=	'd0;
			rx_cnt		<= 'd0;
			if(~up_fifo_full) begin
				up_fifo_wr_true <=  1'b1;
			end
			else begin
				up_fifo_wr_true <=  1'b0;
			end
		end
		'd7: begin
			up_data_in_true	<=	'd0;
			seq_id		<=	'd0;
			if((~up_fifo_full) && (rx_cnt == EDS_PAYLOAD_SIZE_DIV16 - 1'd1)) begin
				up_fifo_wr_true <= 	1'b1;
				rx_cnt		<=	'd0;
			end
			else if(~up_fifo_full) begin
				up_fifo_wr_true <= 	1'b1;
				rx_cnt		<=	rx_cnt + 1'd1;
			end
			else begin
				up_fifo_wr_true <= 	1'b0;
				rx_cnt		<=	rx_cnt;
			end
		end	
		'd8: begin
			up_fifo_wr_true <= 	1'b0;
			up_data_in_true <= 	'd0;
			seq_id		<=	'd0;
			rx_cnt		<=	'd0;
			eds_rx_end_flag	<=	1'b0;
			if(exp_cnt == 'd30) begin
				pcie_eds_rx_end	<=	1'b0;
				exp_cnt	<= 'd0;
			end
			else begin
				pcie_eds_rx_end	<=	1'b1;
				exp_cnt	<= exp_cnt + 1'd1;
			end
		end
		
		'd9: begin
			// seq_id		<=	seq_id;
			exp_cnt			<=	'd0;
			if(up_fifo_wr && (rx_cnt == PMT_PAYLOAD_SIZE_DIV16 - 1'd1)) begin
				up_fifo_wr_true <= 	1'b1;
				up_data_in_true	<=	up_fifo_trans;
				rx_cnt		<=	'd0;
			end
			else if(up_fifo_wr) begin
				up_fifo_wr_true <= 	1'b1;
				up_data_in_true	<=	up_fifo_trans;
				rx_cnt		<=	rx_cnt + 1'd1;
			end
			else begin
				up_fifo_wr_true <= 	1'b0;
				up_data_in_true	<=	'd0;
				rx_cnt		<=	rx_cnt;
			end
			
			if(pmt_rx_end_reg2) begin
				pmt_rx_end_flag	<=	1'b1;
			end
			else begin
				pmt_rx_end_flag	<=	pmt_rx_end_flag;
			end
		end	
		'd10: begin
			up_fifo_wr_true <= 	1'b0;
			up_data_in_true	<=	'd0;
			rx_cnt		<=	'd0;
			// seq_id	<=	seq_id + 1'd1;
			exp_cnt			<=	'd0;
			pmt_rx_end_flag	<= 1'b0;
		end
		'd11: begin
			up_data_in_true	<=	'd0;
			// seq_id		<=	seq_id;
			if((~up_fifo_full) && (rx_cnt == PMT_PAYLOAD_SIZE_DIV16 - 1'd1)) begin
				up_fifo_wr_true <= 	1'b1;
				rx_cnt		<=	'd0;
			end
			else if(~up_fifo_full) begin
				up_fifo_wr_true <= 	1'b1;
				rx_cnt		<=	rx_cnt + 1'd1;
			end
			else begin
				up_fifo_wr_true <= 	1'b0;
				rx_cnt		<=	rx_cnt;
			end
		end	
		'd12: begin
			up_fifo_wr_true <= 	1'b0;
			up_data_in_true <= 	'd0;
			// seq_id		<=	seq_id;
			rx_cnt		<=	'd0;
			pmt_rx_end_flag	<=	1'b0;
			if(exp_cnt == 'd30) begin
				pcie_pmt_rx_end	<=	1'b0;
				exp_cnt	<= 'd0;
			end
			else begin
				pcie_pmt_rx_end	<=	1'b1;
				exp_cnt	<= exp_cnt + 1'd1;
			end
		end

        
        'd13: begin
            if(up_fifo_wr && (rx_cnt == FBC_PAYLOAD_SIZE_DIV16 - 1'd1)) begin
                up_fifo_wr_true <=  1'b1;
                up_data_in_true <=  up_fifo_trans;
                rx_cnt          <=  'd0;
            end
            else if(up_fifo_wr) begin
                up_fifo_wr_true <=  1'b1;
                up_data_in_true <=  up_fifo_trans;
                rx_cnt          <=  rx_cnt + 1'd1;
            end
            else if(fbc_rx_end_flag && ddr_xdma_emp && ~up_fifo_full && (rx_cnt == FBC_PAYLOAD_SIZE_DIV16 - 1'd1)) begin
                up_fifo_wr_true <=  'b1;
                up_data_in_true <=  'd0;
                rx_cnt          <=  'd0;
            end
            else if(fbc_rx_end_flag && ddr_xdma_emp && ~up_fifo_full)begin
                up_fifo_wr_true <=  'b1;
                up_data_in_true <=  'd0;
                rx_cnt          <=  rx_cnt + 1'd1;
            end
            else begin
                up_fifo_wr_true <=  1'b0;
            end
            
        end	
        'd14: begin
            up_fifo_wr_true <=  'b0;
            up_data_in_true <=  'd0;
            rx_cnt          <=  'd0;
        end
        'd15: begin
            up_data_in_true <=  'd0;
            if((~up_fifo_full) && (rx_cnt == FBC_PAYLOAD_SIZE_DIV16 - 1'd1)) begin
                up_fifo_wr_true <=  'b1;
                rx_cnt          <=  'd0;
            end
            else if(~up_fifo_full) begin
                up_fifo_wr_true <=  1'b1;
                rx_cnt          <=  rx_cnt + 1'd1;
            end
            else begin
                up_fifo_wr_true <=  1'b0;
                rx_cnt          <=  rx_cnt;
            end
        end	
        'd16: begin
            up_fifo_wr_true <=  'b0;
            up_data_in_true <=  'd0;
            rx_cnt          <=  'd0;
            if(exp_cnt == 'd30) begin
                pcie_fbc_rx_end <=  1'b0;
                exp_cnt         <=  'd0;
            end
            else begin
                pcie_fbc_rx_end <=  1'b1;
                exp_cnt         <=  exp_cnt + 1'd1;
            end
        end
        default: begin
            up_fifo_wr_true <=  'b0;
            up_data_in_true <=  'd0;
            seq_id          <=  'd0;
            rx_cnt          <=  'd0;
            pcie_eds_rx_end <=  'b0;
            pcie_pmt_rx_end <=  'b0;
            pcie_fbc_rx_end <=  'b0;
            eds_rx_end_flag <=  'b0;
            pmt_rx_end_flag <=  'b0;
            exp_cnt         <=  'd0;
        end
        endcase
	end
end

always @ (posedge user_clk)
begin
	if(!user_resetn) begin
		time_out_state	<=	'd0;
		time_out_cnt	<=	'd0;
		pcie_eds_rx_end2<=	1'b0;
		pcie_pmt_rx_end2<=	1'b0;
		pcie_fbc_rx_end2<=	1'b0;
	end
	else if(pcie_state_start) begin
		time_out_state	<=	'd0;
		time_out_cnt	<=	'd0;
		pcie_eds_rx_end2<=	1'b0;
		pcie_pmt_rx_end2<=	1'b0;
		pcie_fbc_rx_end2<=	1'b0;
	end
	else begin
		case(time_out_state)
		4'd0: begin
			time_out_cnt	<=	'd0;
			pcie_eds_rx_end2<=	1'b0;
			pcie_pmt_rx_end2<=	1'b0;
			pcie_fbc_rx_end2<=	1'b0;
			if(eds_rx_end_reg2) begin
				time_out_state	<=	'd1;
			end
			else if(pmt_rx_end_reg2) begin
				time_out_state	<=	'd4;
			end
            else if(fbc_rx_end_reg2) begin
                time_out_state	<=	'd6;
            end
			else begin
				time_out_state	<=	'd0;
			end
		end
		4'd1: begin
			// pcie_eds_rx_end2<=	1'b0;
			// pcie_pmt_rx_end2<=	1'b0;
			if(pcie_eds_rx_end) begin
				time_out_cnt	<=	'd0;
				time_out_state	<=	'd0;
			end
			else if(time_out_cnt == 'd50000000) begin
				time_out_cnt	<=	'd0;
				time_out_state	<=	time_out_state + 1'd1;
			end
			else begin
				time_out_cnt	<=	time_out_cnt + 1'd1;
				time_out_state	<=	time_out_state;
			end
		end
		4'd2: begin
			// pcie_pmt_rx_end2<=	1'b0;
			if(time_out_cnt == 'd30) begin
				time_out_cnt	<=	'd0;
				time_out_state	<=	'd0;
				pcie_eds_rx_end2<=	1'b0;
			end
			else begin
				time_out_cnt	<=	time_out_cnt + 1'd1;
				time_out_state	<=	time_out_state;
				pcie_eds_rx_end2<=	1'b1;
			end
		end
		
		4'd4: begin
			// pcie_eds_rx_end2<=	1'b0;
			// pcie_pmt_rx_end2<=	1'b0;
			if(pcie_pmt_rx_end) begin
				time_out_cnt	<=	'd0;
				time_out_state	<=	'd0;
			end
			else if(time_out_cnt == 'd50000000) begin
				time_out_cnt	<=	'd0;
				time_out_state	<=	time_out_state + 1'd1;
			end
			else begin
				time_out_cnt	<=	time_out_cnt + 1'd1;
				time_out_state	<=	time_out_state;
			end
		end
		4'd5: begin
			// pcie_eds_rx_end2<=	1'b0;
			if(time_out_cnt == 'd30) begin
				time_out_cnt	<=	'd0;
				time_out_state	<=	'd0;
				pcie_pmt_rx_end2<=	1'b0;
			end
			else begin
				time_out_cnt	<=	time_out_cnt + 1'd1;
				time_out_state	<=	time_out_state;
				pcie_pmt_rx_end2<=	1'b1;
			end
		end

        4'd6: begin
            if(pcie_fbc_rx_end) begin
                time_out_cnt    <=  'd0;
                time_out_state  <=  'd0;
            end
            else if(time_out_cnt == 'd50000000) begin
                time_out_cnt    <=  'd0;
                time_out_state  <=  time_out_state + 1'd1;
            end
            else begin
                time_out_cnt    <=  time_out_cnt + 1'd1;
                time_out_state  <=  time_out_state;
            end
        end
        4'd7: begin
            if(time_out_cnt == 'd30) begin
                time_out_cnt    <=  'd0;
                time_out_state  <=  'd0;
                pcie_fbc_rx_end2<=  1'b0;
            end
            else begin
                time_out_cnt    <=  time_out_cnt + 1'd1;
                time_out_state  <=  time_out_state;
                pcie_fbc_rx_end2<=  1'b1;
            end
        end
		default: begin
			time_out_state	<=	'd0;
			time_out_cnt	<=	'd0;
			pcie_eds_rx_end2<=	1'b0;
			pcie_pmt_rx_end2<=	1'b0;
			pcie_fbc_rx_end2<=	1'b0;
		end
		endcase
	end
end
		

always @ (posedge user_clk) begin
	if(up_fifo_reset) 
		last_dma_size <= 'd0;
	else if(last_dma_en)
		last_dma_size <= dma_wr_cnt;
end
   
assign up_fifo_rd = s_axi_rready && s_axi_rvalid;
assign s_axi_rdata = up_fifo_q;


always @ (posedge user_clk) begin
	if(!user_resetn) begin
		up_state <= 'd0;
		s_axi_arready <= 'd0;
		s_axi_rvalid <= 'd0;
		s_axi_rlast <= 'd0;
		data_cnt <= 'd0;
		axi_arlen_r <= 'd0;
		data_count2 <= 'd0;
		up_irq <= 'd0;
	end
	else if(eds_rx_start_pose || pmt_rx_start_pose) begin
		up_state <= 'd0;
		s_axi_arready <= 'd0;
		s_axi_rvalid <= 'd0;
		s_axi_rlast <= 'd0;
		data_cnt <= 'd0;
		axi_arlen_r <= 'd0;
		data_count2 <= 'd0;
		up_irq <= 'd0;
	end
	else begin
		case(up_state)
			2'd0 : begin
				if(s_axi_arvalid && s_axi_arready) begin
					s_axi_arready <= 1'b0;
					up_state <= 'd1;
					axi_arlen_r <= s_axi_arlen;
				end
				else if(s_axi_arvalid && (!up_prog_empty)) begin
					s_axi_arready <= 1'b1;
				end
				else begin
					up_state <= 'd0;
				end
				s_axi_rvalid <= 'd0;
				s_axi_rlast <= 'd0;
				data_cnt <= 'd0;
				data_count2 <= data_count2;
				up_irq <= 'd0;
			end
			2'd1 : begin
				if(s_axi_rready && s_axi_rvalid && s_axi_rlast)
					s_axi_rvalid <= 1'b0;
				// else if(s_axi_rready) 
					// s_axi_rvalid <= 1;
				// else if(up_irq)
					// s_axi_rvalid <= 0;
				else 
					s_axi_rvalid <= 1'b1;
				//-----------------------------------------	
				if(s_axi_rready && s_axi_rvalid && s_axi_rlast/* && (!up_irq)*/) begin
					data_cnt <= 'd0;
					up_state <= 'd2;
				end
				else if(s_axi_rready && s_axi_rvalid)	begin
					data_cnt <= data_cnt + 1'b1;
					up_state <= 'd1;
				end
				else begin
					data_cnt <= data_cnt;
					up_state <= up_state;
				end
				
				//-----------------------------------------------	
				if(s_axi_rready && s_axi_rvalid && s_axi_rlast)
					s_axi_rlast <= 1'b0;
				else if(s_axi_rready && s_axi_rvalid && (data_cnt == axi_arlen_r - 1'b1))
					s_axi_rlast <= 1'b1;
				else
					s_axi_rlast <= s_axi_rlast;
				//-----------------------------------	
				if(s_axi_rready && s_axi_rvalid && (data_count2 == 'd8388592)) begin
					data_count2 <= 'd0;
					up_irq <= 1'b1;
				end
				else if(s_axi_rready && s_axi_rvalid ) begin
					data_count2 <= data_count2 + 32'd16;
					if(up_irq && up_irq_ack)
						up_irq <= 1'b0;
					else
						up_irq <= up_irq;//0;
				end
				else if(up_irq && up_irq_ack) begin
					data_count2 <= data_count2;
					up_irq <= 1'b0;
				end
				else begin
					data_count2	<= data_count2;
				end
				
			end
			2'd2 : begin
				s_axi_arready <= 1'b0;
				s_axi_rvalid <= 1'b0;
				s_axi_rlast <= 'd0;
				data_count2 <= data_count2;
				if(up_irq && up_irq_ack) begin
					data_cnt <= 'd0;
					up_state <= 'd0;
					up_irq <= 1'b0;
				end
				else if(up_irq) begin
					data_cnt <= 'd0;
					up_state <= up_state;
					up_irq <= 1'b1;
				end
				else if(data_cnt >= 'd2) begin
					data_cnt <= 'd0;
					up_state <= 'd0;
					up_irq <= 1'b0;
				end
				else begin
					data_cnt <= data_cnt + 1'b1;
					up_state <= up_state;
					up_irq <= 1'b0;
				end
			end
		default:up_state <= 'd0;
		endcase
	end	
end
  

   
assign s_axi_rid 	= 'd0;
assign s_axi_bid 	= 'd0;
assign s_axi_bresp 	= 'd0;
assign s_axi_rresp 	= 'd0;

myip_v1_0_S00_AXI myip_v1_0_S00_AXI(	
	.S_AXI_ACLK			(user_clk),
	.S_AXI_ARESETN		(user_rst_n),
	.S_AXI_AWADDR		(s_axil_awaddr),
	.S_AXI_AWVALID		(s_axil_awvalid),
	.S_AXI_AWREADY		(s_axil_awready),
	.S_AXI_WDATA		(s_axil_wdata),   
	.S_AXI_WSTRB		(s_axil_wstrb),
	.S_AXI_WVALID		(s_axil_wvalid),
	.S_AXI_WREADY		(s_axil_wready),
	.S_AXI_BRESP		(s_axil_bresp),
	.S_AXI_BVALID		(s_axil_bvalid),
	.S_AXI_BREADY		(s_axil_bready),
	.S_AXI_ARADDR		(s_axil_araddr),
	.S_AXI_ARVALID		(s_axil_arvalid),
	.S_AXI_ARREADY		(s_axil_arready),
	.S_AXI_RDATA		(s_axil_rdata),
	.S_AXI_RRESP		(s_axil_rresp),
	.S_AXI_RVALID		(s_axil_rvalid),
	.S_AXI_RREADY		(s_axil_rready),
	.read_reg_0x0		(read_reg_0x0),
	.read_reg_0x4		(read_reg_0x4),
	.read_reg_0x8		(read_reg_0x8),
	.read_reg_0xc		(read_reg_0xc),		
	.read_reg_0x10		(read_reg_0x10),		
	.read_reg_0x14		(read_reg_0x14),		
	.read_reg_0x18		(read_reg_0x18),		
	.read_reg_0x1c		(read_reg_0x1c),		
	.read_reg_0x20		(read_reg_0x20),		
	.read_reg_0x24		(read_reg_0x24),		
	.in_reg0			(in_reg0),
	.in_reg1			(in_reg1),
	.in_reg2			(in_reg2),
	.in_reg3            (in_reg3),
	.in_reg4            (last_dma_size),
	.in_reg5            ({31'd0,up_wr_done})
);

// wire	error;
// reg		len_error;
// reg		total_error;

// always @ (posedge user_clk) begin
// 	if(!user_resetn) begin
// 		len_error	<=	1'b0;
// 		total_error	<=	1'b0;
// 	end
// 	else if(pcie_state_start) begin
// 		len_error	<=	1'b0;
// 		total_error	<=	1'b0;
// 	end
// 	else if(up_state == 2'd1) begin
// 		if(axi_arlen_r == 8'd255) begin
// 			len_error	<=	len_error;
// 		end
// 		else begin
// 			len_error	<=	1'b1;
// 		end
// 		if((data_count2 == 'd8388592)) begin
// 			if(s_axi_rlast)
// 				total_error	<=	total_error;
// 			else
// 				total_error	<=	1'b1;
// 		end
// 		else begin
// 			total_error	<=	total_error;
// 		end
// 	end
// 	else begin
// 		len_error	<=	len_error;
// 		total_error	<=	total_error;
// 	end
// end

// reg	[15:0]	test_cnt;
// reg	[35:0]	test_cnt_2;
// reg			pmt_data_error;
// reg	[127:0]	pmt_err_latch = 'd0;

// always @(posedge user_clk)
// begin
// 	if(!user_resetn) begin
// 		test_cnt		<=	'd0;
// 		test_cnt_2		<=	'd0;
// 		pmt_data_error	<=	1'b0;
// 	end
// 	else if(pcie_state_start) begin
// 		test_cnt		<=	'd0;
// 		test_cnt_2		<=	'd0;
// 		pmt_data_error	<=	1'b0;
//         pmt_err_latch   <= 'd0;
// 	end
// 	else if(s_axi_rready && s_axi_rvalid) begin
// 		test_cnt		<=	test_cnt + 'd2;
// 		test_cnt_2		<=	test_cnt_2 + 'd2;
//         if((s_axi_rdata[35:0] == {test_cnt_2}) && (s_axi_rdata[99:64] == {test_cnt_2 + 36'd1})) begin
//             pmt_data_error	<=	pmt_data_error;
//         end
//         else begin
//             pmt_err_latch   <= s_axi_rdata;
//             pmt_data_error	<=	1'b1;
//         end
// 		// if((s_axi_rdata[63:0] == {12'h800,test_cnt_2,test_cnt}) && (s_axi_rdata[127:64] == {12'h800,test_cnt_2 + 36'd1,test_cnt + 16'd1})) begin
// 		// 	pmt_data_error	<=	pmt_data_error;
// 		// end
// 		// else if(s_axi_rdata == 'd0) begin
// 		// 	pmt_data_error	<=	pmt_data_error;
// 		// end
// 		// else begin
// 		// 	pmt_data_error	<=	1'b1;
// 		// end
// 	end
// 	else begin
// 		test_cnt		<=	test_cnt;
// 		test_cnt_2		<=	test_cnt_2;
// 		pmt_data_error	<=	pmt_data_error;
// 	end
// end

// assign	error	=	pmt_data_error || len_error || total_error;

// reg [64-1:0] last_cnt = 'd0;
// always @(posedge user_clk) begin
//     if(s_axi_rlast)
//         last_cnt <= 'd0;
//     else 
//         last_cnt <= last_cnt + 1;
// end

// reg [64-1:0] last_cnt_max = 'd0;
// always @(posedge user_clk) begin
//     if(pmt_rx_start_pose)
//         last_cnt_max <= 'd0;
//     else if(s_axi_rlast)begin
//         if(last_cnt_max < last_cnt)
//             last_cnt_max <= last_cnt;
//     end
// end
 //========================================================
 //========================================================

// ila_xdma	ila_xdma_inst(
// 	.clk(user_clk),
// 	.probe0(up_fifo_wr_true),
// 	.probe1(up_data_in_true),
// 	.probe2(up_fifo_wr_state),
// 	.probe3(up_state),
// 	.probe4({s_axi_arready,s_axi_arvalid,axi_arlen_r,s_axi_rvalid,s_axi_rready,s_axi_rlast,data_cnt,total_error,len_error,pmt_data_error}),
// 	.probe5(data_count2),
// 	.probe6(s_axi_rdata),
// 	.probe7({8'd0,up_prog_empty,up_irq,up_irq_ack,error,test_cnt_2,test_cnt})
// );

endmodule
