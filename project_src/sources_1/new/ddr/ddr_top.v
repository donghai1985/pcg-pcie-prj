`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/06/20
// Design Name: songyuxin
// Module Name: ddr_top
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
// `define DDR_TEST

module ddr_top #(
    parameter                               C_M_AXI_ID_WIDTH    = 4             ,
    parameter                               C_DATA_WIDTH        = 128           ,
    parameter                               C_M_AXI_DATA_WIDTH  = C_DATA_WIDTH  
)(
    // clk & rst
    input                                   clk_500m_i              , // ddr System clk input
    input                                   clk_200m_i              , // ddr Reference clk input
    input                                   rst_i                   , // ddr clk lock
    input                                   sys_clk_i               , // System clk input
    input                                   sys_rst_i               , // System rst input
    input                                   xdma_user_clk_i         , // xdma clk , read ddr
    input                                   xdma_rst_i              ,

    // ddr write channel, within aurora clk
    // input                                   eds_rx_start_i          ,
    // input                                   pmt_rx_start_i          ,
    // input                                   fbc_rx_start_i          ,
    input                                   aurora_wr_start_i       ,
    input                                   aurora_wr_en_i          ,
    input       [512-1:0]                   aurora_wr_data_i        ,
    input                                   xdma_err_reset_i        ,

    // ddr read channel, within xdma clk
    input       [C_M_AXI_ID_WIDTH-1:0]      s_axi_arid_i            ,
    input       [64-1:0]                    s_axi_araddr_i          ,
    input       [7:0]                       s_axi_arlen_i           ,
    input       [2:0]                       s_axi_arsize_i          ,
    input       [1:0]                       s_axi_arburst_i         ,
    input                                   s_axi_arvalid_i         ,
    output                                  s_axi_arready_o         ,
    output      [C_M_AXI_ID_WIDTH-1:0]      s_axi_rid_o             ,
    output      [C_M_AXI_DATA_WIDTH-1:0]    s_axi_rdata_o           ,
    output      [1:0]                       s_axi_rresp_o           ,
    output                                  s_axi_rlast_o           ,
    output                                  s_axi_rvalid_o          ,
    input                                   s_axi_rready_i          ,
    output                                  up_irq_o                ,
    input                                   up_irq_ack_i            ,
    output      [32-1:0]                    up_check_irq_o          ,
    output      [32-1:0]                    up_check_frame_o        ,
    output      [32-1:0]                    irq_timeout_fault_cnt_o ,
    input                                   debug_register_rst_i    ,
    input                                   xdma_vout_state_rst_i   ,
    output      [32-1:0]                    xdma_idle_time_max_o    ,
    output      [32-1:0]                    xdma_hold_time_max_o    ,
    output      [32-1:0]                    pmt_lose_pack_cnt_o     ,
    output      [32-1:0]                    pmt_lose_pack_mem_cnt_o ,
    output      [32-1:0]                    wr_frame_cnt_o          ,
    output      [32-1:0]                    rd_frame_cnt_o          ,
    output      [32-1:0]                    err_state_cnt_o         ,
    output      [32-1:0]                    ddr_last_pack_cnt_o     ,
    output      [32-1:0]                    ddr_usage_max_o         ,

    // ddr complete reset
    output                                  init_calib_complete_o   ,
    // ddr interface
    inout       [63:0]                      ddr3_dq                 ,
    inout       [7:0]                       ddr3_dqs_n              ,
    inout       [7:0]                       ddr3_dqs_p              ,
    output      [15:0]                      ddr3_addr               ,
    output      [2:0]                       ddr3_ba                 ,
    output                                  ddr3_ras_n              ,
    output                                  ddr3_cas_n              ,
    output                                  ddr3_we_n               ,
    output                                  ddr3_reset_n            ,
    output                                  ddr3_ck_p               ,
    output                                  ddr3_ck_n               ,
    output                                  ddr3_cke                ,
    output                                  ddr3_cs_n               ,
    output      [7:0]                       ddr3_dm                 ,
    output                                  ddr3_odt                
);


//////////////////////////////////////////////////////////////////////////////////
// *********** Define Parameter Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
localparam                          DQ_WIDTH          = 64  ;
localparam                          DQS_WIDTH         = 8   ; //DQ_WIDTH/8  ;
localparam                          ADDR_WIDTH        = 30  ;
localparam                          DATA_WIDTH        = 64  ;
localparam                          MEM_DATA_BITS     = 512 ;
localparam                          BURST_LEN         = 64  ;
localparam                          FRAME_DEPTH_WID   = 9   ;
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Register Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>


