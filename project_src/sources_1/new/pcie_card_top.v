`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2022/08/22 10:32:24
// Design Name: 
// Module Name: pcie_card_top
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
// `define TEST_ONLY_PCIE
// `define TEST_COMM
// `define  AURORA_FLASH

module pcie_card_top #(
    parameter PL_LINK_CAP_MAX_LINK_WIDTH          = 8,           // 1- X1; 2 - X2; 4 - X4; 8 - X8
    parameter PL_SIM_FAST_LINK_TRAINING           = "FALSE",     // Simulation Speedup
    parameter PL_LINK_CAP_MAX_LINK_SPEED          = 2,           // 1- GEN1; 2 - GEN2; 4 - GEN3
    parameter C_DATA_WIDTH                        = 128,
    parameter EXT_PIPE_SIM                        = "FALSE",     // This Parameter has effect on selecting Enable External PIPE Interface in GUI.
    parameter C_ROOT_PORT                         = "FALSE",     // PCIe block is in root port mode
    parameter C_DEVICE_NUMBER                     = 0            // Device number for Root Port configurations only
)(
    output [(PL_LINK_CAP_MAX_LINK_WIDTH - 1) : 0] pci_exp_txp,
    output [(PL_LINK_CAP_MAX_LINK_WIDTH - 1) : 0] pci_exp_txn,
    input [(PL_LINK_CAP_MAX_LINK_WIDTH - 1) : 0]  pci_exp_rxp,
    input [(PL_LINK_CAP_MAX_LINK_WIDTH - 1) : 0]  pci_exp_rxn,

    input 				pcie_sys_clk_p,
    input 				pcie_sys_clk_n,
    input 				pcie_rst_n,
	
	input				FPGA_RESET,
	
	input				FPGA_MASTER_CLOCK_P,
	input				FPGA_MASTER_CLOCK_N,
	
	output				VCC12V_FAN_EN,
	input				FAN_FG,
	// DDR3
    inout   [63:0]      ddr3_dq         ,
    inout   [7:0]       ddr3_dqs_n      ,
    inout   [7:0]       ddr3_dqs_p      ,
    output  [15:0]      ddr3_addr       ,
    output  [2:0]       ddr3_ba         ,
    output              ddr3_ras_n      ,
    output              ddr3_cas_n      ,
    output              ddr3_we_n       ,
    output              ddr3_reset_n    ,
    output              ddr3_ck_p       ,
    output              ddr3_ck_n       ,
    output              ddr3_cke        ,
    output              ddr3_cs_n       ,
    output  [7:0]       ddr3_dm         ,
    output  	        ddr3_odt        ,

	// aurora	
	 input  			GTXQ2_0_P,	//100M SFP CLK
     input				GTXQ2_0_N,
	 
     input				RX0P,	//对应SFP1
     input				RX0N,
     output				TX0P,
     output				TX0N,
	 output				FPGA_SFP0_TX_DISABLE,
	 output				FPGA_SFP0_IIC_SCL,
	 
	//  input              GTXQ2_1_P,	//100M SFP CLK
    //  input              GTXQ2_1_N,
	 
     input				RX1P,	//对应SFP2
     input				RX1N,
     output				TX1P,
     output				TX1N,
	 output				FPGA_SFP1_TX_DISABLE,
	 output				FPGA_SFP1_IIC_SCL,

    // flash interface
     inout   [16-1:0]                    FLASH_DATA          ,
     output  [27-1:0]                    FLASH_ADDR          ,
     output                              FLASH_WE_B          ,  // write enable
     output                              FLASH_ADV_B         ,
     output                              FLASH_OE_B          ,  // read enable
     output                              FLASH_CE_B          ,  // chip enable
     input                               FLASH_WAIT          ,

	// Debug
	 output	[3:0]		led 
);

