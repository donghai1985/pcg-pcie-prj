// (c) Copyright 2008 Xilinx, Inc. All rights reserved.
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
//

//
//  FRAME GEN
//
//
//
//  Description: This module is a pattern generator to test the Aurora
//               designs in hardware. It generates data and passes it
//               through the Aurora channel. If connected to a framing
//               interface, it generates frames of varying size and
//               separation. LFSR is used to generate the pseudo-random
//               data and lower bits of LFSR are connected to REM bus

`timescale 1 ns / 1 ps
`define DLY #1

module aurora_8b10b_1_FRAME_GEN
(
    // User Interface
    output				aurora_txen,
	input	[31:0]		aurora_txdata,
	input				aurora_tx_emp,
	
	input				pcie_eds_rx_end,
	input				pcie_pmt_rx_end,
    // System Interface
    input				USER_CLK,
    input				RESET,
    input				CHANNEL_UP,
	
	output				tx_tvalid,
	output	wire [31:0]	tx_data,
	output	wire [3:0]	tx_tkeep,
	output	wire		tx_tlast,
	input				tx_tready
);


//***************************Internal Register/Wire Declarations***************************

wire               	reset_c;

wire       			dly_data_xfer;
reg 	[4:0]  		channel_up_cnt;

reg 	[3:0]		tx_state;
reg 	[15:0]		len_cnt;

reg					pcie_eds_rx_end_reg1;
reg					pcie_eds_rx_end_reg2;
reg					pcie_eds_rx_end_reg3;
wire				up_edge_pcie_eds_rx_end;	
reg					pcie_pmt_rx_end_reg1;
reg					pcie_pmt_rx_end_reg2;
reg					pcie_pmt_rx_end_reg3;
wire				up_edge_pcie_pmt_rx_end;	

//*********************************Main Body of Code**********************************

always @ (posedge USER_CLK)
begin
	  if(RESET)
		  channel_up_cnt <= `DLY 5'd0;
	  else if(CHANNEL_UP)
			if(&channel_up_cnt)
				channel_up_cnt <= `DLY channel_up_cnt;
			else 
				channel_up_cnt <= `DLY channel_up_cnt + 1'b1;
	  else
			channel_up_cnt <= `DLY 5'd0;
end

assign dly_data_xfer = (&channel_up_cnt);

  //Generate RESET signal when Aurora channel is not ready
assign reset_c = RESET || !dly_data_xfer;

always @ (posedge USER_CLK)
begin
	if(reset_c) begin
		pcie_eds_rx_end_reg1	<=	1'b0;
		pcie_eds_rx_end_reg2	<=	1'b0;
		pcie_eds_rx_end_reg3	<=	1'b0;
		pcie_pmt_rx_end_reg1	<=	1'b0;
		pcie_pmt_rx_end_reg2	<=	1'b0;
		pcie_pmt_rx_end_reg3	<=	1'b0;
	end
	else begin
		pcie_eds_rx_end_reg1	<=	pcie_eds_rx_end;
		pcie_eds_rx_end_reg2	<=	pcie_eds_rx_end_reg1;
		pcie_eds_rx_end_reg3	<=	pcie_eds_rx_end_reg2;
		pcie_pmt_rx_end_reg1	<=	pcie_pmt_rx_end;
		pcie_pmt_rx_end_reg2	<=	pcie_pmt_rx_end_reg1;
		pcie_pmt_rx_end_reg3	<=	pcie_pmt_rx_end_reg2;
	end
end

assign	up_edge_pcie_eds_rx_end		=	pcie_eds_rx_end_reg2 && (~pcie_eds_rx_end_reg3);
assign	up_edge_pcie_pmt_rx_end		=	pcie_pmt_rx_end_reg2 && (~pcie_pmt_rx_end_reg3);
    //______________________________ Transmit Data  __________________________________   

always @(posedge USER_CLK)
begin
	if(reset_c) begin
		tx_state	<=	'd0;
	end
	else begin
		case(tx_state)
		4'd0: begin
			if(up_edge_pcie_eds_rx_end) begin
				tx_state	<=	'd1;
			end
			else if(up_edge_pcie_pmt_rx_end) begin
				tx_state	<=	'd2;
			end
			else begin
				tx_state	<=	'd0;
			end
		end
		4'd1: begin
			if(tx_tlast) begin
				tx_state	<=	'd0;
			end
			else begin
				tx_state	<=	tx_state;
			end
		end
		4'd2: begin
			if(tx_tlast) begin
				tx_state	<=	'd0;
			end
			else begin
				tx_state	<=	tx_state;
			end
		end
		default: begin
			tx_state	<=	'd0;
		end
		endcase
	end
end

always @(posedge USER_CLK)
begin
	if(reset_c) begin
		len_cnt		<=	'd0;
	end
	else begin
		case(tx_state)
		4'd0: begin
			len_cnt		<=	'd0;
		end
		4'd1: begin
			if(tx_tlast) begin
				len_cnt		<=	'd0;
			end
			else if(tx_tvalid) begin
				len_cnt		<=	len_cnt + 1'd1;
			end
			else begin
				len_cnt		<=	len_cnt;
			end
		end	
		4'd2: begin
			if(tx_tlast) begin
				len_cnt		<=	'd0;
			end
			else if(tx_tvalid) begin
				len_cnt		<=	len_cnt + 1'd1;
			end
			else begin
				len_cnt		<=	len_cnt;
			end
		end	
		default: begin
			len_cnt		<=	'd0;
		end
		endcase
	end
end       
			    

assign		aurora_txen	=	1'b0;
assign		tx_tvalid	=	(tx_state == 4'd1)	?	tx_tready 	:
							(tx_state == 4'd2)	?	tx_tready	: 1'b0;
assign		tx_tkeep	=	4'b1111;
assign		tx_data		=	(tx_state == 4'd1)	?	((len_cnt == 'd0)	?	{16'h55aa,16'd1}	:	{31'd0,1'b1})	: 
							(tx_state == 4'd2)	?	((len_cnt == 'd0)	?	{16'h55aa,16'd2}	:	{31'd0,1'b1})	: 32'd0;
							
assign		tx_tlast	=	(len_cnt == 'd1) && tx_tready;
		

// ila_aurora_tx	ila_aurora_tx_inst(
	// .clk(USER_CLK),
	// .probe0({CHANNEL_UP,tx_tvalid,tx_tlast,tx_tready,aurora_txen,aurora_tx_emp,tx_state,6'd0}),
	// .probe1(tx_data),
	// .probe2(frame_cnt),
	// .probe3(len_cnt)
// );

endmodule
