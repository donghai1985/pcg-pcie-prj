`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2022/08/22 10:32:24
// Design Name: 
// Module Name: aurora_rx_data_process
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


module aurora_rx_data_process(
    input                   aurora_log_clk_0        ,
    input                   aurora_rst_0            ,
    input                   pmt_aurora_rxen_i       ,
    input       [31:0]      pmt_aurora_rxdata_i     ,
    input                   eds_rx_start_i          ,
    input                   fbc_rx_start_i          ,
    input                   pmt_rx_start_i          ,

    input                   aurora_log_clk_1        ,
    input                   aurora_rst_1            ,
    input                   eds_aurora_rxen_i       ,
    input       [63:0]      eds_aurora_rxdata_i     ,
    input                   pmt_encode_en_i         ,
    input       [63:0]      pmt_encode_data_i       ,

    output      [31:0]      pmt_overflow_cnt_o      ,
    output      [31:0]      encode_overflow_cnt_o   ,
    output      [32-1:0]    Xencode_skip_cnt_o      ,
    output      [32-1:0]    eds_xdma_pack_cnt_o     ,
    output      [32-1:0]    pmt_xdma_pack_cnt_o     ,
    output      [32-1:0]    fbc_xdma_pack_cnt_o     ,

    output                  xdma_vin_mem_clear_o    ,
    output                  xdma_vin_start_o        ,
    (*mark_debug = "true"*)    output  reg             aurora_rxen             ,
    (*mark_debug = "true"*)    output  reg [63:0]      aurora_rxdata
);

(*mark_debug = "true"*)reg [3:0] 	state = 4'd0;

reg  [7:0]  clear_delay_cnt         = 'd0;

reg			pmt_rx_start_reg1;
reg			pmt_rx_start_reg2;
reg			pcie_pmt_rx_end_reg1;
reg			pcie_pmt_rx_end_reg2;
reg			eds_rx_start_reg1;
reg			eds_rx_start_reg2;
reg			pcie_eds_rx_end_reg1;
reg			pcie_eds_rx_end_reg2;
wire        pmt_rx_start_pose;
wire        eds_rx_start_pose;

reg         fbc_rx_start_d0     ;
reg         fbc_rx_start_d1     ;
reg         pcie_fbc_rx_end_d0  ;
reg         pcie_fbc_rx_end_d1  ;
wire        fbc_rx_start_pose   ;

reg			eds_aurora_fifo_rd_en = 1'b0;
reg			eds_aurora_fifo_rd_vld = 1'b0;
wire [63:0]	eds_aurora_fifo_dout;
wire        eds_aurora_fifo_almost_empty;
wire		eds_aurora_fifo_empty;

reg         x_w_encoder_fifo_rd_en = 1'b0;
wire [63:0] x_w_encoder_fifo_dout;
wire        x_w_encoder_fifo_full;
wire        x_w_encoder_fifo_empty;
wire        x_w_encoder_fifo_almost_empty;
wire        encoder_fifo_sbiterr;
wire        encoder_fifo_dbiterr;

reg		    pmt_data_fifo_rd_en = 1'b0;
reg         pmt_data_fifo_rd_en_d = 'd0;
reg         pmt_data_fifo_rd_vld = 'd0;
wire [31:0] pmt_data_fifo_dout;
wire        pmt_data_fifo_full;
wire        pmt_data_fifo_empty;
wire        pmt_data_fifo_almost_empty;
wire        pmt_fifo_sbiterr;
wire        pmt_fifo_dbiterr;

reg         xdma_vin_start  = 'd0;

reg  [63-1:0] pmt_test_cnt = 'd0;

always @(posedge aurora_log_clk_0)begin
    pmt_rx_start_reg1   <=  pmt_rx_start_i;
    pmt_rx_start_reg2   <=  pmt_rx_start_reg1;
    eds_rx_start_reg1   <=  eds_rx_start_i;
    eds_rx_start_reg2   <=  eds_rx_start_reg1;
    fbc_rx_start_d0     <=  fbc_rx_start_i;
    fbc_rx_start_d1     <=  fbc_rx_start_d0;
end

assign  pmt_rx_start_pose = pmt_rx_start_reg1 && (~pmt_rx_start_reg2);
assign  eds_rx_start_pose = eds_rx_start_reg1 && (~eds_rx_start_reg2);
assign  fbc_rx_start_pose = fbc_rx_start_d0   && (~fbc_rx_start_d1);

assign  aurora_rst      =   aurora_rst_1 || aurora_rst_0 || xdma_vin_mem_clear_o;
// wire    eds_fifo_reset  =   eds_rx_start_i || fbc_rx_start_i;
eds_aurora_sync_fifo eds_aurora_sync_fifo_inst(
    .rst                    ( aurora_rst                    ),  // input wire rst
    .wr_clk                 ( aurora_log_clk_1              ),  // input wire wr_clk
    .rd_clk                 ( aurora_log_clk_0              ),  // input wire rd_clk
    .din                    ( eds_aurora_rxdata_i           ),  // input wire [63 : 0] din
    .wr_en                  ( eds_aurora_rxen_i             ),  // input wire wr_en
    .rd_en                  ( eds_aurora_fifo_rd_en         ),  // input wire rd_en
    .dout                   ( eds_aurora_fifo_dout          ),  // output wire [63 : 0] dout
    .full                   (                               ),  // output wire full
    .almost_empty           ( eds_aurora_fifo_almost_empty  ),  // output wire almost_empty
    .empty                  ( eds_aurora_fifo_empty         )   // output wire empty
);

x_w_encoder_fifo x_w_encoder_fifo_inst (
    .rst                    ( aurora_rst                    ),  // input wire rst
    .wr_clk                 ( aurora_log_clk_1              ),  // input wire wr_clk
    .rd_clk                 ( aurora_log_clk_0              ),  // input wire rd_clk
    .din                    ( pmt_encode_data_i             ),  // input wire [63 : 0] din
    .wr_en                  ( pmt_encode_en_i               ),  // input wire wr_en
    .rd_en                  ( x_w_encoder_fifo_rd_en        ),  // input wire rd_en
    .dout                   ( x_w_encoder_fifo_dout         ),  // output wire [63 : 0] dout
    .full                   ( x_w_encoder_fifo_full         ),  // output wire full
    .empty                  ( x_w_encoder_fifo_empty        ),  // output wire empty
    .almost_empty           ( x_w_encoder_fifo_almost_empty ),  // output wire almost_empty
    .sbiterr                ( encoder_fifo_sbiterr          ),  // output wire sbiterr
    .dbiterr                ( encoder_fifo_dbiterr          )   // output wire dbiterr
);

pmt_data_fifo pmt_data_fifo_inst (
    .clk                    ( aurora_log_clk_0              ),  // input wire clk
    .rst                    ( aurora_rst                    ),  // input wire rst
    .din                    ( pmt_aurora_rxdata_i           ),  // input wire [31 : 0] din
    .wr_en                  ( pmt_aurora_rxen_i && pmt_rx_start_reg2   ),  // input wire wr_en
    .rd_en                  ( pmt_data_fifo_rd_en           ),  // input wire rd_en
    .dout                   ( pmt_data_fifo_dout            ),  // output wire [31 : 0] dout
    .full                   ( pmt_data_fifo_full            ),  // output wire full
    .empty                  ( pmt_data_fifo_empty           ),  // output wire empty
    .almost_empty           ( pmt_data_fifo_almost_empty    ),  // output wire almost_empty
    .sbiterr                ( pmt_fifo_sbiterr              ),  // output wire sbiterr
    .dbiterr                ( pmt_fifo_dbiterr              )   // output wire dbiterr
);

always @(posedge aurora_log_clk_0)
begin
    if(pmt_rx_start_pose || eds_rx_start_pose || fbc_rx_start_pose) begin
        state           <=	4'd0;
    end
    else begin
		case(state)
		4'd0: begin
			if(eds_rx_start_reg2) begin
				state  			<=	4'd1;
			end
            else if(fbc_rx_start_d1) begin
                state           <=	4'd2;
            end
			else if(pmt_rx_start_reg2) begin
				state  			<=	4'd4;
			end
			else begin
				state  			<=	4'd0;
			end
		end
		4'd1: begin
			if((~eds_rx_start_reg2) && eds_aurora_fifo_almost_empty) begin
				state  			<=	4'd8;
			end
			else begin
				state  			<=	state;
			end
		end
        
        4'd2: begin
            if((~fbc_rx_start_d1) && eds_aurora_fifo_almost_empty) begin
                state           <=  4'd8;
            end
            else begin
                state           <=  state;
            end
        end
		
		4'd4: begin
			if((~pmt_rx_start_reg2) && (x_w_encoder_fifo_almost_empty || pmt_data_fifo_almost_empty)) begin
				state  			<=	4'd8;
			end
			else begin
				state  			<=	state;
			end
		end
        
        4'd8: begin
            if(clear_delay_cnt[7])
                state           <=  4'd0;
        end

        default: begin
            state           <=  4'd0;
        end
        endcase
    end
end

always @(posedge aurora_log_clk_0)
begin
    case(state)
        4'd0: begin
            eds_aurora_fifo_rd_en   <= 'b0;
            x_w_encoder_fifo_rd_en  <= 'b0;
            pmt_data_fifo_rd_en     <= 'b0;
            eds_aurora_fifo_rd_vld  <= 'd0;
            pmt_data_fifo_rd_en_d   <= 'd0;
            pmt_data_fifo_rd_vld    <= 'd0;
            aurora_rxen             <= 'b0;
            aurora_rxdata           <= 'd0;
            xdma_vin_start          <= 'd0;
        end
        4'd1: begin
            xdma_vin_start          <= 'd1;
            eds_aurora_fifo_rd_vld  <= eds_aurora_fifo_rd_en;  // read latency 

            aurora_rxen             <= eds_aurora_fifo_rd_vld;
            aurora_rxdata           <= eds_aurora_fifo_dout;

            if(pcie_eds_rx_end_reg2) begin
                eds_aurora_fifo_rd_en <= 'b0;
            end
            else if(~eds_aurora_fifo_almost_empty) begin
                eds_aurora_fifo_rd_en <= 'b1;
            end
            else begin
                eds_aurora_fifo_rd_en <= 'b0;
            end
        end

        4'd2: begin
            xdma_vin_start          <= 'd1;
            eds_aurora_fifo_rd_vld  <= eds_aurora_fifo_rd_en;  // read latency 

            aurora_rxen             <= eds_aurora_fifo_rd_vld;
            aurora_rxdata           <= eds_aurora_fifo_dout;

            if(pcie_fbc_rx_end_d1) begin
                eds_aurora_fifo_rd_en   <=  'b0;
            end
            else if(~eds_aurora_fifo_almost_empty) begin
                eds_aurora_fifo_rd_en   <=  'b1;
            end
            else begin
                eds_aurora_fifo_rd_en   <=  'b0;
            end
        end

        4'd4: begin
            xdma_vin_start          <= 'd1;
            pmt_data_fifo_rd_en_d   <= pmt_data_fifo_rd_en && x_w_encoder_fifo_rd_en;
            pmt_data_fifo_rd_vld    <= pmt_data_fifo_rd_en_d;
            
            aurora_rxen             <= pmt_data_fifo_rd_vld;
            aurora_rxdata           <= { x_w_encoder_fifo_dout[59]      // clpc flag, from timing board
                                        // ,x_w_encoder_fifo_dout[58]      // ACC flag, from timing board
                                        ,pmt_data_fifo_dout[31]         // ACC flag, from pmt board
                                        ,x_w_encoder_fifo_dout[57:50]   // AFS and AutoCal flag, from timing board
                                        ,x_w_encoder_fifo_dout[49:32]   // Wencode, from timing board
                                        ,x_w_encoder_fifo_dout[17:0]    // Xencode, from timing board
                                        ,2'b0                           // algo
                                        ,pmt_data_fifo_dout[15:0]};     // pmt data, from pmt board
                                        // {1'b1,pmt_test_cnt[62:0]}; 

            // aurora_rxdata           <= {1'b0,1'b0,8'd0,x_w_encoder_fifo_dout[49:32],x_w_encoder_fifo_dout[17:0],2'b0,pmt_data_fifo_dout[15:0]}; // {1'b1,pmt_test_cnt[62:0]}; 

            if(pcie_pmt_rx_end_reg2) begin
                x_w_encoder_fifo_rd_en  <= 1'b0;
                pmt_data_fifo_rd_en     <= 1'b0;
            end
            else if((~x_w_encoder_fifo_almost_empty) && (~pmt_data_fifo_almost_empty)) begin
                x_w_encoder_fifo_rd_en  <= 1'b1;
                pmt_data_fifo_rd_en     <= 1'b1;
            end
            else begin
                x_w_encoder_fifo_rd_en  <= 1'b0;
                pmt_data_fifo_rd_en     <= 1'b0;
            end
        end
        default: begin
            eds_aurora_fifo_rd_en   <= 'b0;
            x_w_encoder_fifo_rd_en  <= 'b0;
            pmt_data_fifo_rd_en     <= 'b0;
            eds_aurora_fifo_rd_vld  <= 'd0;
            pmt_data_fifo_rd_en_d   <= 'd0;
            pmt_data_fifo_rd_vld    <= 'd0;
            xdma_vin_start          <= 'd1;
            aurora_rxen             <= 'b0;
            aurora_rxdata           <= 'd0;
        end
    endcase
end

always @(posedge aurora_log_clk_0) begin
    if(state==4'd8)
        clear_delay_cnt <= clear_delay_cnt + 1;
    else 
        clear_delay_cnt <= 'd0;
end

assign xdma_vin_start_o     = xdma_vin_start;
assign xdma_vin_mem_clear_o = (state=='d8);
// check code
reg [32-1:0] pmt_overflow_cnt = 'd0;
always @(posedge aurora_log_clk_0) begin
    if((~pmt_rx_start_reg2) && pmt_rx_start_reg1)
        pmt_overflow_cnt <= 'd0;
    else if(pmt_aurora_rxen_i && pmt_rx_start_reg2 && pmt_data_fifo_full)
        pmt_overflow_cnt <= &pmt_overflow_cnt ? pmt_overflow_cnt : pmt_overflow_cnt + 1;
end

reg          pmt_rx_start_d0 = 'd0;
reg          pmt_rx_start_d1 = 'd0;
reg [32-1:0] encode_overflow_cnt = 'd0;
always @(posedge aurora_log_clk_1) begin
    pmt_rx_start_d0 <= pmt_rx_start_i;
    pmt_rx_start_d1 <= pmt_rx_start_d0;

    if((~pmt_rx_start_d1) && pmt_rx_start_d0)
        encode_overflow_cnt <= 'd0;
    else if(pmt_encode_en_i && x_w_encoder_fifo_full)
        encode_overflow_cnt <= &encode_overflow_cnt ? encode_overflow_cnt : encode_overflow_cnt + 1;
end

assign pmt_overflow_cnt_o    = pmt_overflow_cnt;
assign encode_overflow_cnt_o = encode_overflow_cnt;

// debug code
reg             dbg_aurora_rxen     = 'd0;
reg [16-1:0]    dbg_pmt_data        = 'd0;
always @(posedge aurora_log_clk_0) begin
    dbg_aurora_rxen <= aurora_rxen  ;
    dbg_pmt_data    <= aurora_rxdata[16-1:0];
end

wire          dbg_Xencode_vld   = (state==4) && aurora_rxen;
wire [18-1:0] dbg_Xencode       = aurora_rxdata[18 +: 18];

reg          dbg_Xencode_vld_d  = 'd0;
reg [18-1:0] dbg_Xencode_d      = 'd0;
always @(posedge aurora_log_clk_0 ) begin
    dbg_Xencode_vld_d   <= dbg_Xencode_vld;
    dbg_Xencode_d       <= dbg_Xencode;
end

reg          dbg_delta_vld      = 'd0;
reg [18-1:0] dbg_Xencode_delta  = 'd0;
always @(posedge aurora_log_clk_0 ) begin
    dbg_delta_vld       <= dbg_Xencode_vld_d;
    dbg_Xencode_delta   <= dbg_Xencode - dbg_Xencode_d;
end

reg [32-1:0] Xencode_skip_cnt = 'd0;
always @(posedge aurora_log_clk_0 ) begin
    if(~pmt_rx_start_reg2 && pmt_rx_start_reg1)
        Xencode_skip_cnt <= 'd0;
    else if(dbg_delta_vld)begin
        if(dbg_Xencode_delta[17:1])
            Xencode_skip_cnt <= (&Xencode_skip_cnt) ? Xencode_skip_cnt : Xencode_skip_cnt + 1;
    end
end

assign Xencode_skip_cnt_o = Xencode_skip_cnt;

// 增加监控 eds pmt fbc 分别产生了多少次传输命令，和last pack 统计做交叉对比
reg [32-1:0] eds_xdma_pack_cnt = 'd0;
reg [32-1:0] pmt_xdma_pack_cnt = 'd0;
reg [32-1:0] fbc_xdma_pack_cnt = 'd0;

always @(posedge aurora_log_clk_0) begin
    if(state == 4'd0)begin
        if(eds_rx_start_reg2) begin
            eds_xdma_pack_cnt <= eds_xdma_pack_cnt + 1;
        end
        
        if(fbc_rx_start_d1) begin
            fbc_xdma_pack_cnt <= fbc_xdma_pack_cnt + 1;
        end
        
        if(pmt_rx_start_reg2) begin
            pmt_xdma_pack_cnt <= pmt_xdma_pack_cnt + 1;
        end
    end
end

assign eds_xdma_pack_cnt_o = eds_xdma_pack_cnt;
assign pmt_xdma_pack_cnt_o = pmt_xdma_pack_cnt;
assign fbc_xdma_pack_cnt_o = fbc_xdma_pack_cnt;
endmodule