// Local Parameters derived from user selection
localparam integer 	USER_CLK_FREQ		= ((PL_LINK_CAP_MAX_LINK_SPEED == 3'h4) ? 5 : 4);
localparam 			TCQ 				= 1;
localparam 			C_M_AXI_ID_WIDTH 	= 4;
localparam 			C_S_AXI_DATA_WIDTH 	= C_DATA_WIDTH;
localparam 			C_M_AXI_DATA_WIDTH 	= C_DATA_WIDTH;
localparam 			C_S_AXI_ADDR_WIDTH 	= 64;
localparam 			C_M_AXI_ADDR_WIDTH 	= 64;
localparam 			C_NUM_USR_IRQ	 	= 1;
genvar i;

wire 				user_lnk_up;
wire 				user_clk;
wire				user_resetn;

//----------------------------------------------------------------------------------------------------------------//
//    System(SYS) Interface                                                                                       //
//----------------------------------------------------------------------------------------------------------------//

wire               	sys_clk;
wire               	sys_rst_n_c;

wire				FPGA_MASTER_CLOCK;
wire				clk_500M;
wire				clk_200M;
wire				clk_50M;
wire                clk_125M;
wire				pll_locked;
wire                aurora_user_rst_0       ;
wire                aurora_user_rst_1       ;

reg                 core_rst          = 'd1;
reg     [27:0]      core_rst_cnt      = 'd0;

wire               	pcie_clk_250m;
reg                 aurora_reset_0      = 'd1;
reg                 aurora_reset_1      = 'd1;
reg     [15:0]      aurora_reset_cnt_0  = 'd0;
reg     [15:0]      aurora_reset_cnt_1  = 'd0;

(*mark_debug = "true"*)wire				ddr3_init_done;
(*mark_debug = "true"*)wire				CHANNEL_UP_DONE_0;
(*mark_debug = "true"*)wire				CHANNEL_UP_DONE_1;
wire                aurora_log_clk_0            ;   //5G    5G/10*8/4*8=125M时钟
wire                aurora_log_clk_1            ;   //5G    5G/10*8/4*8=125M时钟

wire                eds_rx_start                ;
wire                eds_rx_end                  ;
wire                pcie_eds_rx_end             ;
wire                eds_aurora_rxen             ;
wire    [64-1:0]    eds_aurora_rxdata           ;

wire                fbc_rx_start                ;
wire                fbc_rx_end                  ;
wire                pcie_fbc_rx_end             ;

wire                pmt_rx_start                ;
wire                pmt_rx_end                  ;
wire                pcie_pmt_rx_end             ;
wire                pmt_aurora_rxen             ;
wire    [31:0]      pmt_aurora_rxdata           ;
wire                pmt_encode_rxen             ;
wire    [63:0]      pmt_encode_rxdata           ;

wire                aurora_rxen                 ;
wire    [63:0]      aurora_rxdata               ;

wire    [32-1:0]    aurora_pmt_soft_err         ;
wire    [32-1:0]    aurora_timing_soft_err      ;

wire                xdma_err_reset              ;

wire				gt_refclk1                  ;
wire                gt0_qplllock_i              ;
wire                gt0_qpllrefclklost_i        ;
wire                gt_qpllclk_quad1_i          ; 
wire                gt_qpllrefclk_quad1_i       ; 

// wire                mem_rst             = pmt_rx_start || eds_rx_start || fbc_rx_start;
reg                 temp_ddr_wr_en      = 'd0   ;
reg     [511:0]     temp_ddr_wr_data    = 'd0   ;


wire [C_NUM_USR_IRQ-1:0]			usr_irq_req ;
wire [C_NUM_USR_IRQ-1:0] 			usr_irq_ack;
wire 			 	dn_irq                  ;
wire				dn_irq_ack              ;
wire				up_irq                  ;
wire				up_irq_ack              ;
wire    [31:0]      up_check_irq            ;
wire    [31:0]      up_check_frame          ;
wire    [31:0]      irq_timeout_fault_cnt   ;
wire                debug_register_rst      ;
wire                xdma_vout_state_rst     ;
wire    [31:0]      xdma_idle_time_max      ;
wire    [31:0]      xdma_hold_time_max      ;
wire    [31:0]      pmt_lose_pack_cnt       ;
wire    [31:0]      pmt_lose_pack_mem_cnt   ;
wire    [31:0]      wr_frame_cnt            ;
wire    [31:0]      rd_frame_cnt            ;
wire    [31:0]      err_state_cnt           ;
wire    [31:0]      ddr_last_pack_cnt       ;
wire    [31:0]      ddr_usage_max           ;
//-- AXI Master Write Address Channel
wire [C_M_AXI_ADDR_WIDTH-1:0] 		m_axi_awaddr;
wire [C_M_AXI_ID_WIDTH-1:0] 		m_axi_awid;
wire 	[2:0] 		m_axi_awprot;
wire 	[1:0] 		m_axi_awburst;
wire 	[2:0] 		m_axi_awsize;
wire 	[3:0] 		m_axi_awcache;
wire 	[7:0] 		m_axi_awlen;
wire 			 	m_axi_awlock;
wire 			 	m_axi_awvalid;
wire 			 	m_axi_awready;

//-- AXI Master Write Data Channel
wire [C_M_AXI_DATA_WIDTH-1:0]     	m_axi_wdata;
wire [(C_M_AXI_DATA_WIDTH/8)-1:0] 	m_axi_wstrb;
wire 			 	m_axi_wlast;
wire 			 	m_axi_wvalid;
wire 			 	m_axi_wready;
//-- AXI Master Write Response Channel
wire 				m_axi_bvalid;
wire 				m_axi_bready;
wire [C_M_AXI_ID_WIDTH-1 : 0]     	m_axi_bid;
wire 	[1:0]     	m_axi_bresp;
//-- AXI Master Read Address Channel
wire [C_M_AXI_ID_WIDTH-1 : 0]     	m_axi_arid;
wire [C_M_AXI_ADDR_WIDTH-1:0]     	m_axi_araddr;
wire 	[7:0]    	m_axi_arlen;
wire 	[2:0]    	m_axi_arsize;
wire 	[1:0]    	m_axi_arburst;
wire 	[2:0] 		m_axi_arprot;
wire 				m_axi_arvalid;
wire 				m_axi_arready;
wire 				m_axi_arlock;
wire 	[3:0] 		m_axi_arcache;
//-- AXI Master Read Data Channel
wire [C_M_AXI_ID_WIDTH-1 : 0]   	m_axi_rid;
wire [C_M_AXI_DATA_WIDTH-1:0]   	m_axi_rdata;
wire 	[1:0] 		m_axi_rresp;
wire 			 	m_axi_rvalid;
wire 			 	m_axi_rready;

///////////////////////////////////////////////////////////////////////////////
// CQ forwarding port to BARAM

wire 	[2:0]    	msi_vector_width;
wire          		msi_enable;

//-- AXI Master Write Address Channel
wire 	[31:0] 		m_axil_awaddr;
wire 	[2:0]  		m_axil_awprot;
wire 				m_axil_awvalid;
wire 				m_axil_awready;

//-- AXI Master Write Data Channel
wire 	[31:0] 		m_axil_wdata;
wire 	[3:0]  		m_axil_wstrb;
wire 				m_axil_wvalid;
wire 				m_axil_wready;
//-- AXI Master Write Response Channel
wire 				m_axil_bvalid;
wire 				m_axil_bready;
//-- AXI Master Read Address Channel
wire 	[31:0] 		m_axil_araddr;
wire 	[2:0]  		m_axil_arprot;
wire 				m_axil_arvalid;
wire 				m_axil_arready;
//-- AXI Master Read Data Channel
wire 	[31:0] 		m_axil_rdata;
wire 	[1:0]  		m_axil_rresp;
wire 				m_axil_rvalid;
wire 				m_axil_rready;
wire 	[1:0]  		m_axil_bresp;
   
// AXI ST interface to user3
wire 				fifo_data_L2P_en;
wire 	[127:0] 	fifo_data_L2P;

wire				fifo_data_P2L_en;
wire				fifo_data_P2L_emp;
wire 	[127:0]		fifo_data_P2L;

wire    [16-1:0]    flash_data_i            ;
wire    [16-1:0]    flash_data_o            ;
wire                flash_clk               ;

wire    [32-1:0]    pmt_overflow_cnt        ;
wire    [32-1:0]    encode_overflow_cnt     ;
wire    [32-1:0]    Xencode_skip_cnt        ;
wire    [32-1:0]    eds_aurora_pack_cnt     ;
wire    [32-1:0]    pmt_aurora_pack_cnt     ;
wire    [32-1:0]    fbc_aurora_pack_cnt     ;
wire    [32-1:0]    eds_xdma_pack_cnt       ;
wire    [32-1:0]    pmt_xdma_pack_cnt       ;
wire    [32-1:0]    fbc_xdma_pack_cnt       ;

wire                xdma_vin_mem_clear      ;
wire                xdma_vin_start          ;

reg		[31:0]		led_cnt;
reg					led_flag;

//LED灯低电平点亮  
assign 		led[3] = led_flag     		;	// Multiboot:0.5Hz频率闪烁, Golden:2Hz频率闪烁
assign 		led[2] = ~CHANNEL_UP_DONE_0	;	//pmt link status
assign 		led[1] = ~CHANNEL_UP_DONE_1 ;	//eds link status
assign 		led[0] = ~ddr3_init_done  	;

assign 		VCC12V_FAN_EN = 1'b0;

assign		FPGA_SFP0_TX_DISABLE		=	1'b0; //FPGA_SFP0_MOD_DETECT ? 1'b1 : 1'b0;
assign		FPGA_SFP0_IIC_SCL			=	1'b1;
assign		FPGA_SFP1_TX_DISABLE		=	1'b0; //FPGA_SFP1_MOD_DETECT ? 1'b1 : 1'b0;
assign		FPGA_SFP1_IIC_SCL			=	1'b1;

always @(posedge clk_50M) begin
	if(!pll_locked) begin
		led_flag 		<= 'd1;
		led_cnt 		<= 'd0;
	end
	else if(led_cnt == 'd49999999) begin
		led_cnt 		<= 'd0;
		led_flag 		<= ~led_flag;
	end
	else begin
		led_flag 		<= led_flag;
		led_cnt		 	<= led_cnt + 1'd1;
	end
end

// pcie ref clock buffer
IBUFDS_GTE2 pcie_refclk_ibuf(
    .O          ( sys_clk           ),
    .ODIV2      (                   ),
    .I          ( pcie_sys_clk_p    ),
    .CEB        ( 1'b0              ),
    .IB         ( pcie_sys_clk_n    )
);
// Reset buffer
IBUF  sys_reset_n_ibuf(
    .O          ( sys_rst_n_c       ),
    .I          ( pcie_rst_n        )
);

assign	usr_irq_req		=	up_irq;
// assign	dn_irq_ack 		=	usr_irq_ack[0];
assign	up_irq_ack 		=	usr_irq_ack[0];

IBUFDS #(
    .DIFF_TERM("TRUE"),       // Differential Termination
    .IBUF_LOW_PWR("FALSE"),     // Low power="TRUE", Highest performance="FALSE" 
    .IOSTANDARD("DEFAULT")     // Specify the input I/O standard
 ) IBUFDS_inst (
    .O(FPGA_MASTER_CLOCK),  // Buffer output
    .I(FPGA_MASTER_CLOCK_P),  // Diff_p buffer input (connect directly to top-level port)
    .IB(FPGA_MASTER_CLOCK_N) // Diff_n buffer input (connect directly to top-level port)
 );
	
clk_pll clk_pll_inst(
    // Clock out ports
    .clk_out1	(clk_500M		),    	// output clk_out1
    .clk_out2	(clk_200M		),    	// output clk_out2
    .clk_out3	(clk_50M		),     	// output clk_out3
    .clk_out4   (clk_125M       ),      // output clk_out4
    // Status and control signals
    .reset		(FPGA_RESET		), 		// input reset
    .locked		(pll_locked		),    	// output locked
   // Clock in ports
    .clk_in1	(FPGA_MASTER_CLOCK	)
); 

wire aurora_soft_rst ;
wire aurora_soft_rst_vio ;
wire aurora_soft_rst_sync ;
vio_1 aurora_soft_rst_inst (
  .clk(clk_50M),                // input wire clk
  .probe_out0(aurora_soft_rst_vio)  // output wire [0 : 0] probe_out0
);

xpm_cdc_single #(
    .DEST_SYNC_FF(2),   // DECIMAL; range: 2-10
    .INIT_SYNC_FF(0),   // DECIMAL; 0=disable simulation init values, 1=enable simulation init values
    .SIM_ASSERT_CHK(0), // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
    .SRC_INPUT_REG(1)   // DECIMAL; 0=do not register input, 1=register input
 )
 xpm_cdc_single_aurora_rst_inst (
    .dest_out(aurora_soft_rst_sync), // 1-bit output: src_in synchronized to the destination clock domain. This output is
                         // registered.

    .dest_clk(clk_50M), // 1-bit input: Clock signal for the destination clock domain.
    .src_clk(pcie_clk_250m),   // 1-bit input: optional; required when SRC_INPUT_REG = 1
    .src_in(aurora_soft_rst)      // 1-bit input: Input signal to be synchronized to dest_clk domain.
 );

always @(posedge aurora_log_clk_0) begin
    if(core_rst) begin
        aurora_reset_0        <= 'd1;
        aurora_reset_cnt_0    <= 'd0;
    end
    else if(aurora_reset_cnt_0[8])begin
        aurora_reset_0        <= 'd0;
        aurora_reset_cnt_0    <= aurora_reset_cnt_0;
    end
    else begin
        aurora_reset_0        <= 'd1;
        aurora_reset_cnt_0    <= aurora_reset_cnt_0 + 1;
    end
end

always @(posedge aurora_log_clk_1) begin
    if(core_rst) begin
        aurora_reset_1        <= 'd1;
        aurora_reset_cnt_1    <= 'd0;
    end
    else if(aurora_reset_cnt_1[8])begin
        aurora_reset_1        <= 'd0;
        aurora_reset_cnt_1    <= aurora_reset_cnt_1;
    end
    else begin
        aurora_reset_1        <= 'd1;
        aurora_reset_cnt_1    <= aurora_reset_cnt_1 + 1;
    end
end

always @(posedge clk_50M) begin
	if(!pll_locked || aurora_soft_rst_sync || aurora_soft_rst_vio) begin
		core_rst 		<= 'd1;
		core_rst_cnt 	<= 'd0;
	end
	else if(core_rst_cnt[27]) begin
		core_rst_cnt 	<= core_rst_cnt;
		core_rst 		<= 'd0;
	end
	else begin
		core_rst 		<= 'd1;
		core_rst_cnt 	<= core_rst_cnt + 1'b1;
	end
end

reg clk_125M_rst = 'd0;
always @(posedge clk_125M) begin
    clk_125M_rst <= ~pll_locked;
end


generate
    for(i=0;i<16;i=i+1)begin : FLASH_INFO
        assign flash_data_i[i] = FLASH_DATA[i];
        assign FLASH_DATA[i]   = FLASH_OE_B ? flash_data_o[i] : 1'bz;
    end
endgenerate

STARTUPE2 #(
    .PROG_USR("FALSE"),  // Activate program event security feature. Requires encrypted bitstreams.
    .SIM_CCLK_FREQ(0.0)  // Set the Configuration Clock Frequency(ns) for simulation.
)
STARTUPE2_inst (
    .CFGCLK( ),             // 1-bit output: Configuration main clock output
    .CFGMCLK( ),            // 1-bit output: Configuration internal oscillator clock output
    .EOS( ),                // 1-bit output: Active high output signal indicating the End Of Startup.
    .PREQ( ),               // 1-bit output: PROGRAM request to fabric output
    .CLK(0),                // 1-bit input: User start-up clock input
    .GSR(0),                // 1-bit input: Global Set/Reset input (GSR cannot be used for the port name)
    .GTS(0),                // 1-bit input: Global 3-state input (GTS cannot be used for the port name)
    .KEYCLEARB(1),          // 1-bit input: Clear AES Decrypter Key input from Battery-Backed RAM (BBRAM)
    .PACK(1),               // 1-bit input: PROGRAM acknowledge input
    .USRCCLKO(flash_clk),   // 1-bit input: User CCLK input
                            // For Zynq-7000 devices, this input must be tied to GND
    .USRCCLKTS(0),          // 1-bit input: User CCLK 3-state enable input
                            // For Zynq-7000 devices, this input must be tied to VCC
    .USRDONEO(1),           // 1-bit input: User DONE pin output control
    .USRDONETS(1)           // 1-bit input: User DONE 3-state enable output
);

wire                startup_rst       ;
wire                startup_finish    ;
wire  [16-1:0]      startup_finish_cnt;
wire                startup_pack_vld  ;
wire  [16-1:0]      startup_pack_cnt  ;
reg                 startup_vld       ;
wire  [32-1:0]      startup_data      ;
wire  [2-1:0]       startup_ack       ;
wire  [16-1:0]      startup_last_pack ;

wire                erase_multiboot_pcie    ;
wire                startup_rst_pcie        ;
wire                startup_finish_pcie     ;
wire  [16-1:0]      startup_finish_cnt_pcie ;
wire                startup_pack_vld_pcie   ;
wire  [16-1:0]      startup_pack_cnt_pcie   ;
wire                startup_vld_pcie        ;
wire  [32-1:0]      startup_data_pcie       ;
wire                startup_ack_pcie        ;
wire                startup_finish_ack_pcie ;

wire                handshake_fifo_full     ;
wire                handshake_fifo_empty    ;
wire                handshake_fifo_rd_en    ;

wire                erase_multiboot   ;
wire                erase_ack         ;
wire  [8-1:0]       erase_status_reg  ;
wire                erase_finish      ;
wire                erase_finish_pcie ;

wire                flash_rd_start    ;
wire                flash_rd_valid    ;
wire  [16-1:0]      flash_rd_data     ;

`ifdef TEST_COMM
wire            test_FLASH_WE_B     ; 
wire            test_FLASH_ADV_B    ;
wire            test_FLASH_OE_B     ; 
wire            test_FLASH_CE_B     ; 
wire            test_flash_clk      ;
wire [16-1:0]   test_flash_data_o   ;
wire [27-1:0]   test_FLASH_ADDR     ;

reg [16-1:0] test_flash_data_in = 'd0;
reg test_FLASH_WAIT = 'd0;
always @(posedge aurora_log_clk_0) begin
    if(~test_FLASH_OE_B)begin
        test_FLASH_WAIT <= 'd1;
        test_flash_data_in <= 'h80;
    end
    else begin
        test_FLASH_WAIT <= 'd0;
    end
end

`endif // TEST_COMM
startup_ctrl_v2 #(
    .TCQ                        ( TCQ                       ),
    .DATA_WIDTH                 ( 16                        ),
    .ADDR_WIDTH                 ( 26                        ))