//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Wire Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
wire                                ddr_log_rst             ;

wire                                ch0_wr_ddr_req          ;
wire    [8-1:0]                     ch0_wr_ddr_len          ;
wire    [ADDR_WIDTH-1:0]            ch0_wr_ddr_addr         ;
wire                                ch0_wr_ddr_data_req     ;
wire    [MEM_DATA_BITS - 1:0]       ch0_wr_ddr_data         ;
wire                                ch0_wr_ddr_finish       ;

wire                                ch0_rd_ddr_req          ;
wire    [8-1:0]                     ch0_rd_ddr_len          ;
wire    [ADDR_WIDTH-1:0]            ch0_rd_ddr_addr         ;
wire                                ch0_rd_ddr_data_valid   ;
wire    [MEM_DATA_BITS - 1:0]       ch0_rd_ddr_data         ;
wire                                ch0_rd_ddr_finish       ;

wire                                ch1_rd_ddr_req          ;
wire    [8-1:0]                     ch1_rd_ddr_len          ;
wire    [ADDR_WIDTH-1:0]            ch1_rd_ddr_addr         ;
wire                                ch1_rd_ddr_data_valid   ;
wire    [MEM_DATA_BITS - 1:0]       ch1_rd_ddr_data         ;
wire                                ch1_rd_ddr_finish       ;

wire                                ddr_reset_flag          ;
wire    [FRAME_DEPTH_WID-1:0]       wr_frame_addr           ;
wire    [FRAME_DEPTH_WID-1:0]       rd_frame_addr           ;
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Instance Module
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
`ifdef DDR_TEST
ddr_test #(
    .ADDR_WIDTH                     ( ADDR_WIDTH                ),
    .MEM_DATA_BITS                  ( MEM_DATA_BITS             ),
    .BURST_LEN                      ( BURST_LEN                 )
)ddr_test_inst(
    // clk & rst 
    .ddr_clk_i                      ( ui_clk                    ),
    .ddr_rst_i                      ( ddr_log_rst               ),

    .wr_ddr_req_o                   ( ch0_wr_ddr_req            ),
    .wr_ddr_len_o                   ( ch0_wr_ddr_len            ),
    .wr_ddr_addr_o                  ( ch0_wr_ddr_addr           ),
    .ddr_fifo_rd_req_i              ( ch0_wr_ddr_data_req       ),
    .wr_ddr_data_o                  ( ch0_wr_ddr_data           ),
    .wr_ddr_finish_i                ( ch0_wr_ddr_finish         ),

    .rd_ddr_req_o                   ( ch0_rd_ddr_req            ),  
    .rd_ddr_len_o                   ( ch0_rd_ddr_len            ),
    .rd_ddr_addr_o                  ( ch0_rd_ddr_addr           ),
    .rd_ddr_data_valid_i            ( ch0_rd_ddr_data_valid     ),
    .rd_ddr_data_i                  ( ch0_rd_ddr_data           ),
    .rd_ddr_finish_i                ( ch0_rd_ddr_finish         ) 
    
);
`else
xdma_vin_ctrl #(
    .ADDR_WIDTH                     ( ADDR_WIDTH                ),
    .DATA_WIDTH                     ( DATA_WIDTH                ),
    .MEM_DATA_BITS                  ( MEM_DATA_BITS             ),
    .BURST_LEN                      ( BURST_LEN                 ),
    .FRAME_DEPTH_WID                ( FRAME_DEPTH_WID           )
)xdma_vin_ctrl_inst(
    // clk & rst
    .xdma_user_clk_i                ( xdma_user_clk_i           ),
    .sys_clk_i                      ( sys_clk_i                 ),
    .sys_rst_i                      ( sys_rst_i                 ),
    .ddr_clk_i                      ( ui_clk                    ),
    .ddr_rst_i                      ( ddr_log_rst               ),

    // .eds_rx_start_i                 ( eds_rx_start_i            ),
    // .pmt_rx_start_i                 ( pmt_rx_start_i            ),
    // .fbc_rx_start_i                 ( fbc_rx_start_i            ),
    .aurora_wr_start_i              ( aurora_wr_start_i         ),
    .aurora_wr_en_i                 ( aurora_wr_en_i            ),
    .aurora_wr_data_i               ( aurora_wr_data_i          ),
    .xdma_err_reset_i               ( xdma_err_reset_i          ),

    .pmt_lose_pack_cnt_o            ( pmt_lose_pack_cnt_o       ),
    .pmt_lose_pack_mem_cnt_o        ( pmt_lose_pack_mem_cnt_o   ),
    .wr_frame_cnt_o                 ( wr_frame_cnt_o            ),
    .rd_frame_cnt_o                 ( rd_frame_cnt_o            ),
    .err_state_cnt_o                ( err_state_cnt_o           ),
    .ddr_last_pack_cnt_o            ( ddr_last_pack_cnt_o       ),
    .ddr_usage_max_o                ( ddr_usage_max_o           ),

    .ddr_reset_flag_o               ( ddr_reset_flag            ),
    .wr_frame_addr_o                ( wr_frame_addr             ),
    .rd_frame_addr_i                ( rd_frame_addr             ),

    .wr_ddr_req_o                   ( ch0_wr_ddr_req            ),
    .wr_ddr_len_o                   ( ch0_wr_ddr_len            ),
    .wr_ddr_addr_o                  ( ch0_wr_ddr_addr           ),
    .ddr_fifo_rd_req_i              ( ch0_wr_ddr_data_req       ),
    .wr_ddr_data_o                  ( ch0_wr_ddr_data           ),
    .wr_ddr_finish_i                ( ch0_wr_ddr_finish         ) 
);

