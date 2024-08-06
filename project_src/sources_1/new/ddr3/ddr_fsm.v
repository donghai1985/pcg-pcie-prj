
module ddr_fsm #(
	parameter	 DATA_WIDTH	=	64 ,
	parameter	 ADDR_WIDTH	=	28 ,
	parameter	WR_BURST_NUM = 128
)
(
	input			ddr_ui_clk,
	input			ddr_log_rst,
	//------DDR_UP---------
	
	input	[DATA_WIDTH*8-1:0]	iv_ddr_local_q , //�ⲿfifo���ݵ�DDRд
	input	[9:0]				i_rd_data_count , //�ⲿfifo���ݵ�������
	output						o_ddr_local_rden, //�ⲿfifo���ݵĶ�ȡʹ��
	
	input					    	i_dn_full ,	//DDR�������ݵ��ⲿfifo�����ź�
	output	reg [DATA_WIDTH*8-1:0]	ddr_rd_data , // DDR���������ݣ�512bit
	output	reg						ddr_rd_data_en , //DDR�������ݵ�ʹ���ź�
	
	input						complete ,
	output	reg					rd_data_finish,					
	//---DDR---
	output [ADDR_WIDTH-1:0]      app_addr,
	output [2:0]      			 app_cmd,
	output            			 app_en,
	output [DATA_WIDTH*8-1:0]    app_wdf_data,
	output             			app_wdf_end,
	output             			app_wdf_wren,
	input [DATA_WIDTH*8-1:0]    app_rd_data,
	input            			app_rd_data_valid,
	input            			app_rdy,
	input            			app_wdf_rdy,
	input            			init_calib_complete
	
);

	parameter				S_IDLE		=	3'd0;
	parameter				S_INIT		=	3'd1;
	parameter				S_WRITE		=	3'd2;
	// parameter				S_WR_DONE	=	3'd4;
	parameter				S_READ		=	3'd5;
	// parameter				S_READ_DONE	=	3'd6;
	

	reg						init_calib_r 	=	'd0;
	reg						wr_ready 		= 'd0;
	reg						rd_ready 		= 'd0;
	reg						complete_r1		=	'd0;
	reg						complete_r2		=	'd0;
	reg						complete_r3		=	'd0;
	reg						ddr_store_full	=	'd0;
	reg [ADDR_WIDTH-2-3:0]	ddr_store_num	=	'd0; //2^(27-3)== 2^24
	reg	[ADDR_WIDTH-2:0]	app_wr_addr	=	'd0;
	reg	[ADDR_WIDTH-2:0]	app_rd_addr	=	'd0;
	
    reg     [31:0]              rd_cmd_cnt;
    reg                         rd_cmd_finish;

    reg     [31:0]              wr_data_cnt;
    reg                         wr_data_finish;
    reg     [31:0]              wr_data_length;
    reg     [31:0]              rd_data_cnt;
    // reg                         rd_data_finish;
    reg     [31:0]              rd_data_length;
	
	
	reg	[2:0] cs_state	=	'd0;
	
	always @ (posedge ddr_ui_clk) begin
		init_calib_r	<=	init_calib_complete ;
		complete_r1	<=	complete;
		complete_r2 <=	complete_r1;
		complete_r3 <=	complete_r2;
	end
	
	//-=---wr_ready------------------------------------
	always @ (posedge ddr_ui_clk or posedge ddr_log_rst) begin
		if(ddr_log_rst) 
			wr_ready	<=	'd0;
		else if(complete_r3) begin
			if(~ddr_store_full && (i_rd_data_count != 0)) //说明512位宽的fifo里还有剩余的数据量需要读出
				wr_ready	<=	1;
			else
				wr_ready	<=	0;
		end
		else if(~ddr_store_full && (i_rd_data_count >=	WR_BURST_NUM)) //没有到complete时刻 ,且fifo计数到了突发长度的大小
			wr_ready	<=	1;
		else
			wr_ready	<=	0;
			
	end
	
	//-=---rd_ready------------------------------------
	always @ (posedge ddr_ui_clk or posedge ddr_log_rst) begin
		if(ddr_log_rst) 
			rd_ready	<=	'd0;
		else if(complete_r3) begin
			if(~i_dn_full && (ddr_store_num != 0)) //说明DDR有剩余的数据
				rd_ready	<=	1;
			else
				rd_ready	<=	0;
		end
		else if(~i_dn_full && (ddr_store_num >=	WR_BURST_NUM)) //没有到complete时刻 ,且DDR已经存储到了一个突发的数据大小量
			rd_ready	<=	1;
		else
			rd_ready	<=	0;
			
	end
	
	
	
	
    // wr_data_length
    always @ (posedge ddr_ui_clk or posedge ddr_log_rst) begin
		if(ddr_log_rst)
            wr_data_length <= 32'h0;
        else if ( ~complete_r3 && complete_r2 )
            wr_data_length <= i_rd_data_count + 2; // fwft fifo
        else if ( complete_r3 )
            wr_data_length <= wr_data_length;
        else
            wr_data_length <= WR_BURST_NUM;
    end
	
	
	
    // rd_data_length
    always @ (posedge ddr_ui_clk or posedge ddr_log_rst) begin
		if(ddr_log_rst)
            rd_data_length <= 32'h0;
        else if ( complete_r3 && wr_data_finish ) 
             rd_data_length <= ddr_store_num;
        else if ( complete_r3 )
        	rd_data_length <= rd_data_length;
        else
            rd_data_length <= WR_BURST_NUM;
    end
	







	
	
	
	
	//ddr_store_num
	always @ (posedge ddr_ui_clk or posedge ddr_log_rst) begin
		if(ddr_log_rst)
			ddr_store_num	<=	'd0;
		else if((cs_state == S_WRITE) && app_wdf_wren) 
			ddr_store_num	<=	ddr_store_num + 1'b1;
		else if((cs_state == S_READ) && app_en )
			ddr_store_num	<=	ddr_store_num - 1'b1;
		else
			ddr_store_num	<=	ddr_store_num;
	end
	
	//ddr_store_full
	always @ (posedge ddr_ui_clk or posedge ddr_log_rst) begin
		if(ddr_log_rst)
			ddr_store_full	<=	'd0;
		else if(&ddr_store_num)
			ddr_store_full <= 1'b1;
		else 
			ddr_store_full	<=	1'b0;
	end
	
	
	
	//״̬��ת
	always @(posedge ddr_ui_clk or posedge ddr_log_rst) begin
		if(ddr_log_rst)
			cs_state <= S_IDLE;
		else
		case(cs_state)
			S_IDLE : begin
				if(init_calib_r)	//����DDR��ʼ����һ��
					cs_state <=	S_INIT ;
				else
					cs_state <= S_IDLE;
			end
			S_INIT : begin
				if(wr_ready)			//��д����ͽ���д
					cs_state <= S_WRITE;	
				else if(rd_ready)		//�ж�����ͽ��ж�
					cs_state <= S_READ;
				else 
					cs_state <= S_INIT;
			end
			S_WRITE : begin
				if ( wr_data_finish )	// ����Ѿ�ͻ����д�����ˣ���ת����ʼ̬�����ж�д�ж�
                    cs_state <= S_INIT;
                else
                    cs_state <= S_WRITE;
			end
			S_READ : begin
				if(rd_data_finish)
					cs_state	<=	S_INIT;
				else
					cs_state	<=	S_READ;
			end
			
		default: cs_state <= S_IDLE;
		endcase
	end
	