startup_ctrl_inst (
    `ifdef AURORA_FLASH
    .clk_i                      ( aurora_log_clk_0          ), // 125MHz
    .rst_i                      ( aurora_reset_0            ),
    `else
    .clk_i                      ( clk_125M                  ), // 125MHz
    .rst_i                      ( clk_125M_rst              ),
    `endif // AURORA_FLASH

    .startup_rst_i              ( startup_rst               ),
    .startup_finish_i           ( startup_finish            ),
    .startup_finish_cnt_i       ( startup_finish_cnt        ),
    .startup_i                  ( startup_pack_vld          ),
    .startup_pack_i             ( startup_pack_cnt          ),
    .startup_vld_i              ( startup_vld               ),
    .startup_data_i             ( startup_data              ),
    .startup_ack_o              ( startup_ack               ),
    .startup_last_pack_o        ( startup_last_pack         ),

    .erase_multiboot_i          ( erase_multiboot           ),
    .erase_ack_o                ( erase_ack                 ),
    .erase_status_reg_o         ( erase_status_reg          ),
    .erase_finish_o             ( erase_finish              ),

    .flash_rd_start_i           ( flash_rd_start            ),
    .flash_rd_valid_o           ( flash_rd_valid            ),
    .flash_rd_data_o            ( flash_rd_data             ),

    `ifdef TEST_COMM
    .flash_data_i               ( test_flash_data_in        ),
    .flash_data_o               ( test_flash_data_o         ),
    .flash_addr_o               ( test_FLASH_ADDR           ),
    .WAIT                       ( test_FLASH_WAIT           ),
    .WE_B                       ( test_FLASH_WE_B           ),
    .ADV_B                      ( test_FLASH_ADV_B          ),
    .OE_B                       ( test_FLASH_OE_B           ),
    .CE_B                       ( test_FLASH_CE_B           ),
    .CLK                        ( test_flash_clk            )
    `else
    .flash_data_i               ( flash_data_i              ),
    .flash_data_o               ( flash_data_o              ),
    .flash_addr_o               ( FLASH_ADDR                ),
    .WAIT                       ( 1'b1/*FLASH_WAIT*/        ),
    .WE_B                       ( FLASH_WE_B                ),
    .ADV_B                      ( FLASH_ADV_B               ),
    .OE_B                       ( FLASH_OE_B                ),
    .CE_B                       ( FLASH_CE_B                ),
    .CLK                        ( flash_clk                 )
    `endif // TEST_COMM
);

