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

module sim_pmt_aurora_tx
(
    // User Interface
    output				aurora_txen,
	input	[31:0]		aurora_txdata,
	input	[10:0]		aurora_rd_data_count,
	
	input				adc_start,
	input				adc_end,

    // System Interface
    input				USER_CLK,
    input				RESET,
    input				CHANNEL_UP,
	
	output	reg			tx_tvalid,
	output	reg [31:0]	tx_data,
	output	wire [3:0]	tx_tkeep,
	output	reg			tx_tlast,
	input				tx_tready
);


//***************************Internal Register/Wire Declarations***************************

wire               	reset_c;

wire       			dly_data_xfer;
reg 	[4:0]  		channel_up_cnt;

reg 	[3:0]		tx_state;
reg 	[15:0]		len_cnt;
reg		[31:0]		frame_cnt;

reg					adc_start_reg1;
reg					adc_start_reg2;
reg					adc_start_reg3;
reg					adc_end_reg1;
reg					adc_end_reg2;
reg					adc_end_reg3;
wire				up_edge_adc_start;

reg		[15:0]		tx_delay_cnt;

reg					adc_end_flag;


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
		adc_start_reg1	<=	1'b0;
		adc_start_reg2	<=	1'b0;
		adc_start_reg3	<=	1'b0;
		adc_end_reg1	<=	1'b0;
		adc_end_reg2	<=	1'b0;
		adc_end_reg3	<=	1'b0;
	end
	else begin
		adc_start_reg1	<=	adc_start;
		adc_start_reg2	<=	adc_start_reg1;
		adc_start_reg3	<=	adc_start_reg2;
		adc_end_reg1	<=	adc_end;
		adc_end_reg2	<=	adc_end_reg1;
		adc_end_reg3	<=	adc_end_reg2;
	end
end

assign	up_edge_adc_start = adc_start_reg1 && (~adc_start_reg2);

//帧长为帧头32bit + 1000*32bit
//帧头格式为16'h55aa + 16bit指令码
    //______________________________ Transmit Data  __________________________________   

// reg			pulse_10us_flag;
// reg			pulse_10us;
// reg	[15:0]	pulse_10us_cnt;
	
// always @(posedge USER_CLK)
// begin
// 	if(reset_c) begin
// 		pulse_10us_flag		<=	1'b0;
// 	end
// 	else if(up_edge_adc_start) begin
// 		pulse_10us_flag		<=	1'b0;
// 	end
// 	else if(adc_start_reg3) begin
// 		pulse_10us_flag		<=	1'b1;
// 	end
// 	else if(adc_end_reg3) begin
// 		pulse_10us_flag		<=	1'b0;
// 	end
// 	else begin
// 		pulse_10us_flag		<=	pulse_10us_flag;
// 	end
// end

// always @(posedge USER_CLK)
// begin
// 	if(reset_c) begin
// 		pulse_10us		<=	1'b0;
// 		pulse_10us_cnt	<=	'd0;
// 	end
// 	else if(pulse_10us_flag) begin
// 		if(pulse_10us_cnt == 'd1249) begin
// 			pulse_10us		<=	1'b1;
// 			pulse_10us_cnt	<=	'd0;
// 		end
// 		else begin
// 			pulse_10us		<=	1'b0;
// 			pulse_10us_cnt	<=	pulse_10us_cnt + 1'd1;
// 		end
// 	end
// 	else begin
// 		pulse_10us		<=	1'b0;
// 		pulse_10us_cnt	<=	'd0;
// 	end
// end
	