always @(posedge ddr_ui_clk or posedge ddr_log_rst) 
begin
	if(ddr_log_rst) begin
		wr_data_cnt		<=	'd0;
		wr_data_finish	<=	'd0;
		app_wr_addr		<=	'd0;
	end
	else begin
		case(cs_state)
			S_IDLE : begin
				wr_data_cnt		<=	'd0;
				wr_data_finish	<=	'd0;
				app_wr_addr		<=	'd0;
			end
			S_WRITE : begin
				if(app_wdf_wren) begin
					if(wr_data_cnt == wr_data_length - 'd1) begin
						wr_data_cnt		<=	'd0;
						wr_data_finish	<=	1'b1;
						app_wr_addr	<=	app_wr_addr  + 'd8;
					end
					else begin
						wr_data_cnt		<=	wr_data_cnt + 'd1;
						wr_data_finish	<=	1'b0;
						app_wr_addr		<=	app_wr_addr  + 'd8;
					end
				end
				else begin
					wr_data_cnt		<=	wr_data_cnt;
					wr_data_finish	<=	1'b0;
					app_wr_addr		<=	app_wr_addr;
				end
			end
			default: begin
				wr_data_cnt		<=	'd0;
				wr_data_finish	<=	'd0;
				app_wr_addr		<=	app_wr_addr;
			end
		endcase
	end
end
always @(posedge ddr_ui_clk or posedge ddr_log_rst) 
begin
	if(ddr_log_rst) begin
		rd_cmd_cnt		<=	'd0;
		rd_cmd_finish	<=	'd0;
		rd_data_cnt		<=	'd0;
		rd_data_finish	<=	'd0;
		app_rd_addr		<=	'd0;
	end
	else begin
		case(cs_state)
			S_IDLE : begin
				rd_cmd_cnt		<=	'd0;
				rd_cmd_finish	<=	'd0;
				rd_data_cnt		<=	'd0;
				rd_data_finish	<=	'd0;
				app_rd_addr		<=	'd0;
			end
			S_READ : begin
				if(app_en) begin
					if(rd_cmd_cnt == rd_data_length - 'd1) begin
						rd_cmd_cnt		<=	'd0;
						rd_cmd_finish	<=	1'b1;
						app_rd_addr		<=	app_rd_addr  + 'd8;
					end
					else begin
						rd_cmd_cnt		<=	rd_cmd_cnt + 'd1;
						rd_cmd_finish	<=	1'b0;
						app_rd_addr		<=	app_rd_addr  + 'd8;
					end
				end
				else begin
					rd_cmd_cnt		<=	rd_cmd_cnt;
					rd_cmd_finish	<=	rd_cmd_finish;
					app_rd_addr		<=	app_rd_addr;
				end
				if(app_rd_data_valid) begin
					if(rd_data_cnt == rd_data_length - 'd1) begin
						rd_data_cnt		<=	'd0;
						rd_data_finish	<=	'd1;
					end
					else begin
						rd_data_cnt		<=	rd_data_cnt + 'd1;
						rd_data_finish	<=	'd0;
					end
				end
				else begin
					rd_data_cnt		<=	rd_data_cnt;
					rd_data_finish	<=	'd0;
				end
			end
			default: begin
				rd_cmd_cnt		<=	'd0;
				rd_cmd_finish	<=	'd0;
				rd_data_cnt		<=	'd0;
				rd_data_finish	<=	'd0;
				app_rd_addr		<=	app_rd_addr;
			end
		endcase
	end
end
	
	assign	app_addr = (cs_state == S_WRITE) ? {1'b0,app_wr_addr} : {1'b0,app_rd_addr};
	assign	app_en = ((cs_state == S_WRITE) && (~wr_data_finish) && app_rdy && app_wdf_rdy) || ((cs_state == S_READ) && ~rd_cmd_finish && app_rdy) ;
	assign  app_cmd = (cs_state == S_WRITE) ? 3'b000 : 3'b001;
	assign  app_wdf_wren = (cs_state == S_WRITE) ? app_en : 1'b0;
	assign  app_wdf_end = app_wdf_wren ;
	assign  app_wdf_data = iv_ddr_local_q ;
	assign  o_ddr_local_rden = app_wdf_wren;
	
	
	
	always @ (posedge ddr_ui_clk ) begin	
		ddr_rd_data		<=	app_rd_data ; //{app_rd_data[127:0],app_rd_data[255:128],app_rd_data[383:256],app_rd_data[511:384]};
		ddr_rd_data_en	<=	app_rd_data_valid;
	end
	
	
	
	
endmodule 