aurora_8b10b_0_exdes  aurora_8b10b_exdes_inst_0(	
    .aurora_log_clk             ( aurora_log_clk_0          ),
    .pmt_aurora_rxen_o          ( pmt_aurora_rxen           ),
    .pmt_aurora_rxdata_o        ( pmt_aurora_rxdata         ),

    .pmt_rx_start_i             ( pmt_rx_start              ),

    .aurora_pmt_soft_err_o      ( aurora_pmt_soft_err       ),
    .RESET                      ( aurora_reset_0            ),
    .CHANNEL_UP_DONE	        ( CHANNEL_UP_DONE_0	        ),
    .INIT_CLK_P			        ( clk_50M			        ),
    .DRP_CLK_IN			        ( clk_50M			        ),
    .GT_RESET_IN		        ( core_rst                  ),

    .refclk1_i                  ( gt_refclk1                ),

    .RXP                        ( RX0P                      ),
    .RXN                        ( RX0N                      ),
    .TXP                        ( TX0P                      ),
    .TXN                        ( TX0N                      )
);	
   
// reg pmt_rx_start_d0 = 'd0;
// reg pmt_rx_start_d1 = 'd0;
// always @(posedge aurora_log_clk_1 ) begin
//     pmt_rx_start_d0 <= pmt_rx_start;
//     pmt_rx_start_d1 <= pmt_rx_start_d0;
// end


aurora_64b66b_0_exdes aurora_64b66b_exdes_inst_1(
    .aurora_log_clk_o           ( aurora_log_clk_1          ),
    
    // aurora clk
    .eds_aurora_rxen_o          ( eds_aurora_rxen           ),
    .eds_aurora_rxdata_o        ( eds_aurora_rxdata         ),
    .encoder_rxen_o             ( pmt_encode_rxen           ),
    .encoder_rxdata_o           ( pmt_encode_rxdata         ),

    // sys_clk
    .eds_rx_start_o             ( eds_rx_start              ),
    .fbc_rx_start_o             ( fbc_rx_start              ),
    .pmt_rx_start_o             ( pmt_rx_start              ),

    .sys_clk_i                  ( aurora_log_clk_0          ),
    .aurora_timing_soft_err_o   ( aurora_timing_soft_err    ),
    .eds_aurora_pack_cnt_o      ( eds_aurora_pack_cnt       ),
    .pmt_aurora_pack_cnt_o      ( pmt_aurora_pack_cnt       ),
    .fbc_aurora_pack_cnt_o      ( fbc_aurora_pack_cnt       ),

    // Reset and clk
    .RESET                      ( aurora_reset_1            ),
    .PMA_INIT                   ( core_rst                  ),
    .INIT_CLK_P                 ( clk_50M                   ),
    .DRP_CLK_IN                 ( clk_50M                   ),

    .CHANNEL_UP                 ( CHANNEL_UP_DONE_1         ),

    // GTX Reference Clock Interface
    .GTXQ0_P                    ( GTXQ2_0_P                 ),
    .GTXQ0_N                    ( GTXQ2_0_N                 ),
    // GT clk from aurora_0_support
    .refclk1_o                  ( gt_refclk1                ),

    // GTX Serial I/O
    .RXP                        ( RX1P                      ),
    .RXN                        ( RX1N                      ),
    .TXP                        ( TX1P                      ),
    .TXN                        ( TX1N                      )
);

