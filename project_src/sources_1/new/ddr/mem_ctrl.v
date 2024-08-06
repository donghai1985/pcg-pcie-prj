`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/06/21
// Design Name: songyuxin
// Module Name: mem_ctrl
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
//      The module contains read and write arbitration control module, which is 
//      equivalent to extending DDR to multiple interfaces.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module mem_ctrl#(
    parameter                       DQ_WIDTH        = 32    ,
    parameter                       DQS_WIDTH       = 4     ,
    parameter                       MEM_DATA_BITS   = 256   ,
    parameter                       ADDR_WIDTH      = 30
)(
    // clk & rst
    input                           rst_i                   ,
    input                           clk_500m_i              , // ddr System clk input
    input                           clk_200m_i              , // ddr Reference clk input
    output                          ui_clk                  , // ddr PHY to memory controller clk.    312.5/4MHz
    // input                           laser_rst_i             ,
    output                          ddr_log_rst_o           , 

    // write channel interface 
    input                           ch0_wr_ddr_req          ,
    input   [8-1:0]                 ch0_wr_ddr_len          ,
    input   [ADDR_WIDTH-1:0]        ch0_wr_ddr_addr         ,
    output                          ch0_wr_ddr_data_req     , 
    input   [MEM_DATA_BITS-1:0]     ch0_wr_ddr_data         ,
    output                          ch0_wr_ddr_finish       ,
    
    // read channel interface 
    input                           ch0_rd_ddr_req          ,
    input   [8-1:0]                 ch0_rd_ddr_len          ,
    input   [ADDR_WIDTH-1:0]        ch0_rd_ddr_addr         ,
    output                          ch0_rd_ddr_data_valid   ,
    output  [MEM_DATA_BITS - 1:0]   ch0_rd_ddr_data         ,
    output                          ch0_rd_ddr_finish       ,
    
    input                           ch1_rd_ddr_req          ,
    input   [8-1:0]                 ch1_rd_ddr_len          ,
    input   [ADDR_WIDTH-1:0]        ch1_rd_ddr_addr         ,
    output                          ch1_rd_ddr_data_valid   ,
    output  [MEM_DATA_BITS - 1:0]   ch1_rd_ddr_data         ,
    output                          ch1_rd_ddr_finish       ,
            
    // DDR interface 
    output                          init_calib_complete_o   ,
    inout   [DQ_WIDTH-1:0]          ddr3_dq                 ,
    inout   [DQS_WIDTH-1:0]         ddr3_dqs_n              ,
    inout   [DQS_WIDTH-1:0]         ddr3_dqs_p              ,
    output  [15:0]                  ddr3_addr               ,
    output  [2:0]                   ddr3_ba                 ,
    output                          ddr3_ras_n              ,
    output                          ddr3_cas_n              ,
    output                          ddr3_we_n               ,
    output                          ddr3_reset_n            ,
    output                          ddr3_ck_p               ,
    output                          ddr3_ck_n               ,
    output                          ddr3_cke                ,
    output                          ddr3_cs_n               ,
    output  [DQS_WIDTH-1:0]         ddr3_dm                 ,
    output                          ddr3_odt                
);

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Register Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
(*async_reg="true"*)reg     [2:0]                       ddr_rst_r   = 3'b000;  
(*async_reg="true"*)reg                                 ddr_log_rst = 'd0;
(*async_reg="true"*)reg     [2:0]                       sys_rst_r   = 3'b111;  

//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Wire Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
wire    [ADDR_WIDTH-1:0]            app_addr                ;
wire    [2:0]                       app_cmd                 ;
wire                                app_en                  ;
wire    [MEM_DATA_BITS-1:0]         app_wdf_data            ;
wire                                app_wdf_end             ;
wire    [DQ_WIDTH-1:0]              app_wdf_mask            ;
wire                                app_wdf_wren            ;
wire    [MEM_DATA_BITS-1:0]         app_rd_data             ;
wire                                app_rd_data_end         ;
wire                                app_rd_data_valid       ;
wire                                app_rdy                 ;
wire                                app_wdf_rdy             ;
wire                                app_sr_req              ;
wire                                app_ref_req             ;
wire                                app_zq_req              ;
wire                                app_sr_active           ;
wire                                app_ref_ack             ;
wire                                app_zq_ack              ;

wire                                wr_ddr_req              ;
wire    [8-1:0]                     wr_ddr_len              ;
wire    [ADDR_WIDTH-1:0]            wr_ddr_addr             ;
wire                                wr_ddr_data_req         ;
wire    [MEM_DATA_BITS - 1:0]       wr_ddr_data             ;
wire                                wr_ddr_finish           ;

wire                                rd_ddr_req              ;
wire    [8-1:0]                     rd_ddr_len              ;
wire    [ADDR_WIDTH-1:0]            rd_ddr_addr             ;
wire                                rd_ddr_data_valid       ;
wire    [MEM_DATA_BITS - 1:0]       rd_ddr_data             ;
wire                                rd_ddr_finish           ;
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Instance Module
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
mem_write_arbi#(
    .MEM_DATA_BITS                  ( MEM_DATA_BITS                 ),
    .ADDR_WIDTH                     ( ADDR_WIDTH                    )
)mem_write_arbi_inst(
    .ddr_rst_i                      ( ddr_log_rst                   ),
    .ddr_clk_i                      ( ui_clk                        ),
    
    .ch0_wr_ddr_req                 ( ch0_wr_ddr_req                ),
    .ch0_wr_ddr_len                 ( ch0_wr_ddr_len                ),
    .ch0_wr_ddr_addr                ( ch0_wr_ddr_addr               ),
    .ch0_wr_ddr_data_req            ( ch0_wr_ddr_data_req           ),
    .ch0_wr_ddr_data                ( ch0_wr_ddr_data               ),
    .ch0_wr_ddr_finish              ( ch0_wr_ddr_finish             ),
    
    .wr_ddr_req                     ( wr_ddr_req                    ),
    .wr_ddr_len                     ( wr_ddr_len                    ),
    .wr_ddr_addr                    ( wr_ddr_addr                   ),
    .wr_ddr_data_req                ( wr_ddr_data_req               ),
    .wr_ddr_data                    ( wr_ddr_data                   ),
    .wr_ddr_finish                  ( wr_ddr_finish                 )     
);

mem_burst_ctrl#(
    .DQ_WIDTH                       ( DQ_WIDTH                      ),
    .MEM_DATA_BITS                  ( MEM_DATA_BITS                 ),
    .ADDR_WIDTH                     ( ADDR_WIDTH                    )
)mem_burst_ctrl_inst(
    .ddr_rst_i                      ( ddr_log_rst                   ),
    .ddr_clk_i                      ( ui_clk                        ),
    
    .rd_ddr_req_i                   ( rd_ddr_req                    ),
    .rd_ddr_len_i                   ( rd_ddr_len                    ),
    .rd_ddr_addr_i                  ( rd_ddr_addr                   ),
    .rd_ddr_data_valid_o            ( rd_ddr_data_valid             ),
    .rd_ddr_data_o                  ( rd_ddr_data                   ),
    .rd_ddr_finish_o                ( rd_ddr_finish                 ),

    .wr_ddr_req_i                   ( wr_ddr_req                    ),
    .wr_ddr_len_i                   ( wr_ddr_len                    ),
    .wr_ddr_addr_i                  ( wr_ddr_addr                   ),
    .wr_ddr_data_req_o              ( wr_ddr_data_req               ),
    .wr_ddr_data_i                  ( wr_ddr_data                   ),
    .wr_ddr_finish_o                ( wr_ddr_finish                 ),
    
    // ddr interface
    .local_init_done_i              ( init_calib_complete_o         ),
    .app_addr                       ( app_addr                      ),
    .app_cmd                        ( app_cmd                       ),
    .app_en                         ( app_en                        ),
    .app_wdf_data                   ( app_wdf_data                  ),
    .app_wdf_end                    ( app_wdf_end                   ),
    .app_wdf_mask                   ( app_wdf_mask                  ),
    .app_wdf_wren                   ( app_wdf_wren                  ),
    .app_rd_data                    ( app_rd_data                   ),
    .app_rd_data_end                ( app_rd_data_end               ),
    .app_rd_data_valid              ( app_rd_data_valid             ),
    .app_rdy                        ( app_rdy                       ),
    .app_wdf_rdy                    ( app_wdf_rdy                   ),
    .app_sr_req                     ( app_sr_req                    ),
    .app_ref_req                    ( app_ref_req                   ),
    .app_zq_req                     ( app_zq_req                    ),
    .app_sr_active                  ( app_sr_active                 ),
    .app_ref_ack                    ( app_ref_ack                   ),
    .app_zq_ack                     ( app_zq_ack                    )
);

mem_read_arbi #(
    .MEM_DATA_BITS                  ( MEM_DATA_BITS                 ),
    .ADDR_WIDTH                     ( ADDR_WIDTH                    )
)mem_read_arbi_inst(
    .ddr_rst_i                      ( ddr_log_rst                   ),
    .ddr_clk_i                      ( ui_clk                        ),
    
    .ch0_rd_ddr_req                 ( ch0_rd_ddr_req                ),
    .ch0_rd_ddr_len                 ( ch0_rd_ddr_len                ),
    .ch0_rd_ddr_addr                ( ch0_rd_ddr_addr               ),
    .ch0_rd_ddr_data_valid          ( ch0_rd_ddr_data_valid         ),
    .ch0_rd_ddr_data                ( ch0_rd_ddr_data               ),
    .ch0_rd_ddr_finish              ( ch0_rd_ddr_finish             ),
    
    .ch1_rd_ddr_req                 ( ch1_rd_ddr_req                ),
    .ch1_rd_ddr_len                 ( ch1_rd_ddr_len                ),
    .ch1_rd_ddr_addr                ( ch1_rd_ddr_addr               ),
    .ch1_rd_ddr_data_valid          ( ch1_rd_ddr_data_valid         ),
    .ch1_rd_ddr_data                ( ch1_rd_ddr_data               ),
    .ch1_rd_ddr_finish              ( ch1_rd_ddr_finish             ),
    
    .rd_ddr_req                     ( rd_ddr_req                    ),
    .rd_ddr_len                     ( rd_ddr_len                    ),
    .rd_ddr_addr                    ( rd_ddr_addr                   ),
    .rd_ddr_data_valid              ( rd_ddr_data_valid             ),
    .rd_ddr_data                    ( rd_ddr_data                   ),
    .rd_ddr_finish                  ( rd_ddr_finish                 )    
);

//====================================== IP核 =============================================//
ddr3_mig ddr3_mig_inst(
    // Memory interface ports
    .ddr3_addr                      ( ddr3_addr                     ),      // output [15:0]    ddr3_addr
    .ddr3_ba                        ( ddr3_ba                       ),      // output [2:0]     ddr3_ba
    .ddr3_cas_n                     ( ddr3_cas_n                    ),      // output           ddr3_cas_n
    .ddr3_ck_n                      ( ddr3_ck_n                     ),      // output [0:0]     ddr3_ck_n
    .ddr3_ck_p                      ( ddr3_ck_p                     ),      // output [0:0]     ddr3_ck_p
    .ddr3_cke                       ( ddr3_cke                      ),      // output [0:0]     ddr3_cke
    .ddr3_ras_n                     ( ddr3_ras_n                    ),      // output           ddr3_ras_n
    .ddr3_reset_n                   ( ddr3_reset_n                  ),      // output           ddr3_reset_n
    .ddr3_we_n                      ( ddr3_we_n                     ),      // output           ddr3_we_n
    .ddr3_dq                        ( ddr3_dq                       ),      // inout [64:0]     ddr3_dq
    .ddr3_dqs_n                     ( ddr3_dqs_n                    ),      // inout [7:0]      ddr3_dqs_n
    .ddr3_dqs_p                     ( ddr3_dqs_p                    ),      // inout [7:0]      ddr3_dqs_p
    .init_calib_complete            ( init_calib_complete_o         ),      // output           init_calib_complete
         
    .ddr3_cs_n                      ( ddr3_cs_n                     ),      // output [0:0]     ddr3_cs_n
    .ddr3_dm                        ( ddr3_dm                       ),      // output [7:0]     ddr3_dm
    .ddr3_odt                       ( ddr3_odt                      ),      // output [0:0]     ddr3_odt
    // Application interface ports    
    .app_addr                       ( app_addr                      ),      // input [29:0]     app_addr
    .app_cmd                        ( app_cmd                       ),      // input [2:0]      app_cmd
    .app_en                         ( app_en                        ),      // input            app_en
    .app_wdf_data                   ( app_wdf_data                  ),      // input [511:0]    app_wdf_data
    .app_wdf_end                    ( app_wdf_end                   ),      // input            app_wdf_end
    .app_wdf_mask                   ( app_wdf_mask                  ),      // input [64:0]     app_wdf_mask
    .app_wdf_wren                   ( app_wdf_wren                  ),      // input            app_wdf_wren
    .app_rd_data                    ( app_rd_data                   ),      // output [511:0]   app_rd_data
    .app_rd_data_end                ( app_rd_data_end               ),      // output           app_rd_data_end
    .app_rd_data_valid              ( app_rd_data_valid             ),      // output           app_rd_data_valid
    .app_rdy                        ( app_rdy                       ),      // output           app_rdy
    .app_wdf_rdy                    ( app_wdf_rdy                   ),      // output           app_wdf_rdy
    .app_sr_req                     ( app_sr_req                    ),      // input            app_sr_req
    .app_ref_req                    ( app_ref_req                   ),      // input            app_ref_req
    .app_zq_req                     ( app_zq_req                    ),      // input            app_zq_req
    .app_sr_active                  ( app_sr_active                 ),      // output           app_sr_active
    .app_ref_ack                    ( app_ref_ack                   ),      // output           app_ref_ack
    .app_zq_ack                     ( app_zq_ack                    ),      // output           app_zq_ack
    .ui_clk                         ( ui_clk                        ),      // output           ui_clk
    .ui_clk_sync_rst                ( ui_clk_sync_rst               ),      // output           ui_clk_sync_rst
    // System Clock Ports            
    .sys_clk_i                      ( clk_500m_i                    ),      // input            sys_clk_p
    // Reference Clock Ports    
    .clk_ref_i                      ( clk_200m_i                    ),      // input            clk_ref_i
    .device_temp                    (                               ),      // output [11:0]    device_temp
    .sys_rst                        ( ~sys_rst_r[2]                 )       // input            sys_rst        Active Low
);

//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


//////////////////////////////////////////////////////////////////////////////////
// *********** Logic Design
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
assign ddr_log_rst_o = ddr_log_rst;

always @ (posedge ui_clk) begin
    // ddr_rst_r <= {ddr_rst_r[1:0],laser_rst_i};
    ddr_log_rst <= ui_clk_sync_rst;
end

always @(posedge clk_500m_i) begin
    sys_rst_r <= {sys_rst_r[1:0],rst_i};
end
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
endmodule 