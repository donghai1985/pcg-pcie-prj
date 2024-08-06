`timescale 1 ns / 1 ps

(* core_generation_info = "aurora_64b66b_0,aurora_64b66b_v12_0_6,{c_aurora_lanes=1,c_column_used=left,c_gt_clock_1=GTXQ0,c_gt_clock_2=None,c_gt_loc_1=1,c_gt_loc_10=X,c_gt_loc_11=X,c_gt_loc_12=X,c_gt_loc_13=X,c_gt_loc_14=X,c_gt_loc_15=X,c_gt_loc_16=X,c_gt_loc_17=X,c_gt_loc_18=X,c_gt_loc_19=X,c_gt_loc_2=X,c_gt_loc_20=X,c_gt_loc_21=X,c_gt_loc_22=X,c_gt_loc_23=X,c_gt_loc_24=X,c_gt_loc_25=X,c_gt_loc_26=X,c_gt_loc_27=X,c_gt_loc_28=X,c_gt_loc_29=X,c_gt_loc_3=X,c_gt_loc_30=X,c_gt_loc_31=X,c_gt_loc_32=X,c_gt_loc_33=X,c_gt_loc_34=X,c_gt_loc_35=X,c_gt_loc_36=X,c_gt_loc_37=X,c_gt_loc_38=X,c_gt_loc_39=X,c_gt_loc_4=X,c_gt_loc_40=X,c_gt_loc_41=X,c_gt_loc_42=X,c_gt_loc_43=X,c_gt_loc_44=X,c_gt_loc_45=X,c_gt_loc_46=X,c_gt_loc_47=X,c_gt_loc_48=X,c_gt_loc_5=X,c_gt_loc_6=X,c_gt_loc_7=X,c_gt_loc_8=X,c_gt_loc_9=X,c_lane_width=4,c_line_rate=10.0,c_gt_type=gtx,c_qpll=true,c_nfc=false,c_nfc_mode=IMM,c_refclk_frequency=100.0,c_simplex=false,c_simplex_mode=TX,c_stream=false,c_ufc=false,c_user_k=false,flow_mode=None,interface_mode=Framing,dataflow_config=Duplex}" *)
(* DowngradeIPIdentifiedWarnings="yes" *)
//////////////////////////////////////////////////////////////////////////////////
// Company: zas
// Engineer: songyuxin
// 
// Create Date: 2023/10/10
// Design Name: PCG
// Module Name: aurora_64b66b_0_exdes
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

module aurora_64b66b_0_exdes #(
    parameter           TCQ                = 0.1
)(
    output              aurora_log_clk_o                ,
    // output              gt_reset_o                      ,
    // aurora_clk0
    output              eds_aurora_rxen_o               ,
    output  [64-1:0]    eds_aurora_rxdata_o             ,
    output              encoder_rxen_o                  ,
    output  [64-1:0]    encoder_rxdata_o                ,

    // sys_clk
    output              eds_rx_start_o                  ,
    output              fbc_rx_start_o                  ,
    output              pmt_rx_start_o                  ,

    input               sys_clk_i                       ,
    output  [32-1:0]    aurora_timing_soft_err_o        ,
    output  [32-1:0]    eds_aurora_pack_cnt_o           ,
    output  [32-1:0]    pmt_aurora_pack_cnt_o           ,
    output  [32-1:0]    fbc_aurora_pack_cnt_o           ,

    // Reset and clk
    input               RESET                           ,
    input               PMA_INIT                        ,
    input               INIT_CLK_P                      ,
    // input               INIT_CLK_N                      ,
    input               DRP_CLK_IN                      ,

    // Status
    output reg          LANE_UP                         ,
    output reg          CHANNEL_UP                      ,
    output reg          HARD_ERR                        ,
    output reg          SOFT_ERR                        ,

    // GTX Reference Clock Interface
    input               GTXQ0_P                         ,
    input               GTXQ0_N                         ,
    // GT clk to aurora_1_support
    output              refclk1_o                       ,

    // GTX Serial I/O
    input               RXP                             ,
    input               RXN                             ,
    output              TXP                             ,
    output              TXN                             
);
//////////////////////////////////////////////////////////////////////////////////
// *********** Define Parameter Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>



//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Register Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
reg     [127:0]         pma_init_stage              = {128{1'b1}};
reg     [23:0]          pma_init_pulse_width_cnt    = 24'h0;
reg                     pma_init_assertion          = 1'b0;
reg                     gt_reset_delayed_r1;
reg                     gt_reset_delayed_r2;
reg     [32-1:0]        aurora_timing_soft_err      = 'd0;

//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Wire Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
//TX Interface
wire    [63:0]          tx_tdata                ; 
wire                    tx_tvalid               ;
wire    [7:0]           tx_tkeep                ;  
wire                    tx_tlast                ;
wire                    tx_tready               ;
//RX Interface
wire    [63:0]          rx_tdata                ;  
wire                    rx_tvalid               ;
wire    [7:0]           rx_tkeep                ;  
wire                    rx_tlast                ;


//Error Detection Interface
wire                    hard_err                ;
wire                    soft_err                ;

//Status
wire                    channel_up              ;
wire                    lane_up                 ;

//System Interface      
wire                    aurora_rst              ;
wire                    gt_reset_tmp            ;
wire                    gt_rxcdrovrden          ;
wire                    gt_reset_delayed        ;
wire                    gt_reset_eff            ;
wire                    gt_reset                ;
wire                    link_reset              ;
wire                    system_reset            ;
wire                    pll_not_locked          ;

wire                    power_down              ;
wire    [2:0]           loopback                ;
wire                    gt_pll_lock             ;
wire                    tx_out_clk              ;

// clock
wire                    user_clk                ;
wire                    sync_clk                ;
wire                    init_clk                ; // synthesis syn_keep = 1
wire                    drp_clk                 ;

wire    [8:0]           drpaddr_in              ;
wire    [15:0]          drpdi_in                ;
wire    [15:0]          drpdo_out               ;
wire                    drprdy_out              ;
wire                    drpen_in                ;
wire                    drpwe_in                ;
wire    [7:0]           qpll_drpaddr_in         ;
wire    [15:0]          qpll_drpdi_in           ;
wire    [15:0]          qpll_drpdo_out          ;
wire                    qpll_drprdy_out         ;
wire                    qpll_drpen_in           ;
wire                    qpll_drpwe_in           ;


wire                    pcie_eds_end_sync       ;
wire                    pcie_pmt_end_sync       ;

wire                    eds_rx_start            ;
wire                    fbc_rx_start            ;
wire                    pmt_rx_start            ;
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Instance Module
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
// xpm_cdc_array_single #(
//     .DEST_SYNC_FF(2),   // DECIMAL; range: 2-10
//     .INIT_SYNC_FF(0),   // DECIMAL; 0=disable simulation init values, 1=enable simulation init values
//     .SIM_ASSERT_CHK(0), // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
//     .SRC_INPUT_REG(1),  // DECIMAL; 0=do not register input, 1=register input
//     .WIDTH(2)           // DECIMAL; range: 1-1024
//  )
//  xpm_cdc_pcie_end_inst (
//     .dest_out({pcie_eds_end_sync,pcie_pmt_end_sync}), // WIDTH-bit output: src_in synchronized to the destination clock domain. This
//                          // output is registered.

//     .dest_clk(user_clk), // 1-bit input: Clock signal for the destination clock domain.
//     .src_clk(sys_clk_i),   // 1-bit input: optional; required when SRC_INPUT_REG = 1
//     .src_in({pcie_eds_rx_end_i,pcie_pmt_rx_end_i})      // WIDTH-bit input: Input single-bit array to be synchronized to destination clock
//                          // domain. It is assumed that each bit of the array is unrelated to the others. This
//                          // is reflected in the constraints applied to this macro. To transfer a binary value
//                          // losslessly across the two clock domains, use the XPM_CDC_GRAY macro instead.
//  );

 xpm_cdc_array_single #(
    .DEST_SYNC_FF(2),   // DECIMAL; range: 2-10
    .INIT_SYNC_FF(0),   // DECIMAL; 0=disable simulation init values, 1=enable simulation init values
    .SIM_ASSERT_CHK(0), // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
    .SRC_INPUT_REG(1),  // DECIMAL; 0=do not register input, 1=register input
    .WIDTH(3)           // DECIMAL; range: 1-1024
 )
 xpm_cdc_rx_signal_inst (
    .dest_out({
        eds_rx_start_o
       ,fbc_rx_start_o
       ,pmt_rx_start_o
   }), // WIDTH-bit output: src_in synchronized to the destination clock domain. This
                         // output is registered.

    .dest_clk(sys_clk_i), // 1-bit input: Clock signal for the destination clock domain.
    .src_clk(user_clk),   // 1-bit input: optional; required when SRC_INPUT_REG = 1
    .src_in({
             eds_rx_start
            ,fbc_rx_start
            ,pmt_rx_start  
        })      // WIDTH-bit input: Input single-bit array to be synchronized to destination clock
                         // domain. It is assumed that each bit of the array is unrelated to the others. This
                         // is reflected in the constraints applied to this macro. To transfer a binary value
                         // losslessly across the two clock domains, use the XPM_CDC_GRAY macro instead.

 );

aurora_64b66b_tx aurora_64b66b_tx_inst(
    // .pcie_eds_rx_end_i          ( pcie_eds_end_sync             ),
    // .pcie_pmt_rx_end_i          ( pcie_pmt_end_sync             ),
    
    // System Interface
    .USER_CLK                   ( user_clk                      ),
    .RESET                      ( aurora_rst                    ),
    .CHANNEL_UP                 ( 'd1                           ),
    
    .tx_tvalid_o                ( tx_tvalid                     ),
    .tx_tdata_o                 ( tx_tdata                      ),
    .tx_tkeep_o                 ( tx_tkeep                      ),
    .tx_tlast_o                 ( tx_tlast                      ),
    .tx_tready_i                ( tx_tready                     )
);

aurora_64b66b_rx aurora_64b66b_rx_inst(
    // eds
    .eds_rx_start_o             ( eds_rx_start                  ),
    .eds_aurora_rxen_o          ( eds_aurora_rxen_o             ),
    .eds_aurora_rxdata_o        ( eds_aurora_rxdata_o           ),
    // fbc
    .fbc_rx_start_o             ( fbc_rx_start                  ),
    // pmt encode
    .pmt_rx_start_o             ( pmt_rx_start                  ),
    .encoder_rxen_o             ( encoder_rxen_o                ), 
    .encoder_rxdata_o           ( encoder_rxdata_o              ),
    
    .eds_aurora_pack_cnt_o      ( eds_aurora_pack_cnt_o         ),
    .pmt_aurora_pack_cnt_o      ( pmt_aurora_pack_cnt_o         ),
    .fbc_aurora_pack_cnt_o      ( fbc_aurora_pack_cnt_o         ),
    
    // System Interface
    .USER_CLK                   ( user_clk                      ),      
    .RESET                      ( aurora_rst                    ),
    .CHANNEL_UP                 ( 'd1                           ),

    .rx_tvalid_i                ( rx_tvalid                     ),
    .rx_tdata_i                 ( rx_tdata                      ),
    .rx_tkeep_i                 ( rx_tkeep                      ),
    .rx_tlast_i                 ( rx_tlast                      )
);

BUFG drpclk_bufg_i(
    .I  (DRP_CLK_IN),
    .O  (drp_clk)
);


// this is non shared mode, the clock, GT common are part of example design.
aurora_64b66b_0_support aurora_64b66b_0_block_i(
    // TX AXI4-S Interface
    .s_axi_tx_tdata             ( tx_tdata                      ),
    .s_axi_tx_tlast             ( tx_tlast                      ),
    .s_axi_tx_tkeep             ( tx_tkeep                      ),
    .s_axi_tx_tvalid            ( tx_tvalid                     ),
    .s_axi_tx_tready            ( tx_tready                     ),

    // RX AXI4-S Interface
    .m_axi_rx_tdata             ( rx_tdata                      ),
    .m_axi_rx_tlast             ( rx_tlast                      ),
    .m_axi_rx_tkeep             ( rx_tkeep                      ),
    .m_axi_rx_tvalid            ( rx_tvalid                     ),

    // GT Serial I/O
    .rxp                        ( RXP                           ),
    .rxn                        ( RXN                           ),

    .txp                        ( TXP                           ),
    .txn                        ( TXN                           ),

    //GT Reference Clock Interface
    .gt_refclk1_p               ( GTXQ0_P                       ),
    .gt_refclk1_n               ( GTXQ0_N                       ),
    // GT clk to aurora_2_support
    .refclk1_o                  ( refclk1_o                     ),

    // Error Detection Interface
    .hard_err                   ( hard_err                      ),
    .soft_err                   ( soft_err                      ),

    // Status
    .channel_up                 ( channel_up                    ),
    .lane_up                    ( lane_up                       ),

    // System Interface
    .init_clk_out               ( init_clk                      ),
    .user_clk_out               ( user_clk                      ),

    .sync_clk_out               ( sync_clk                      ),
    .reset_pb                   ( aurora_rst                    ),
    .gt_rxcdrovrden_in          ( gt_rxcdrovrden                ),
    .power_down                 ( power_down                    ),
    .loopback                   ( loopback                      ),
    .pma_init                   ( gt_reset                      ),
    .gt_pll_lock                ( gt_pll_lock                   ),
    .drp_clk_in                 ( drp_clk                       ),
    //---------------------- GT DRP Ports ----------------------
    .drpaddr_in                 ( drpaddr_in                    ),
    .drpdi_in                   ( drpdi_in                      ),
    .drpdo_out                  ( drpdo_out                     ),
    .drprdy_out                 ( drprdy_out                    ),
    .drpen_in                   ( drpen_in                      ),
    .drpwe_in                   ( drpwe_in                      ),


    //---------------------- GTXE2 COMMON DRP Ports ----------------------
    .qpll_drpaddr_in            ( qpll_drpaddr_in               ),
    .qpll_drpdi_in              ( qpll_drpdi_in                 ),
    .qpll_drpdo_out             ( qpll_drpdo_out                ),
    .qpll_drprdy_out            ( qpll_drprdy_out               ),
    .qpll_drpen_in              ( qpll_drpen_in                 ),
    .qpll_drpwe_in              ( qpll_drpwe_in                 ),
    .init_clk_p                 ( INIT_CLK_P                    ),
    // .init_clk_n                 ( INIT_CLK_N                    ),
    .link_reset_out             ( link_reset                    ),
    .mmcm_not_locked_out        ( pll_not_locked                ),

    .sys_reset_out              ( system_reset                  ),
    .tx_out_clk                 ( tx_out_clk                    )
);


//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Logic Design
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

// System Interface
assign  power_down_i        = 1'b0;
// Native DRP Interface
assign  drpaddr_in          = 'h0;
assign  drpdi_in            = 16'h0;
assign  drpen_in            = 1'b0;
assign  drpwe_in            = 1'b0;

assign  qpll_drpaddr_in     =  8'h0;
assign  qpll_drpdi_in       =  16'h0;
assign  qpll_drpen_in       =  1'b0;
assign  qpll_drpwe_in       =  1'b0;

// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  gt_reset timming
//  <- 128clk cycle -> <------------24bit------------> 
//                      ______________________________
//  ___________________|                              |______________________
//
// <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
always @(posedge init_clk)begin
    pma_init_stage[127:0] <= {pma_init_stage[126:0], gt_reset_tmp};
end

assign gt_reset_delayed = pma_init_stage[127];

always @(posedge init_clk)begin
    gt_reset_delayed_r1   <= #TCQ gt_reset_delayed;
    gt_reset_delayed_r2   <= #TCQ gt_reset_delayed_r1;
end
always @(posedge init_clk) begin
    if(~gt_reset_delayed_r2 & gt_reset_delayed_r1 & ~pma_init_assertion & (pma_init_pulse_width_cnt != 24'hFFFFFF))
        pma_init_assertion <= 1'b1;
    else if (pma_init_assertion & pma_init_pulse_width_cnt == 24'hFFFFFF)
        pma_init_assertion <= 1'b0;

    if(pma_init_assertion)
        pma_init_pulse_width_cnt <= pma_init_pulse_width_cnt + 24'h1;
end

assign  gt_reset_tmp      = PMA_INIT;
assign  aurora_rst        = RESET;
assign  gt_reset_eff      = pma_init_assertion ? 1'b1 : gt_reset_delayed;
assign  gt_reset          = gt_reset_eff;
assign  gt_rxcdrovrden    = 1'b0;
assign  loopback          = 3'b000;

// Register User Outputs from core.
always @(posedge user_clk)begin
    HARD_ERR    <= #TCQ hard_err;
    SOFT_ERR    <= #TCQ soft_err;
    LANE_UP     <= #TCQ lane_up;
    CHANNEL_UP  <= #TCQ channel_up;
end

assign aurora_log_clk_o         = user_clk;
// assign gt_reset_o               = gt_reset;
// assign pcie_eds_end_o           = pcie_eds_end;
// assign pcie_pmt_end_o           = pcie_pmt_end;

// check soft error every scan
reg pmt_rx_start_d = 'd0;

always @(posedge user_clk) begin
    pmt_rx_start_d <= #TCQ pmt_rx_start;

    if(~pmt_rx_start_d && pmt_rx_start)
        aurora_timing_soft_err <= #TCQ 'd0;
    else if(SOFT_ERR)begin
        if(aurora_timing_soft_err[31])
            aurora_timing_soft_err <= #TCQ aurora_timing_soft_err;
        else
            aurora_timing_soft_err <= #TCQ aurora_timing_soft_err + 1; 
    end
end

assign aurora_timing_soft_err_o = aurora_timing_soft_err;


// debug code
// wire            debug_encode_en = encoder_rxen_o;
// wire    [31:0]  debug_encode_x  = encoder_rxdata_o[31:0];
// wire    [31:0]  debug_encode_w  = encoder_rxdata_o[63:32];
  
// reg [32-1:0] w_encode_delay = 'd0;
// always @(posedge user_clk) begin
//     if(debug_encode_en)
//         w_encode_delay <= debug_encode_w;
// end

// reg [17:0] w_encode_diff = 'd0;
// always @(posedge user_clk) begin
//     if(debug_encode_en)begin
//         if(w_encode_delay > debug_encode_w)
//             w_encode_diff <= debug_encode_w + {18{1'b1}} - w_encode_delay;
//         else
//             w_encode_diff <= debug_encode_w - w_encode_delay;
//     end
// end

// reg w_encode_en_d = 'd0;
// always @(posedge user_clk) begin
//     w_encode_en_d <= debug_encode_en;
// end

// reg w_encode_first = 'd0;
// always @(posedge user_clk) begin
//     if(pmt_rx_start_i)
//         w_encode_first <= 'd0;
//     else if(w_encode_en_d)
//         w_encode_first <= 'd1;
// end

// reg w_encode_err = 'd0;
// always @(posedge user_clk) begin
//     if(~w_encode_first)begin
//         w_encode_err <= 'd0;
//     end
//     else if(w_encode_en_d)begin
//         if(w_encode_diff > 'd10)
//             w_encode_err <= 'd1;
//         else 
//             w_encode_err <= 'd0;
//     end
// end
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
endmodule
 