aurora_rx_data_process	aurora_rx_data_process_inst(
    .aurora_log_clk_0	        ( aurora_log_clk_0          ),
    .aurora_rst_0		        ( aurora_reset_0            ),
    .pmt_aurora_rxen_i          ( pmt_aurora_rxen           ),
    .pmt_aurora_rxdata_i        ( pmt_aurora_rxdata         ),

    .eds_rx_start_i	            ( eds_rx_start              ),
    .fbc_rx_start_i             ( fbc_rx_start              ),
    .pmt_rx_start_i             ( pmt_rx_start              ),

    .aurora_log_clk_1           ( aurora_log_clk_1          ),
    .aurora_rst_1               ( aurora_reset_1            ),
    .eds_aurora_rxen_i          ( eds_aurora_rxen           ),
    .eds_aurora_rxdata_i        ( eds_aurora_rxdata         ),

    .pmt_overflow_cnt_o         ( pmt_overflow_cnt          ),
    .encode_overflow_cnt_o      ( encode_overflow_cnt       ),
    .Xencode_skip_cnt_o         ( Xencode_skip_cnt          ),
    .eds_xdma_pack_cnt_o        ( eds_xdma_pack_cnt         ),
    .pmt_xdma_pack_cnt_o        ( pmt_xdma_pack_cnt         ),
    .fbc_xdma_pack_cnt_o        ( fbc_xdma_pack_cnt         ),

    .pmt_encode_en_i            ( pmt_encode_rxen           ),
    .pmt_encode_data_i          ( pmt_encode_rxdata         ),
 
    .xdma_vin_mem_clear_o       ( xdma_vin_mem_clear        ),
    .xdma_vin_start_o           ( xdma_vin_start            ),
    .aurora_rxen                ( aurora_rxen               ),
    .aurora_rxdata              ( aurora_rxdata             )

);

reg [2:0] temp_ddr_wr_cnt = 'd0;
always @(posedge aurora_log_clk_0) begin
    if(aurora_reset_0)
        temp_ddr_wr_cnt <= 'd0;
    else if(xdma_vin_mem_clear)
        temp_ddr_wr_cnt <= 'd0;
    else if(aurora_rxen)
        temp_ddr_wr_cnt <= temp_ddr_wr_cnt + 1;
end

always @(posedge aurora_log_clk_0) begin
    if(aurora_reset_0)
        temp_ddr_wr_en <= 'd0;
    else if(xdma_vin_mem_clear)
        temp_ddr_wr_en <= 'd0;
    else if((&temp_ddr_wr_cnt) && aurora_rxen)
        temp_ddr_wr_en <= 'd1;
    else 
        temp_ddr_wr_en <= 'd0;
end

always @(posedge aurora_log_clk_0) begin
    if(aurora_rxen)
        temp_ddr_wr_data <= {aurora_rxdata,temp_ddr_wr_data[511:64]};
end

ddr_top ddr_top_inst(
    // clk & rst
    .clk_500m_i                 ( clk_500M                  ), // ddr System clk input
    .clk_200m_i                 ( clk_200M                  ), // ddr Reference clk input
    .rst_i                      ( !pll_locked               ),
    .sys_clk_i                  ( aurora_log_clk_0          ), // aurora clk , write ddr
    .sys_rst_i                  ( aurora_reset_0            ),
    .xdma_user_clk_i            ( pcie_clk_250m             ), // xdma clk , read ddr
    .xdma_rst_i                 ( ~user_resetn              ),

    // .eds_rx_start_i             ( eds_rx_start              ),
    // .pmt_rx_start_i             ( pmt_rx_start              ),
    // .fbc_rx_start_i             ( fbc_rx_start              ),
    .aurora_wr_start_i          ( xdma_vin_start            ),
    .aurora_wr_en_i             ( temp_ddr_wr_en            ),
    .aurora_wr_data_i           ( temp_ddr_wr_data          ),
    .xdma_err_reset_i           ( xdma_err_reset            ),

    .s_axi_arid_i               ( m_axi_arid                ),
    .s_axi_araddr_i             ( m_axi_araddr              ),
    .s_axi_arlen_i              ( m_axi_arlen               ),
    .s_axi_arsize_i             ( m_axi_arsize              ),
    .s_axi_arburst_i            ( m_axi_arburst             ),
    .s_axi_arvalid_i            ( m_axi_arvalid             ),
    .s_axi_arready_o            ( m_axi_arready             ),
    .s_axi_rid_o                ( m_axi_rid                 ),
    .s_axi_rdata_o              ( m_axi_rdata               ),
    .s_axi_rresp_o              ( m_axi_rresp               ),
    .s_axi_rlast_o              ( m_axi_rlast               ),
    .s_axi_rvalid_o             ( m_axi_rvalid              ),
    .s_axi_rready_i             ( m_axi_rready              ),

    .up_irq_o                   ( up_irq                    ),
    .up_irq_ack_i               ( up_irq_ack                ),
    .up_check_irq_o             ( up_check_irq              ),
    .up_check_frame_o           ( up_check_frame            ),
    .irq_timeout_fault_cnt_o    ( irq_timeout_fault_cnt     ),
    .debug_register_rst_i       ( debug_register_rst        ),
    .xdma_vout_state_rst_i      ( xdma_vout_state_rst       ),
    .xdma_idle_time_max_o       ( xdma_idle_time_max        ),
    .xdma_hold_time_max_o       ( xdma_hold_time_max        ),
    .pmt_lose_pack_cnt_o        ( pmt_lose_pack_cnt         ),
    .pmt_lose_pack_mem_cnt_o    ( pmt_lose_pack_mem_cnt     ),
    .wr_frame_cnt_o             ( wr_frame_cnt              ),
    .rd_frame_cnt_o             ( rd_frame_cnt              ),
    .err_state_cnt_o            ( err_state_cnt             ),
    .ddr_last_pack_cnt_o        ( ddr_last_pack_cnt         ),
    .ddr_usage_max_o            ( ddr_usage_max             ),
    // ddr complete reset
    .init_calib_complete_o      ( ddr3_init_done            ),
    // ddr interface
    .ddr3_dq                    ( ddr3_dq                   ),
    .ddr3_dqs_n                 ( ddr3_dqs_n                ),
    .ddr3_dqs_p                 ( ddr3_dqs_p                ),
    .ddr3_addr                  ( ddr3_addr                 ),
    .ddr3_ba                    ( ddr3_ba                   ),
    .ddr3_ras_n                 ( ddr3_ras_n                ),
    .ddr3_cas_n                 ( ddr3_cas_n                ),
    .ddr3_we_n                  ( ddr3_we_n                 ),
    .ddr3_reset_n               ( ddr3_reset_n              ),
    .ddr3_ck_p                  ( ddr3_ck_p                 ),
    .ddr3_ck_n                  ( ddr3_ck_n                 ),
    .ddr3_cke                   ( ddr3_cke                  ),
    .ddr3_cs_n                  ( ddr3_cs_n                 ),
    .ddr3_dm                    ( ddr3_dm                   ),
    .ddr3_odt                   ( ddr3_odt                  )
);


//---------------------------------------------------------------

