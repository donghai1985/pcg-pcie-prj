
module  ddr_fifo_top(

	input				sys_rst,
	input				rst,
	
	input			   	clk_500m,
	input				clk_200m,
	output				ui_clk,
	
	input	[511:0]		ddr_wr_data,
	output				ddr_wr_en,
	input	[9:0]		ddr_wr_data_count,
	input				complete,
	
	output				ddr_rd_en,
	output	[511:0]		ddr_rd_data,	
	input				ddr_rd_full,
	
	output				init_calib_complete,

	inout 	[63:0]      ddr3_dq,
	inout 	[7:0]       ddr3_dqs_n,
	inout 	[7:0]       ddr3_dqs_p,
  // Outputs
    output 	[13:0]     	ddr3_addr,
    output 	[2:0]       ddr3_ba,
    output            	ddr3_ras_n,
    output           	ddr3_cas_n,
    output            	ddr3_we_n,
    output            	ddr3_reset_n,
    output        		ddr3_ck_p,
    output        		ddr3_ck_n,
    output        		ddr3_cke,
    output        		ddr3_cs_n,
    output 	[7:0]   	ddr3_dm,
    output        		ddr3_odt
);


parameter	ADDR_WIDTH	=	28	;
parameter   DATA_WIDTH	=	64	;

	
wire	[ADDR_WIDTH - 1 :0]		app_addr			;
wire  	[2:0]     			 	app_cmd				;
wire            				app_en				;
wire  	[DATA_WIDTH*8-1:0]      app_wdf_data		;
wire            				app_wdf_end			;
wire  	[DATA_WIDTH-1:0]       	app_wdf_mask		;
wire            				app_wdf_wren		;
wire  	[DATA_WIDTH*8-1:0]      app_rd_data			;
wire             				app_rd_data_end		;
wire             				app_rd_data_valid	;
wire             				app_rdy				;
wire             				app_wdf_rdy			;
wire         	   				app_sr_req			;
wire         	   				app_ref_req			;
wire         	   				app_zq_req			;
wire             				app_sr_active		;
wire             				app_ref_ack			;
wire             				app_zq_ack			;
wire             				ui_clk_sync_rst		;

wire							start				;


wire							ddr_log_rst  		;

reg		[2:0]					sys_rst_r = 3'b000;  




always @ (posedge ui_clk) begin
	sys_rst_r <= {sys_rst_r[1:0],sys_rst};
end


assign	ddr_log_rst	=	sys_rst_r[2] | ui_clk_sync_rst;

	
//---------------------------------------------------------------------------
	
	 
	
ddr_ctrl #(
	.DATA_WIDTH	(DATA_WIDTH),
	.ADDR_WIDTH	(ADDR_WIDTH)
) ddr_ctrl_inst(
	.ddr_ui_clk			(ui_clk				),
	.ddr_log_rst		(ddr_log_rst		),
	//------DDR_UP---------
	
	.iv_ddr_local_q 	(ddr_wr_data		),
	.o_ddr_local_rden 	(ddr_wr_en			),
	.i_rd_data_count 	(ddr_wr_data_count	),
	
	.o_ddr_rd_data		(ddr_rd_data		),
	.o_ddr_rd_data_en	(ddr_rd_en			),
	.i_dn_full 			(ddr_rd_full		),

	//---DDR---
	.app_addr			(app_addr			),
	.app_cmd			(app_cmd			),
	.app_en				(app_en				),
	.app_wdf_data		(app_wdf_data		),
	.app_wdf_end		(app_wdf_end		),
	.app_wdf_wren		(app_wdf_wren		),
	.app_rd_data		(app_rd_data		),
	.app_rd_data_valid	(app_rd_data_valid	),
	.app_rdy			(app_rdy			),
	.app_wdf_rdy		(app_wdf_rdy		),
	.init_calib_complete(init_calib_complete),
	.complete			(complete			)
);	
	
	
	
	
	
	
ddr3_mig ddr3_mig_inst(

    // Memory interface ports
    .ddr3_addr          (ddr3_addr			),  	// output [13:0]	ddr3_addr
    .ddr3_ba            (ddr3_ba			),  	// output [2:0]		ddr3_ba
    .ddr3_cas_n         (ddr3_cas_n			),  	// output			ddr3_cas_n
    .ddr3_ck_n          (ddr3_ck_n			),  	// output [0:0]		ddr3_ck_n
    .ddr3_ck_p          (ddr3_ck_p			),  	// output [0:0]		ddr3_ck_p
    .ddr3_cke           (ddr3_cke			),  	// output [0:0]		ddr3_cke
    .ddr3_ras_n         (ddr3_ras_n			),  	// output			ddr3_ras_n
    .ddr3_reset_n       (ddr3_reset_n		),  	// output			ddr3_reset_n
    .ddr3_we_n          (ddr3_we_n			),  	// output			ddr3_we_n
    .ddr3_dq            (ddr3_dq			),  	// inout [63:0]		ddr3_dq
    .ddr3_dqs_n         (ddr3_dqs_n			),  	// inout [7:0]		ddr3_dqs_n
    .ddr3_dqs_p         (ddr3_dqs_p			),  	// inout [7:0]		ddr3_dqs_p
    .init_calib_complete(init_calib_complete),  	// output			init_calib_complete
		
	.ddr3_cs_n          (ddr3_cs_n			),  	// output [0:0]		ddr3_cs_n
    .ddr3_dm            (ddr3_dm			),  	// output [7:0]		ddr3_dm
    .ddr3_odt           (ddr3_odt			),  	// output [0:0]		ddr3_odt
    // Application interface ports	
    .app_addr           (app_addr			),  	// input [27:0]		app_addr
    .app_cmd            (app_cmd			),  	// input [2:0]		app_cmd
    .app_en             (app_en				),  	// input			app_en
    .app_wdf_data       (app_wdf_data		),  	// input [511:0]	app_wdf_data
    .app_wdf_end        (app_wdf_end		),  	// input			app_wdf_end
    .app_wdf_wren       (app_wdf_wren		),  	// input			app_wdf_wren
    .app_rd_data        (app_rd_data		),  	// output [511:0]	app_rd_data
    .app_rd_data_end    (app_rd_data_end	),  	// output			app_rd_data_end
    .app_rd_data_valid  (app_rd_data_valid	),  	// output			app_rd_data_valid
    .app_rdy            (app_rdy			),  	// output			app_rdy
    .app_wdf_rdy        (app_wdf_rdy		),  	// output			app_wdf_rdy
    .app_sr_req         (1'b0				),  	// input			app_sr_req
    .app_ref_req        (1'b0				),  	// input			app_ref_req
    .app_zq_req         (1'b0				),  	// input			app_zq_req
    .app_sr_active      (app_sr_active		),  	// output			app_sr_active
    .app_ref_ack        (app_ref_ack		),  	// output			app_ref_ack
    .app_zq_ack         (app_zq_ack			),  	// output			app_zq_ack
    .ui_clk             (ui_clk				),  	// output			ui_clk
    .ui_clk_sync_rst    (ui_clk_sync_rst	),  	// output			ui_clk_sync_rst
    .app_wdf_mask       (64'd0				),  	// input [63:0]		app_wdf_mask
    // System Clock Ports	
    .sys_clk_i          (clk_500m			),  	// input			sys_clk_p
    // Reference Clock Ports	
    .clk_ref_i          (clk_200m			),  	// input			clk_ref_i
	.device_temp        (					),		// output [11:0]	device_temp
    .sys_rst            (~rst				) 		// input 			sys_rst		Active Low
);


endmodule 