always @(posedge USER_CLK)
begin
	if(reset_c) begin
		tx_state	<=	'd0;
	end
	else if(up_edge_adc_start) begin
		tx_state	<=	'd0;
	end
	else begin
		case(tx_state)
		4'd0: begin
			if(adc_start_reg3) begin
				tx_state	<=	tx_state + 1'd1;
			end
			else begin
				tx_state	<=	'd0;
			end
		end
		4'd1: begin
			if(tx_tlast) begin
				tx_state	<=	tx_state + 1'd1;
			end
			else begin
				tx_state	<=	tx_state;
			end
		end
		4'd2: begin
			if(tx_delay_cnt == 'd200) begin		//加延迟目的是给pcie光纤卡清buffer预留时间
				tx_state	<=	tx_state + 1'd1;
			end
			else begin
				tx_state	<=	tx_state;
			end
		end
		4'd3: begin
			if(~adc_start_reg3) begin
				tx_state	<=	'd6;
			end
			else if((aurora_rd_data_count >= 'd1000)) begin
				tx_state	<=	tx_state + 1'd1;
			end
			else begin
				tx_state	<=	tx_state;
			end
		end
		4'd4: begin
			if(tx_tlast) begin
				tx_state	<=	tx_state + 1'd1;
			end
			else begin
				tx_state	<=	tx_state;
			end
		end
		4'd5: begin
			if(~adc_start_reg3) begin
				tx_state	<=	tx_state + 1'd1;
			end
			else begin
				tx_state	<=	'd3;
			end
		end
		4'd6: begin
			if(tx_tlast) begin
				tx_state	<=	tx_state + 1'd1;
			end
			else begin
				tx_state	<=	tx_state;
			end
		end	
		
		4'd7: begin
			if(adc_end_reg3) begin
				tx_state	<=	'd9;
			end
			else if((aurora_rd_data_count >= 'd1000)) begin
				tx_state	<=	tx_state + 1'd1;
			end
			else begin
				tx_state	<=	tx_state;
			end
		end
		4'd8: begin
			if(tx_tlast) begin
				tx_state	<=	tx_state + 1'd1;
			end
			else begin
				tx_state	<=	tx_state;
			end
		end
		4'd9: begin
			if(adc_end_flag) begin
				tx_state	<=	tx_state + 1'd1;
			end
			else begin
				tx_state	<=	4'd7;
			end
		end
		4'd10: begin
			if(~adc_end_reg3) begin
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
		frame_cnt	<=	'd0;
		tx_delay_cnt<=	'd0;
		adc_end_flag<=	1'b0;
	end
	else if(up_edge_adc_start) begin
		len_cnt		<=	'd0;
		frame_cnt	<=	'd0;
		tx_delay_cnt<=	'd0;
		adc_end_flag<=	1'b0;
	end
	else begin
		case(tx_state)
		4'd0: begin
			len_cnt		<=	'd0;
			frame_cnt	<=	'd0;
			tx_delay_cnt<=	'd0;
			adc_end_flag<=	1'b0;
		end
		4'd1: begin
			frame_cnt	<=	'd0;
			tx_delay_cnt<=	'd0;
			adc_end_flag<=	1'b0;
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
			len_cnt		<=	'd0;
			frame_cnt	<=	'd0;
			adc_end_flag<=	1'b0;
			if(tx_delay_cnt == 'd200) begin
				tx_delay_cnt	<=	'd0;
			end
			else begin
				tx_delay_cnt	<=	tx_delay_cnt + 1'd1;
			end
		end
		4'd3: begin
			len_cnt			<=	'd0;
			tx_delay_cnt	<=	'd0;
			frame_cnt		<=	frame_cnt;
			adc_end_flag	<=	1'b0;
		end
		4'd4: begin
			tx_delay_cnt	<=	'd0;
			frame_cnt		<=	frame_cnt;
			adc_end_flag	<=	1'b0;
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
		4'd5: begin
			tx_delay_cnt	<=	'd0;
			len_cnt			<=	'd0;
			adc_end_flag	<=	1'b0;
			frame_cnt		<=	frame_cnt + 1'd1;
		end
		4'd6: begin
			frame_cnt	<=	frame_cnt;
			tx_delay_cnt<=	'd0;
			adc_end_flag<=	1'b0;
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
		
		4'd7: begin
			len_cnt			<=	'd0;
			tx_delay_cnt	<=	'd0;
			frame_cnt		<=	frame_cnt;
			if(adc_end_reg3) begin
				adc_end_flag	<=	1'b1;
			end
			else begin
				adc_end_flag	<=	1'b0;
			end
		end
		4'd8: begin
			tx_delay_cnt	<=	'd0;
			frame_cnt		<=	frame_cnt;
			if(tx_tlast) begin
				len_cnt		<=	'd0;
			end
			else if(tx_tvalid) begin
				len_cnt		<=	len_cnt + 1'd1;
			end
			else begin
				len_cnt		<=	len_cnt;
			end
			
			if(adc_end_reg3) begin
				adc_end_flag	<=	1'b1;
			end
			else begin
				adc_end_flag	<=	adc_end_flag;
			end
		end
		4'd9: begin
			tx_delay_cnt	<=	'd0;
			len_cnt			<=	'd0;
			adc_end_flag	<=	1'b0;
			if(adc_end_flag) begin
				frame_cnt	<=	'd0;
			end
			else begin
				frame_cnt	<=	frame_cnt + 1'd1;
			end
		end
		4'd10: begin
			len_cnt			<=	'd0;
			frame_cnt		<=	'd0;
			tx_delay_cnt	<=	'd0;
			adc_end_flag	<=	1'b0;
		end
		default: begin
			len_cnt			<=	'd0;
			frame_cnt		<=	'd0;
			tx_delay_cnt	<=	'd0;
			adc_end_flag	<=	1'b0;
		end
		endcase
	end
end            

always @(*)
begin
	if(tx_state == 4'd1)
		tx_tvalid	=	tx_tready;
	else if(tx_state == 4'd4)
		tx_tvalid	=	tx_tready;
	else if(tx_state == 4'd6)
		tx_tvalid	=	tx_tready;
	else if(tx_state == 4'd8)
		tx_tvalid	=	tx_tready;
	else
		tx_tvalid	=	1'b0;
end

always @(*)
begin
	if((tx_state == 4'd1)) begin
		if(len_cnt == 'd0) begin
			tx_data		=	32'h55aa_0001;
		end
		else if(len_cnt == 'd1) begin
			tx_data		=	32'h0000_0001;
		end
		else begin
			tx_data		=	32'h0;
		end
	end
	else if((tx_state == 4'd4)) begin
		if(len_cnt == 'd0) begin
			tx_data		=	32'h55aa_0002;
		end
		// else if(len_cnt == 'd1) begin
			// tx_data		=	frame_cnt;
		// end
		else begin
			tx_data		=	aurora_txdata;
		end
	end
	else if((tx_state == 4'd6)) begin
		if(len_cnt == 'd0) begin
			tx_data		=	32'h55aa_0001;
		end
		else if(len_cnt == 'd1) begin
			tx_data		=	32'h0000_0000;
		end
		else begin
			tx_data		=	32'h0;
		end
	end
	else if((tx_state == 4'd8)) begin
		if(len_cnt == 'd0) begin
			tx_data		=	32'h55aa_0002;
		end
		// else if(len_cnt == 'd1) begin
			// tx_data		=	frame_cnt;
		// end
		else begin
			tx_data		=	aurora_txdata;
		end
	end
	else begin
		tx_data		=	32'd0;
	end
end

always @(*)
begin
	if((tx_state == 4'd1) && (len_cnt == 'd1))
		tx_tlast	=	tx_tready;
	else if((tx_state == 4'd4) && (len_cnt == 'd1000))
		tx_tlast	=	tx_tready;
	else if((tx_state == 4'd6) && (len_cnt == 'd1))
		tx_tlast	=	tx_tready;
	else if((tx_state == 4'd8) && (len_cnt == 'd1000))
		tx_tlast	=	tx_tready;
	else
		tx_tlast	=	1'b0;
end   

assign		aurora_txen	=	((tx_state == 4'd4) && (len_cnt >= 'd1))	?	tx_tvalid : 
							((tx_state == 4'd8) && (len_cnt >= 'd1))	?	tx_tvalid : 1'b0;
assign		tx_tkeep	=	4'b1111;

// ila_aurora_tx	ila_aurora_tx_inst(
	// .clk(USER_CLK),
	// .probe0({CHANNEL_UP,tx_tvalid,tx_tlast,tx_tready,aurora_txen,tx_state,7'd0}),
	// .probe1(tx_data),
	// .probe2(frame_cnt),
	// .probe3(len_cnt)
// );

endmodule