// XDMA taget application
xdma_app_ctrl xdma_app_ctrl_inst(
    // AXI Memory Mapped interface, for down
    .s_axi_awid                 ( m_axi_awid                ),
    .s_axi_awaddr               ( m_axi_awaddr              ),
    .s_axi_awlen                ( m_axi_awlen               ),
    .s_axi_awsize               ( m_axi_awsize              ),
    .s_axi_awburst              ( m_axi_awburst             ),
    .s_axi_awvalid              ( m_axi_awvalid             ),
    .s_axi_awready              ( m_axi_awready             ),
    .s_axi_wdata                ( m_axi_wdata               ),
    .s_axi_wstrb                ( m_axi_wstrb               ),
    .s_axi_wlast                ( m_axi_wlast               ),
    .s_axi_wvalid               ( m_axi_wvalid              ),
    .s_axi_wready               ( m_axi_wready              ),
    .s_axi_bid                  ( m_axi_bid                 ),
    .s_axi_bresp                ( m_axi_bresp               ),
    .s_axi_bvalid               ( m_axi_bvalid              ),
    .s_axi_bready               ( m_axi_bready              ),

    // AXI Lite interface, for control
    .s_axil_awaddr	            ( m_axil_awaddr             ),   
    // .m_axil_awprot              ( m_axil_awprot             ),
    .s_axil_awvalid             ( m_axil_awvalid            ),   
    .s_axil_awready             ( m_axil_awready            ),   
    .s_axil_wdata               ( m_axil_wdata              ),   
    .s_axil_wstrb               ( m_axil_wstrb              ),   
    .s_axil_wvalid              ( m_axil_wvalid             ),   
    .s_axil_wready              ( m_axil_wready             ),   
    .s_axil_bvalid              ( m_axil_bvalid             ),   
    .s_axil_bresp               ( m_axil_bresp              ),   
    .s_axil_bready              ( m_axil_bready             ),   
    .s_axil_araddr              ( m_axil_araddr             ),   
    // .m_axil_arprot              ( m_axil_arprot             ),
    .s_axil_arvalid             ( m_axil_arvalid            ),   
    .s_axil_arready             ( m_axil_arready            ),   
    .s_axil_rdata               ( m_axil_rdata              ),   
    .s_axil_rresp               ( m_axil_rresp              ),   
    .s_axil_rvalid              ( m_axil_rvalid             ),   
    .s_axil_rready              ( m_axil_rready             ),  

    // clk & rst
    .user_clk                   ( pcie_clk_250m             ),
    .user_rst_n                 ( user_resetn               ),
    // .sys_rst_n                  ( sys_rst_n_c               ),

    // down channel
    .dn_irq                     ( dn_irq                    ),
    .dn_irq_ack                 ( dn_irq_ack                ),
    .dn_fifo_rd                 ( fifo_data_P2L_en          ),
    .dn_fifo_q                  ( fifo_data_P2L             ),
    .dn_fifo_emp                ( fifo_data_P2L_emp         ),

    // startup
    .erase_multiboot_o          ( erase_multiboot_pcie      ),
    .erase_finish_i             ( erase_finish_pcie         ),
    .startup_rst_o              ( startup_rst_pcie          ),
    .startup_finish_o           ( startup_finish_pcie       ),
    .startup_pack_finish_cnt_o  ( startup_finish_cnt_pcie   ),
    .startup_pack_vld_o         ( startup_pack_vld_pcie     ),
    .startup_pack_cnt_o         ( startup_pack_cnt_pcie     ),
    .startup_vld_o              ( startup_vld_pcie          ),
    .startup_data_o             ( startup_data_pcie         ),
    .read_flash_o               ( flash_rd_start_pcie       ),
    .startup_ack_i              ( startup_ack_pcie          ),
    .startup_finish_ack_i       ( startup_finish_ack_pcie   ),
    
    // check signal
    .up_check_irq_i             ( up_check_irq              ),
    .up_check_frame_i           ( up_check_frame            ),
    .irq_timeout_fault_cnt_i    ( irq_timeout_fault_cnt     ),
    .debug_register_rst_o       ( debug_register_rst        ),
    .xdma_vout_state_rst_o      ( xdma_vout_state_rst       ),
    .xdma_idle_time_max_i       ( xdma_idle_time_max        ),
    .xdma_hold_time_max_i       ( xdma_hold_time_max        ),
    .pmt_lose_pack_cnt_i        ( pmt_lose_pack_cnt         ),
    .pmt_lose_pack_mem_cnt_i    ( pmt_lose_pack_mem_cnt     ),
    .wr_frame_cnt_i             ( wr_frame_cnt              ),
    .rd_frame_cnt_i             ( rd_frame_cnt              ),
    .err_state_cnt_i            ( err_state_cnt             ),
    .CHANNEL_UP_DONE1           ( CHANNEL_UP_DONE_0         ),
    .CHANNEL_UP_DONE2           ( CHANNEL_UP_DONE_1         ),
    .ddr3_init_done             ( ddr3_init_done            ),
    .aurora_pmt_soft_err_i      ( aurora_pmt_soft_err       ),
    .aurora_timing_soft_err_i   ( aurora_timing_soft_err    ),
    .pmt_overflow_cnt_i         ( pmt_overflow_cnt          ),
    .encode_overflow_cnt_i      ( encode_overflow_cnt       ),
    .Xencode_skip_cnt_i         ( Xencode_skip_cnt          ),
    .ddr_last_pack_cnt_i        ( ddr_last_pack_cnt         ),
    .ddr_usage_max_i            ( ddr_usage_max             ),
    .eds_aurora_pack_cnt_i      ( eds_aurora_pack_cnt       ),
    .pmt_aurora_pack_cnt_i      ( pmt_aurora_pack_cnt       ),
    .fbc_aurora_pack_cnt_i      ( fbc_aurora_pack_cnt       ),
    .eds_xdma_pack_cnt_i        ( eds_xdma_pack_cnt         ),
    .pmt_xdma_pack_cnt_i        ( pmt_xdma_pack_cnt         ),
    .fbc_xdma_pack_cnt_i        ( fbc_xdma_pack_cnt         ),
 
    .aurora_soft_rst_o          ( aurora_soft_rst           ),
    .up_err_reset_o             ( xdma_err_reset            )

);


