
module ddr_ctrl #(
	parameter	 DATA_WIDTH	=	64 ,
	parameter	 ADDR_WIDTH	=	28
)
(
	input			ddr_ui_clk,
	input			ddr_log_rst,
	//------DDR_UP---------
	
	input	[DATA_WIDTH*8-1:0]	iv_ddr_local_q ,
	output						o_ddr_local_rden ,
	input	[9:0]	i_rd_data_count,
	
	//-------DDR_DN--------------------
	output  [DATA_WIDTH*8-1:0]  o_ddr_rd_data ,
	output	 					o_ddr_rd_data_en,
	input						i_dn_full ,
	
	
	//---DDR---
	output [ADDR_WIDTH-1:0]       app_addr,
	output [2:0]      			 app_cmd,
	output            			 app_en,
	output [DATA_WIDTH*8-1:0]    app_wdf_data,
	output             			app_wdf_end,
	output             			app_wdf_wren,
	input [DATA_WIDTH*8-1:0]    app_rd_data,
	input            			app_rd_data_valid,
	input            			app_rdy,
	input            			app_wdf_rdy,
	input            			init_calib_complete,
	input						complete
	
	
);

	parameter		WR_BURST_NUM	=	128 ;

 
wire					   rd_data_finish;


reg			complete_r1		=	'd0;
reg			complete_r2		=	'd0;
reg			complete_r3		=	'd0;
reg			complete_reg	=	'd0;
wire		up_edge_comlete;
reg	[2:0]	complete_state	=	'd0;
reg [15:0]	delay_cnt		=	'd0;
always @ (posedge ddr_ui_clk)
begin
	if(ddr_log_rst) begin
		complete_r1	<=	1'b0;
		complete_r2	<=	1'b0;
		complete_r3	<=	1'b0;
	end
	else begin
		complete_r1	<=	complete;
		complete_r2 <=	complete_r1;
		complete_r3 <=	complete_r2;
	end
end
assign	up_edge_comlete = complete_r2 && (~complete_r3);
always @ (posedge ddr_ui_clk)
begin
	if(ddr_log_rst) begin
		complete_state	<=	'd0;
	end
	else begin
	case(complete_state)
	3'd0: begin
		if(up_edge_comlete) begin
			complete_state	<=	'd1;
		end
		else begin
			complete_state	<=	'd0;
		end
	end
	3'd1: begin
		if(rd_data_finish) begin
			complete_state	<=	'd2;
		end
		else begin
			complete_state	<=	'd1;
		end
	end
	3'd2: begin
		if(delay_cnt == 'd50) begin
			complete_state	<=	'd0;
		end
		else begin
			complete_state	<=	'd2;
		end
	end
	default: begin
		complete_state	<=	'd0;
	end
	endcase
	end
end
always @ (posedge ddr_ui_clk)
begin
	if(ddr_log_rst) begin
		complete_reg	<=	'd0;
		delay_cnt		<=	'd0;
	end
	else begin
	case(complete_state)
	3'd0: begin
		complete_reg	<=	'd0;
		delay_cnt		<=	'd0;
	end
	3'd1: begin
		complete_reg	<=	'd1;
		delay_cnt		<=	'd0;
	end
	3'd2: begin
		if(delay_cnt == 'd50) begin
			complete_reg	<=	'd0;
			delay_cnt		<=	'd0;
		end
		else begin
			complete_reg	<=	'd1;
			delay_cnt		<=	delay_cnt + 'd1;
		end
	end
	default: begin
		complete_reg	<=	'd0;
		delay_cnt		<=	'd0;
	end
	endcase
	end
end

ddr_fsm #(
	.DATA_WIDTH	(DATA_WIDTH) ,
	.ADDR_WIDTH	(ADDR_WIDTH),
	.WR_BURST_NUM(WR_BURST_NUM)
)
	ddr_fsm(
	.ddr_ui_clk		(ddr_ui_clk),
	.ddr_log_rst	(ddr_log_rst),
	//------DDR_UP---------
	
	.iv_ddr_local_q 		(iv_ddr_local_q),
	.i_rd_data_count 	(i_rd_data_count),
	.o_ddr_local_rden	(o_ddr_local_rden),
	.complete			(complete_reg	),
	.rd_data_finish		(rd_data_finish),
	
	.i_dn_full 				(i_dn_full),	//DDR读出数据到外部fifo的满信号
	.ddr_rd_data 			(o_ddr_rd_data), // DDR读出的数据，512bit
	.ddr_rd_data_en 		(o_ddr_rd_data_en), //DDR读出数据的使能信号
	//---DDR---
	.app_addr			(app_addr),
	.app_cmd			(app_cmd),
	.app_en				(app_en),
	.app_wdf_data		(app_wdf_data),
	.app_wdf_end		(app_wdf_end),
	.app_wdf_wren		(app_wdf_wren),
	.app_rd_data		(app_rd_data),
	.app_rd_data_valid	(app_rd_data_valid),
	.app_rdy			(app_rdy),
	.app_wdf_rdy		(app_wdf_rdy),
	.init_calib_complete(init_calib_complete)
	
);





endmodule 