xdma_vout_ctrl #(
    .C_M_AXI_ID_WIDTH               ( C_M_AXI_ID_WIDTH          ),
    .C_DATA_WIDTH                   ( C_DATA_WIDTH              ),
    .C_M_AXI_DATA_WIDTH             ( C_M_AXI_DATA_WIDTH        ),
    .ADDR_WIDTH                     ( ADDR_WIDTH                ),
    .DATA_WIDTH                     ( DATA_WIDTH                ),
    .MEM_DATA_BITS                  ( MEM_DATA_BITS             ),
    .BURST_LEN                      ( BURST_LEN                 ),
    .FRAME_DEPTH_WID                ( FRAME_DEPTH_WID           )
)xdma_vout_ctrl_inst(
    // clk & rst 
    .xdma_user_clk_i                ( xdma_user_clk_i           ),
    .xdma_rst_i                     ( xdma_rst_i                ),
    .ddr_clk_i                      ( ui_clk                    ),
    .ddr_rst_i                      ( ddr_log_rst               ),

    .s_axi_arid_i                   ( s_axi_arid_i              ),
    .s_axi_araddr_i                 ( s_axi_araddr_i            ),
    .s_axi_arlen_i                  ( s_axi_arlen_i             ),
    .s_axi_arsize_i                 ( s_axi_arsize_i            ),
    .s_axi_arburst_i                ( s_axi_arburst_i           ),
    .s_axi_arvalid_i                ( s_axi_arvalid_i           ),
    .s_axi_arready_o                ( s_axi_arready_o           ),
    .s_axi_rid_o                    ( s_axi_rid_o               ),
    .s_axi_rdata_o                  ( s_axi_rdata_o             ),
    .s_axi_rresp_o                  ( s_axi_rresp_o             ),
    .s_axi_rlast_o                  ( s_axi_rlast_o             ),
    .s_axi_rvalid_o                 ( s_axi_rvalid_o            ),
    .s_axi_rready_i                 ( s_axi_rready_i            ),
    .up_irq_o                       ( up_irq_o                  ),
    .up_irq_ack_i                   ( up_irq_ack_i              ),
    .up_check_irq_o                 ( up_check_irq_o            ),
    .up_check_frame_o               ( up_check_frame_o          ),
    .irq_timeout_fault_cnt_o        ( irq_timeout_fault_cnt_o   ),
    .debug_register_rst_i           ( debug_register_rst_i      ),
    .xdma_vout_state_rst_i          ( xdma_vout_state_rst_i     ),
    .xdma_idle_time_max_o           ( xdma_idle_time_max_o      ),
    .xdma_hold_time_max_o           ( xdma_hold_time_max_o      ),
    // .pmt_rx_start_i                 ( pmt_rx_start_i            ),
    // .XDMA_Xencode_skip_cnt_o        ( XDMA_Xencode_skip_cnt_o   ),
    
    .ddr_reset_flag_i               ( ddr_reset_flag            ),
    .wr_frame_addr_i                ( wr_frame_addr             ),
    .rd_frame_addr_o                ( rd_frame_addr             ),

    .rd_ddr_req_o                   ( ch0_rd_ddr_req            ),  
    .rd_ddr_len_o                   ( ch0_rd_ddr_len            ),
    .rd_ddr_addr_o                  ( ch0_rd_ddr_addr           ),
    .rd_ddr_data_valid_i            ( ch0_rd_ddr_data_valid     ),
    .rd_ddr_data_i                  ( ch0_rd_ddr_data           ),
    .rd_ddr_finish_i                ( ch0_rd_ddr_finish         ) 
    
);
`endif // DDR_TEST

mem_ctrl#(
    .DQ_WIDTH                       ( DQ_WIDTH                  ),
    .DQS_WIDTH                      ( DQS_WIDTH                 ),
    .MEM_DATA_BITS                  ( MEM_DATA_BITS             ),
    .ADDR_WIDTH                     ( ADDR_WIDTH                )
)mem_ctrl_inst(
    // clk & rst
    .rst_i                          ( rst_i                     ),
    .clk_500m_i                     ( clk_500m_i                ), // ddr System clk input
    .clk_200m_i                     ( clk_200m_i                ), // ddr Reference clk input
    .ui_clk                         ( ui_clk                    ), // ddr PHY to memory controller clk.    312.5/4MHz
    .ddr_log_rst_o                  ( ddr_log_rst               ),

    // write channel interface 
    .ch0_wr_ddr_req                 ( ch0_wr_ddr_req            ),
    .ch0_wr_ddr_len                 ( ch0_wr_ddr_len            ),
    .ch0_wr_ddr_addr                ( ch0_wr_ddr_addr           ),
    .ch0_wr_ddr_data_req            ( ch0_wr_ddr_data_req       ), 
    .ch0_wr_ddr_data                ( ch0_wr_ddr_data           ),
    .ch0_wr_ddr_finish              ( ch0_wr_ddr_finish         ),
    
    // read channel interface 
    .ch0_rd_ddr_req                 ( ch0_rd_ddr_req            ),
    .ch0_rd_ddr_len                 ( ch0_rd_ddr_len            ),
    .ch0_rd_ddr_addr                ( ch0_rd_ddr_addr           ),
    .ch0_rd_ddr_data_valid          ( ch0_rd_ddr_data_valid     ),
    .ch0_rd_ddr_data                ( ch0_rd_ddr_data           ),
    .ch0_rd_ddr_finish              ( ch0_rd_ddr_finish         ),
    
    .ch1_rd_ddr_req                 ( ch1_rd_ddr_req            ),
    .ch1_rd_ddr_len                 ( ch1_rd_ddr_len            ),
    .ch1_rd_ddr_addr                ( ch1_rd_ddr_addr           ),
    .ch1_rd_ddr_data_valid          ( ch1_rd_ddr_data_valid     ),
    .ch1_rd_ddr_data                ( ch1_rd_ddr_data           ),
    .ch1_rd_ddr_finish              ( ch1_rd_ddr_finish         ),
            
    // DDR interface 
    .init_calib_complete_o          ( init_calib_complete_o     ),
    .ddr3_dq                        ( ddr3_dq                   ),
    .ddr3_dqs_n                     ( ddr3_dqs_n                ),
    .ddr3_dqs_p                     ( ddr3_dqs_p                ),
    .ddr3_addr                      ( ddr3_addr                 ),
    .ddr3_ba                        ( ddr3_ba                   ),
    .ddr3_ras_n                     ( ddr3_ras_n                ),
    .ddr3_cas_n                     ( ddr3_cas_n                ),
    .ddr3_we_n                      ( ddr3_we_n                 ),
    .ddr3_reset_n                   ( ddr3_reset_n              ),
    .ddr3_ck_p                      ( ddr3_ck_p                 ),
    .ddr3_ck_n                      ( ddr3_ck_n                 ),
    .ddr3_cke                       ( ddr3_cke                  ),
    .ddr3_cs_n                      ( ddr3_cs_n                 ),
    .ddr3_dm                        ( ddr3_dm                   ),
    .ddr3_odt                       ( ddr3_odt                  )
);

//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


//////////////////////////////////////////////////////////////////////////////////
// *********** Logic Design
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>


//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


endmodule