xdma_0 xdma_0_inst(
    //---------------------------------------------------------------------------------------//
    //  PCI Express (pci_exp) Interface                                                      //
    //---------------------------------------------------------------------------------------//
    .sys_clk                    ( sys_clk                   ),
    .sys_rst_n                  ( sys_rst_n_c               ),
    
    // Tx
    .pci_exp_txn                ( pci_exp_txn               ),
    .pci_exp_txp                ( pci_exp_txp               ),

    // Rx
    .pci_exp_rxn     		    ( pci_exp_rxn               ),
    .pci_exp_rxp     		    ( pci_exp_rxp               ),

     // AXI MM Interface
    .m_axi_awid                 ( m_axi_awid                ),
    .m_axi_awaddr               ( m_axi_awaddr              ),
    .m_axi_awlen                ( m_axi_awlen               ),
    .m_axi_awsize               ( m_axi_awsize              ),
    .m_axi_awburst              ( m_axi_awburst             ),
    .m_axi_awprot               ( m_axi_awprot              ),
    .m_axi_awvalid              ( m_axi_awvalid             ),
    .m_axi_awready              ( m_axi_awready             ),
    .m_axi_awlock               ( m_axi_awlock              ),
    .m_axi_awcache              ( m_axi_awcache             ),
    .m_axi_wdata                ( m_axi_wdata               ),
    .m_axi_wstrb                ( m_axi_wstrb               ),
    .m_axi_wlast                ( m_axi_wlast               ),
    .m_axi_wvalid               ( m_axi_wvalid              ),
    .m_axi_wready               ( m_axi_wready              ),
    .m_axi_bid                  ( m_axi_bid                 ),
    .m_axi_bresp                ( m_axi_bresp               ),
    .m_axi_bvalid               ( m_axi_bvalid              ),
    .m_axi_bready               ( m_axi_bready              ),
    .m_axi_arid                 ( m_axi_arid                ),
    .m_axi_araddr               ( m_axi_araddr              ),
    .m_axi_arlen                ( m_axi_arlen               ),
    .m_axi_arsize               ( m_axi_arsize              ),
    .m_axi_arburst              ( m_axi_arburst             ),
    .m_axi_arprot               ( m_axi_arprot              ),
    .m_axi_arvalid              ( m_axi_arvalid             ),
    .m_axi_arready              ( m_axi_arready             ),
    .m_axi_arlock               ( m_axi_arlock              ),
    .m_axi_arcache              ( m_axi_arcache             ),
    .m_axi_rid                  ( m_axi_rid                 ),
    .m_axi_rdata                ( m_axi_rdata               ),
    .m_axi_rresp                ( m_axi_rresp               ),
    .m_axi_rlast                ( m_axi_rlast               ),
    .m_axi_rvalid               ( m_axi_rvalid              ),
    .m_axi_rready               ( m_axi_rready              ),
     // CQ Bypass ports
       
    .m_axil_awaddr              ( m_axil_awaddr             ),  // output wire [31 : 0] m_axil_awaddr
    .m_axil_awprot              ( m_axil_awprot             ),  // output wire [2 : 0] m_axil_awprot
    .m_axil_awvalid             ( m_axil_awvalid            ),  // output wire m_axil_awvalid
    .m_axil_awready             ( m_axil_awready            ),  // input wire m_axil_awready
    .m_axil_wdata               ( m_axil_wdata              ),  // output wire [31 : 0] m_axil_wdata
    .m_axil_wstrb               ( m_axil_wstrb              ),  // output wire [3 : 0] m_axil_wstrb
    .m_axil_wvalid              ( m_axil_wvalid             ),  // output wire m_axil_wvalid
    .m_axil_wready              ( m_axil_wready             ),  // input wire m_axil_wready
    .m_axil_bvalid              ( m_axil_bvalid             ),  // input wire m_axil_bvalid
    .m_axil_bresp               ( m_axil_bresp              ),  // input wire [1 : 0] m_axil_bresp
    .m_axil_bready              ( m_axil_bready             ),  // output wire m_axil_bready
    .m_axil_araddr              ( m_axil_araddr             ),  // output wire [31 : 0] m_axil_araddr
    .m_axil_arprot              ( m_axil_arprot             ),  // output wire [2 : 0] m_axil_arprot
    .m_axil_arvalid             ( m_axil_arvalid            ),  // output wire m_axil_arvalid
    .m_axil_arready             ( m_axil_arready            ),  // input wire m_axil_arready
    .m_axil_rdata               ( m_axil_rdata              ),  // input wire [31 : 0] m_axil_rdata
    .m_axil_rresp               ( m_axil_rresp              ),  // input wire [1 : 0] m_axil_rresp
    .m_axil_rvalid              ( m_axil_rvalid             ),  // input wire m_axil_rvalid
    .m_axil_rready              ( m_axil_rready             ),  

    .usr_irq_req                ( usr_irq_req               ),  
    .usr_irq_ack                ( usr_irq_ack               ),  
    .msi_enable                 ( msi_enable                ),  // no use
    .msi_vector_width           ( msi_vector_width          ),  // no use

    // Config managemnet interface
    // .cfg_mgmt_addr              ( 19'b0                     ),
    // .cfg_mgmt_write             ( 1'b0                      ),
    // .cfg_mgmt_write_data        ( 32'b0                     ),
    // .cfg_mgmt_byte_enable       ( 4'b0                      ),
    // .cfg_mgmt_read              ( 1'b0                      ),
    // .cfg_mgmt_read_data         (                           ),
    // .cfg_mgmt_read_write_done   (                           ),
    // .cfg_mgmt_type1_cfg_reg_access(1'b0                     ),

    //-- AXI Global
    .axi_aclk                   ( pcie_clk_250m             ),
    .axi_aresetn                ( user_resetn               ),
    .user_lnk_up                ( user_lnk_up               )

);


pc_rx_data_process  pc_rx_data_process_inst(
    .pcie_clk_250m              (pcie_clk_250m              ),
    .rst                        (~user_resetn               ),
    .fifo_data_P2L_en           (fifo_data_P2L_en           ),
    .fifo_data_P2L              (fifo_data_P2L              ),
    .fifo_data_P2L_emp          (fifo_data_P2L_emp          )
);


handshake_fifo handshake_fifo_inst (
    .rst                        ( ~user_resetn              ),  // input wire rst
    .wr_clk                     ( pcie_clk_250m             ),  // input wire wr_clk
    .rd_clk                     ( clk_125M                  ),  // input wire rd_clk
    .din                        ( startup_data_pcie         ),  // input wire [127 : 0] din
    .wr_en                      ( startup_vld_pcie          ),  // input wire wr_en
    .rd_en                      ( handshake_fifo_rd_en      ),  // input wire rd_en
    .dout                       ( startup_data              ),  // output wire [127 : 0] dout
    .full                       ( handshake_fifo_full       ),  // output wire full
    .empty                      ( handshake_fifo_empty      )   // output wire empty
);

assign handshake_fifo_rd_en = (~handshake_fifo_empty);

always @(posedge clk_125M) begin
    startup_vld <= handshake_fifo_rd_en;
end

// handshake #(
//     .DATA_WIDTH                 ( 32                        )
// )handshake_startup_data_inst(
//     // clk & rst
//     .src_clk_i                  ( pcie_clk_250m             ),
//     .src_rst_i                  ( ~user_resetn              ),
//     .dest_clk_i                 ( clk_125M                  ),
//     .dest_rst_i                 ( clk_125M_rst              ),
    
//     .src_data_i                 ( startup_data_pcie         ),
//     .src_vld_i                  ( startup_vld_pcie          ),
//     .dest_data_o                ( startup_data              ),
//     .dest_vld_o                 ( startup_vld               )
// );

handshake #(
    .DATA_WIDTH                 ( 16                        )
)handshake_startup_pack_cnt_inst(
    // clk & rst
    .src_clk_i                  ( pcie_clk_250m             ),
    .src_rst_i                  ( ~user_resetn              ),
    .dest_clk_i                 ( clk_125M                  ),
    .dest_rst_i                 ( clk_125M_rst              ),
    
    .src_data_i                 ( startup_pack_cnt_pcie     ),
    .src_vld_i                  ( startup_pack_vld_pcie     ),
    .dest_data_o                ( startup_pack_cnt          ),
    .dest_vld_o                 ( startup_pack_vld          )
);

handshake #(
    .DATA_WIDTH                 ( 16                        )
)handshake_startup_finish_cnt_inst(
    // clk & rst
    .src_clk_i                  ( pcie_clk_250m             ),
    .src_rst_i                  ( ~user_resetn              ),
    .dest_clk_i                 ( clk_125M                  ),
    .dest_rst_i                 ( clk_125M_rst              ),
    
    .src_data_i                 ( startup_finish_cnt_pcie   ),
    .src_vld_i                  ( startup_finish_pcie       ),
    .dest_data_o                ( startup_finish_cnt        ),
    .dest_vld_o                 ( startup_finish            )
);

xpm_cdc_single #(
    .DEST_SYNC_FF(2),   // DECIMAL; range: 2-10
    .INIT_SYNC_FF(0),   // DECIMAL; 0=disable simulation init values, 1=enable simulation init values
    .SIM_ASSERT_CHK(0), // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
    .SRC_INPUT_REG(0)   // DECIMAL; 0=do not register input, 1=register input
 )
 xpm_cdc_single_inst (
    .dest_out(erase_finish_pcie), // 1-bit output: src_in synchronized to the destination clock domain. This output is
                         // registered.

    .dest_clk(pcie_clk_250m), // 1-bit input: Clock signal for the destination clock domain.
    .src_clk(clk_125M),   // 1-bit input: optional; required when SRC_INPUT_REG = 1
    .src_in(erase_finish)      // 1-bit input: Input signal to be synchronized to dest_clk domain.
 );

xpm_cdc_single #(
    .DEST_SYNC_FF(2),   // DECIMAL; range: 2-10
    .INIT_SYNC_FF(0),   // DECIMAL; 0=disable simulation init values, 1=enable simulation init values
    .SIM_ASSERT_CHK(0), // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
    .SRC_INPUT_REG(0)   // DECIMAL; 0=do not register input, 1=register input
 )
 xpm_startup_finish_ack_inst (
    .dest_out(startup_finish_ack_pcie), // 1-bit output: src_in synchronized to the destination clock domain. This output is
                         // registered.

    .dest_clk(pcie_clk_250m), // 1-bit input: Clock signal for the destination clock domain.
    .src_clk(clk_125M),   // 1-bit input: optional; required when SRC_INPUT_REG = 1
    .src_in(startup_ack[1])      // 1-bit input: Input signal to be synchronized to dest_clk domain.
 );

 xpm_cdc_single #(
    .DEST_SYNC_FF(2),   // DECIMAL; range: 2-10
    .INIT_SYNC_FF(0),   // DECIMAL; 0=disable simulation init values, 1=enable simulation init values
    .SIM_ASSERT_CHK(0), // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
    .SRC_INPUT_REG(0)   // DECIMAL; 0=do not register input, 1=register input
 )
 xpm_startup_ack_inst (
    .dest_out(startup_ack_pcie), // 1-bit output: src_in synchronized to the destination clock domain. This output is
                         // registered.

    .dest_clk(pcie_clk_250m), // 1-bit input: Clock signal for the destination clock domain.
    .src_clk(clk_125M),   // 1-bit input: optional; required when SRC_INPUT_REG = 1
    .src_in(startup_ack[0])      // 1-bit input: Input signal to be synchronized to dest_clk domain.
 );

xpm_cdc_pulse #(
    .DEST_SYNC_FF(2),   // DECIMAL; range: 2-10
    .INIT_SYNC_FF(0),   // DECIMAL; 0=disable simulation init values, 1=enable simulation init values
    .REG_OUTPUT(0),     // DECIMAL; 0=disable registered output, 1=enable registered output
    .RST_USED(0),       // DECIMAL; 0=no reset, 1=implement reset
    .SIM_ASSERT_CHK(0)  // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
 )
 erase_multiboot_pulse_inst (
    .dest_pulse(erase_multiboot), // 1-bit output: Outputs a pulse the size of one dest_clk period when a pulse
                             // transfer is correctly initiated on src_pulse input. This output is
                             // combinatorial unless REG_OUTPUT is set to 1.

    .dest_clk(clk_125M),     // 1-bit input: Destination clock.
    .dest_rst(clk_125M_rst),     // 1-bit input: optional; required when RST_USED = 1
    .src_clk(pcie_clk_250m),       // 1-bit input: Source clock.
    .src_pulse(erase_multiboot_pcie),   // 1-bit input: Rising edge of this signal initiates a pulse transfer to the
                             // destination clock domain. The minimum gap between each pulse transfer must be
                             // at the minimum 2*(larger(src_clk period, dest_clk period)). This is measured
                             // between the falling edge of a src_pulse to the rising edge of the next
                             // src_pulse. This minimum gap will guarantee that each rising edge of src_pulse
                             // will generate a pulse the size of one dest_clk period in the destination
                             // clock domain. When RST_USED = 1, pulse transfers will not be guaranteed while
                             // src_rst and/or dest_rst are asserted.

    .src_rst(~user_resetn)        // 1-bit input: optional; required when RST_USED = 1
 );

 xpm_cdc_pulse #(
    .DEST_SYNC_FF(2),   // DECIMAL; range: 2-10
    .INIT_SYNC_FF(0),   // DECIMAL; 0=disable simulation init values, 1=enable simulation init values
    .REG_OUTPUT(0),     // DECIMAL; 0=disable registered output, 1=enable registered output
    .RST_USED(0),       // DECIMAL; 0=no reset, 1=implement reset
    .SIM_ASSERT_CHK(0)  // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
 )
 startup_rst_pulse_inst (
    .dest_pulse(startup_rst), // 1-bit output: Outputs a pulse the size of one dest_clk period when a pulse
                             // transfer is correctly initiated on src_pulse input. This output is
                             // combinatorial unless REG_OUTPUT is set to 1.

    .dest_clk(clk_125M),     // 1-bit input: Destination clock.
    .dest_rst(clk_125M_rst),     // 1-bit input: optional; required when RST_USED = 1
    .src_clk(pcie_clk_250m),       // 1-bit input: Source clock.
    .src_pulse(startup_rst_pcie),   // 1-bit input: Rising edge of this signal initiates a pulse transfer to the
                             // destination clock domain. The minimum gap between each pulse transfer must be
                             // at the minimum 2*(larger(src_clk period, dest_clk period)). This is measured
                             // between the falling edge of a src_pulse to the rising edge of the next
                             // src_pulse. This minimum gap will guarantee that each rising edge of src_pulse
                             // will generate a pulse the size of one dest_clk period in the destination
                             // clock domain. When RST_USED = 1, pulse transfers will not be guaranteed while
                             // src_rst and/or dest_rst are asserted.

    .src_rst(~user_resetn)        // 1-bit input: optional; required when RST_USED = 1
 );

 xpm_cdc_pulse #(
    .DEST_SYNC_FF(2),   // DECIMAL; range: 2-10
    .INIT_SYNC_FF(0),   // DECIMAL; 0=disable simulation init values, 1=enable simulation init values
    .REG_OUTPUT(0),     // DECIMAL; 0=disable registered output, 1=enable registered output
    .RST_USED(0),       // DECIMAL; 0=no reset, 1=implement reset
    .SIM_ASSERT_CHK(0)  // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
 )
 flash_rd_start_pulse_inst (
    .dest_pulse(flash_rd_start), // 1-bit output: Outputs a pulse the size of one dest_clk period when a pulse
                             // transfer is correctly initiated on src_pulse input. This output is
                             // combinatorial unless REG_OUTPUT is set to 1.

    .dest_clk(clk_125M),     // 1-bit input: Destination clock.
    .dest_rst(clk_125M_rst),     // 1-bit input: optional; required when RST_USED = 1
    .src_clk(pcie_clk_250m),       // 1-bit input: Source clock.
    .src_pulse(flash_rd_start_pcie),   // 1-bit input: Rising edge of this signal initiates a pulse transfer to the
                             // destination clock domain. The minimum gap between each pulse transfer must be
                             // at the minimum 2*(larger(src_clk period, dest_clk period)). This is measured
                             // between the falling edge of a src_pulse to the rising edge of the next
                             // src_pulse. This minimum gap will guarantee that each rising edge of src_pulse
                             // will generate a pulse the size of one dest_clk period in the destination
                             // clock domain. When RST_USED = 1, pulse transfers will not be guaranteed while
                             // src_rst and/or dest_rst are asserted.

    .src_rst(~user_resetn)        // 1-bit input: optional; required when RST_USED = 1
 );

endmodule
