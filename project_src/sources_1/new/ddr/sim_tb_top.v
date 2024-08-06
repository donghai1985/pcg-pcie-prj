//*****************************************************************************

// (c) Copyright 2009 - 2010 Xilinx, Inc. All rights reserved.

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

//*****************************************************************************

//   ____  ____

//  /   /\/   /

// /___/  \  /    Vendor             : Xilinx

// \   \   \/     Version            : 4.2

//  \   \         Application        : MIG

//  /   /         Filename           : sim_tb_top.v

// /___/   /\     Date Last Modified : $Date: 2011/06/07 13:45:16 $

// \   \  /  \    Date Created       : Tue Sept 21 2010

//  \___\/\___\

//

// Device           : 7 Series

// Design Name      : DDR3 SDRAM

// Purpose          :

//                   Top-level testbench for testing DDR3.

//                   Instantiates:

//                     1. IP_TOP (top-level representing FPGA, contains core,

//                        clocking, built-in testbench/memory checker and other

//                        support structures)

//                     2. DDR3 Memory

//                     3. Miscellaneous clock generation and reset logic

//                     4. For ECC ON case inserts error on LSB bit

//                        of data from DRAM to FPGA.

// Reference        :

// Revision History :

//*****************************************************************************



`timescale 1ps/100fs



module sim_tb_top;





   //***************************************************************************

   // Traffic Gen related parameters

   //***************************************************************************

   parameter SIMULATION            = "TRUE";

   parameter PORT_MODE             = "BI_MODE";

   parameter DATA_MODE             = 4'b0010;

   parameter TST_MEM_INSTR_MODE    = "R_W_INSTR_MODE";

   parameter EYE_TEST              = "FALSE";

                                     // set EYE_TEST = "TRUE" to probe memory

                                     // signals. Traffic Generator will only

                                     // write to one single location and no

                                     // read transactions will be generated.

   parameter DATA_PATTERN          = "DGEN_ALL";

                                      // For small devices, choose one only.

                                      // For large device, choose "DGEN_ALL"

                                      // "DGEN_HAMMER", "DGEN_WALKING1",

                                      // "DGEN_WALKING0","DGEN_ADDR","

                                      // "DGEN_NEIGHBOR","DGEN_PRBS","DGEN_ALL"

   parameter CMD_PATTERN           = "CGEN_ALL";

                                      // "CGEN_PRBS","CGEN_FIXED","CGEN_BRAM",

                                      // "CGEN_SEQUENTIAL", "CGEN_ALL"

   parameter BEGIN_ADDRESS         = 32'h00000000;

   parameter END_ADDRESS           = 32'h00000fff;

   parameter PRBS_EADDR_MASK_POS   = 32'hff000000;



   //***************************************************************************

   // The following parameters refer to width of various ports

   //***************************************************************************

   parameter COL_WIDTH             = 10;

                                     // # of memory Column Address bits.

   parameter CS_WIDTH              = 1;

                                     // # of unique CS outputs to memory.

   parameter DM_WIDTH              = 8;

                                     // # of DM (data mask)

   parameter DQ_WIDTH              = 64;

                                     // # of DQ (data)

   parameter DQS_WIDTH             = 8;

   parameter DQS_CNT_WIDTH         = 3;

                                     // = ceil(log2(DQS_WIDTH))

   parameter DRAM_WIDTH            = 8;

                                     // # of DQ per DQS

   parameter ECC                   = "OFF";

   parameter RANKS                 = 1;

                                     // # of Ranks.

   parameter ODT_WIDTH             = 1;

                                     // # of ODT outputs to memory.

   parameter ROW_WIDTH             = 14;

                                     // # of memory Row Address bits.

   parameter ADDR_WIDTH            = 28;

                                     // # = RANK_WIDTH + BANK_WIDTH

                                     //     + ROW_WIDTH + COL_WIDTH;

                                     // Chip Select is always tied to low for

                                     // single rank devices

   //***************************************************************************

   // The following parameters are mode register settings

   //***************************************************************************

   parameter BURST_MODE            = "8";

                                     // DDR3 SDRAM:

                                     // Burst Length (Mode Register 0).

                                     // # = "8", "4", "OTF".

                                     // DDR2 SDRAM:

                                     // Burst Length (Mode Register).

                                     // # = "8", "4".

   parameter CA_MIRROR             = "OFF";

                                     // C/A mirror opt for DDR3 dual rank

   

   //***************************************************************************

   // The following parameters are multiplier and divisor factors for PLLE2.

   // Based on the selected design frequency these parameters vary.

   //***************************************************************************

   parameter CLKIN_PERIOD          = 2000;

                                     // Input Clock Period





   //***************************************************************************

   // Simulation parameters

   //***************************************************************************

   parameter SIM_BYPASS_INIT_CAL   = "FAST";

                                     // # = "SIM_INIT_CAL_FULL" -  Complete

                                     //              memory init &

                                     //              calibration sequence

                                     // # = "SKIP" - Not supported

                                     // # = "FAST" - Complete memory init & use

                                     //              abbreviated calib sequence



   //***************************************************************************

   // IODELAY and PHY related parameters

   //***************************************************************************

   parameter TCQ                   = 100;

   //***************************************************************************

   // IODELAY and PHY related parameters

   //***************************************************************************

   parameter RST_ACT_LOW           = 1;

                                     // =1 for active low reset,

                                     // =0 for active high.



   //***************************************************************************

   // Referece clock frequency parameters

   //***************************************************************************

   parameter REFCLK_FREQ           = 200.0;

                                     // IODELAYCTRL reference clock frequency

   //***************************************************************************

   // System clock frequency parameters

   //***************************************************************************

   parameter tCK                   = 2000;

                                     // memory tCK paramter.

                     // # = Clock Period in pS.

   parameter nCK_PER_CLK           = 4;

                                     // # of memory CKs per fabric CLK



   



   //***************************************************************************

   // Debug and Internal parameters

   //***************************************************************************

   parameter DEBUG_PORT            = "OFF";

                                     // # = "ON" Enable debug signals/controls.

                                     //   = "OFF" Disable debug signals/controls.

   //***************************************************************************

   // Debug and Internal parameters

   //***************************************************************************

   parameter DRAM_TYPE             = "DDR3";



    



  //**************************************************************************//

  // Local parameters Declarations

  //**************************************************************************//



  localparam real TPROP_DQS          = 0.00;

                                       // Delay for DQS signal during Write Operation

  localparam real TPROP_DQS_RD       = 0.00;

                       // Delay for DQS signal during Read Operation

  localparam real TPROP_PCB_CTRL     = 0.00;

                       // Delay for Address and Ctrl signals

  localparam real TPROP_PCB_DATA     = 0.00;

                       // Delay for data signal during Write operation

  localparam real TPROP_PCB_DATA_RD  = 0.00;

                       // Delay for data signal during Read operation



  localparam MEMORY_WIDTH            = 16;

  localparam NUM_COMP                = DQ_WIDTH/MEMORY_WIDTH;

  localparam ECC_TEST 		   	= "OFF" ;

  localparam ERR_INSERT = (ECC_TEST == "ON") ? "OFF" : ECC ;

  



  localparam real REFCLK_PERIOD = (1000000.0/(2*REFCLK_FREQ));

  localparam RESET_PERIOD = 200000; //in pSec  

  localparam real SYSCLK_PERIOD = tCK;

    

    



  //**************************************************************************//

  // Wire Declarations

  //**************************************************************************//

  reg                                sys_rst_n;

  wire                               sys_rst;





  reg                     sys_clk_i;



  reg clk_ref_i;



  

  wire                               ddr3_reset_n;

  wire [DQ_WIDTH-1:0]                ddr3_dq_fpga;

  wire [DQS_WIDTH-1:0]               ddr3_dqs_p_fpga;

  wire [DQS_WIDTH-1:0]               ddr3_dqs_n_fpga;

  wire [ROW_WIDTH-1:0]               ddr3_addr_fpga;

  wire [3-1:0]              ddr3_ba_fpga;

  wire                               ddr3_ras_n_fpga;

  wire                               ddr3_cas_n_fpga;

  wire                               ddr3_we_n_fpga;

  wire [1-1:0]               ddr3_cke_fpga;

  wire [1-1:0]                ddr3_ck_p_fpga;

  wire [1-1:0]                ddr3_ck_n_fpga;

    

  

  wire                               init_calib_complete;

  wire                               tg_compare_error;

  wire [(CS_WIDTH*1)-1:0] ddr3_cs_n_fpga;

    

  wire [DM_WIDTH-1:0]                ddr3_dm_fpga;

    

  wire [ODT_WIDTH-1:0]               ddr3_odt_fpga;

    

  

  reg [(CS_WIDTH*1)-1:0] ddr3_cs_n_sdram_tmp;

    

  reg [DM_WIDTH-1:0]                 ddr3_dm_sdram_tmp;

    

  reg [ODT_WIDTH-1:0]                ddr3_odt_sdram_tmp;

    



  

  wire [DQ_WIDTH-1:0]                ddr3_dq_sdram;

  reg [ROW_WIDTH-1:0]                ddr3_addr_sdram [0:1];

  reg [3-1:0]               ddr3_ba_sdram [0:1];

  reg                                ddr3_ras_n_sdram;

  reg                                ddr3_cas_n_sdram;

  reg                                ddr3_we_n_sdram;

  wire [(CS_WIDTH*1)-1:0] ddr3_cs_n_sdram;

  wire [ODT_WIDTH-1:0]               ddr3_odt_sdram;

  reg [1-1:0]                ddr3_cke_sdram;

  wire [DM_WIDTH-1:0]                ddr3_dm_sdram;

  wire [DQS_WIDTH-1:0]               ddr3_dqs_p_sdram;

  wire [DQS_WIDTH-1:0]               ddr3_dqs_n_sdram;

  reg [1-1:0]                 ddr3_ck_p_sdram;

  reg [1-1:0]                 ddr3_ck_n_sdram;

  

    



//**************************************************************************//



  //**************************************************************************//

  // Reset Generation

  //**************************************************************************//

  initial begin

    sys_rst_n = 1'b0;

    #RESET_PERIOD

      sys_rst_n = 1'b1;

   end



   assign sys_rst = RST_ACT_LOW ? sys_rst_n : ~sys_rst_n;



  //**************************************************************************//

  // Clock Generation

  //**************************************************************************//



  initial

    sys_clk_i = 1'b0;

  always

    sys_clk_i = #(CLKIN_PERIOD/2.0) ~sys_clk_i;





  initial

    clk_ref_i = 1'b0;

  always

    clk_ref_i = #REFCLK_PERIOD ~clk_ref_i;









  always @( * ) begin

    ddr3_ck_p_sdram      <=  #(TPROP_PCB_CTRL) ddr3_ck_p_fpga;

    ddr3_ck_n_sdram      <=  #(TPROP_PCB_CTRL) ddr3_ck_n_fpga;

    ddr3_addr_sdram[0]   <=  #(TPROP_PCB_CTRL) ddr3_addr_fpga;

    ddr3_addr_sdram[1]   <=  #(TPROP_PCB_CTRL) ddr3_addr_fpga;

    ddr3_ba_sdram[0]     <=  #(TPROP_PCB_CTRL) ddr3_ba_fpga;

    ddr3_ba_sdram[1]     <=  #(TPROP_PCB_CTRL) ddr3_ba_fpga;

    ddr3_ras_n_sdram     <=  #(TPROP_PCB_CTRL) ddr3_ras_n_fpga;

    ddr3_cas_n_sdram     <=  #(TPROP_PCB_CTRL) ddr3_cas_n_fpga;

    ddr3_we_n_sdram      <=  #(TPROP_PCB_CTRL) ddr3_we_n_fpga;

    ddr3_cke_sdram       <=  #(TPROP_PCB_CTRL) ddr3_cke_fpga;

  end

    



  always @( * )

    ddr3_cs_n_sdram_tmp   <=  #(TPROP_PCB_CTRL) ddr3_cs_n_fpga;

  assign ddr3_cs_n_sdram =  ddr3_cs_n_sdram_tmp;

    



  always @( * )

    ddr3_dm_sdram_tmp <=  #(TPROP_PCB_DATA) ddr3_dm_fpga;//DM signal generation

  assign ddr3_dm_sdram = ddr3_dm_sdram_tmp;

    



  always @( * )

    ddr3_odt_sdram_tmp  <=  #(TPROP_PCB_CTRL) ddr3_odt_fpga;

  assign ddr3_odt_sdram =  ddr3_odt_sdram_tmp;

    



// Controlling the bi-directional BUS



  genvar dqwd;

  generate

    for (dqwd = 1;dqwd < DQ_WIDTH;dqwd = dqwd+1) begin : dq_delay

      WireDelay #

       (

        .Delay_g    (TPROP_PCB_DATA),

        .Delay_rd   (TPROP_PCB_DATA_RD),

        .ERR_INSERT ("OFF")

       )

      u_delay_dq

       (

        .A             (ddr3_dq_fpga[dqwd]),

        .B             (ddr3_dq_sdram[dqwd]),

        .reset         (sys_rst_n),

        .phy_init_done (init_calib_complete)

       );

    end

          WireDelay #

       (

        .Delay_g    (TPROP_PCB_DATA),

        .Delay_rd   (TPROP_PCB_DATA_RD),

        .ERR_INSERT ("OFF")

       )

      u_delay_dq_0

       (

        .A             (ddr3_dq_fpga[0]),

        .B             (ddr3_dq_sdram[0]),

        .reset         (sys_rst_n),

        .phy_init_done (init_calib_complete)

       );

  endgenerate



  genvar dqswd;

  generate

    for (dqswd = 0;dqswd < DQS_WIDTH;dqswd = dqswd+1) begin : dqs_delay

      WireDelay #

       (

        .Delay_g    (TPROP_DQS),

        .Delay_rd   (TPROP_DQS_RD),

        .ERR_INSERT ("OFF")

       )

      u_delay_dqs_p

       (

        .A             (ddr3_dqs_p_fpga[dqswd]),

        .B             (ddr3_dqs_p_sdram[dqswd]),

        .reset         (sys_rst_n),

        .phy_init_done (init_calib_complete)

       );



      WireDelay #

       (

        .Delay_g    (TPROP_DQS),

        .Delay_rd   (TPROP_DQS_RD),

        .ERR_INSERT ("OFF")

       )

      u_delay_dqs_n

       (

        .A             (ddr3_dqs_n_fpga[dqswd]),

        .B             (ddr3_dqs_n_sdram[dqswd]),

        .reset         (sys_rst_n),

        .phy_init_done (init_calib_complete)

       );

    end

  endgenerate

    



    



  //===========================================================================

  //                         FPGA Memory Controller

  //===========================================================================
  reg     [4-1:0]     m_axi_arid          = 'd0;
  reg     [64-1:0]    m_axi_araddr        = 'd0;
  reg     [7:0]       m_axi_arlen         = 'hff;
  reg     [2:0]       m_axi_arsize        = 'd0;
  reg     [1:0]       m_axi_arburst       = 'd0;
  reg                 m_axi_arvalid       = 'd0;
  reg                 m_axi_rready        = 'd0;

  
  // clock generate
reg aurora_log_clk_0 = 0;
reg aurora_log_clk_1 = 0;
reg pcie_clk_250m = 0;

initial
begin
    forever #(8000/2)  aurora_log_clk_0 = ~aurora_log_clk_0;
end

initial
begin
    forever #(3200)  aurora_log_clk_1 = ~aurora_log_clk_1;
end

initial
begin
    forever #(4000/2)  pcie_clk_250m=~pcie_clk_250m;
end

// reset generate
reg aurora_reset_0 = 'd0;
always @(posedge aurora_log_clk_0) begin
    if(init_calib_complete)
        aurora_reset_0 <= 'd0;
    else 
        aurora_reset_0 <= 'd1;
end

reg aurora_reset_1 = 'd0;
always @(posedge aurora_log_clk_1) begin
    if(init_calib_complete)
        aurora_reset_1 <= 'd0;
    else 
        aurora_reset_1 <= 'd1;
end

reg [2:0] xdma_rst = 'd0;
always @(posedge pcie_clk_250m) begin
    xdma_rst 	<= {xdma_rst[1:0],~sys_rst_n};
end

// 
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

wire                mem_rst             = pmt_rx_start || eds_rx_start || fbc_rx_start;
reg                 temp_ddr_wr_en      = 'd0   ;
reg     [511:0]     temp_ddr_wr_data    = 'd0   ;



reg adc_start_i = 'd0;



sim_pmt_to_pcie_aurora sim_pmt_to_pcie_aurora_inst(
    .aurora_clk_i               ( aurora_log_clk_0          ),
    .aurora_rst_i               ( aurora_reset_0            ),

    .adc_start_i                ( adc_start_i               ),
    .pcie_adc_end_i             ( pcie_pmt_rx_end           ),

    .pmt_aurora_rxen_o          ( pmt_aurora_rxen           ),
    .pmt_aurora_rxdata_o        ( pmt_aurora_rxdata         ),
    .pmt_rx_start_o             ( pmt_rx_start              ),
    .pmt_rx_end_o               ( pmt_rx_end                )

);

sim_timing_to_pcie_aurora sim_timing_to_pcie_aurora_inst(
    .aurora_clk_i               ( aurora_log_clk_1          ),
    .aurora_rst_i               ( aurora_reset_1            ),

    .adc_start_i                ( adc_start_i               ),
    .pcie_adc_end_i             ( pcie_pmt_rx_end           ),

    .eds_rx_start_o             ( eds_rx_start              ),
    .eds_rx_end_o               ( eds_rx_end                ),
    .eds_aurora_rxen_o          ( eds_aurora_rxen           ),
    .eds_aurora_rxdata_o        ( eds_aurora_rxdata         ),
    .fbc_rx_start_o             ( fbc_rx_start              ),
    .fbc_rx_end_o               ( fbc_rx_end                ),
    .encoder_rxen_o             ( pmt_encode_rxen           ),
    .encoder_rxdata_o           ( pmt_encode_rxdata         ),

    .sys_clk_i                  ( aurora_log_clk_0          )

);

aurora_rx_data_process	aurora_rx_data_process_inst(
    .aurora_log_clk_0	        ( aurora_log_clk_0          ),
    .aurora_rst_0		        ( aurora_reset_0            ),
    .pmt_aurora_rxen_i          ( pmt_aurora_rxen           ),
    .pmt_aurora_rxdata_i        ( pmt_aurora_rxdata         ),
    .pmt_rx_start_i             ( pmt_rx_start              ),
    .pcie_pmt_rx_end_i          ( pcie_pmt_rx_end           ),

    .aurora_log_clk_1           ( aurora_log_clk_1          ),
    .aurora_rst_1               ( aurora_reset_1            ),
    .eds_aurora_rxen_i          ( eds_aurora_rxen           ),
    .eds_aurora_rxdata_i        ( eds_aurora_rxdata         ),
    .eds_rx_start_i	            ( eds_rx_start              ),
    .pcie_eds_rx_end_i          ( pcie_eds_rx_end           ),
    .fbc_rx_start_i             ( fbc_rx_start              ),
    .pcie_fbc_rx_end_i          ( pcie_fbc_rx_end           ),

    .pmt_encode_en_i            ( pmt_encode_rxen           ),
    .pmt_encode_data_i          ( pmt_encode_rxdata         ),
 
    .aurora_rxen                ( aurora_rxen               ),
    .aurora_rxdata              ( aurora_rxdata             )

);

reg [2:0] temp_ddr_wr_cnt = 'd0;
always @(posedge aurora_log_clk_0) begin
    if(aurora_reset_0)
        temp_ddr_wr_cnt <= 'd0;
    else if(mem_rst)
        temp_ddr_wr_cnt <= 'd0;
    else if(aurora_rxen)
        temp_ddr_wr_cnt <= temp_ddr_wr_cnt + 1;
end

always @(posedge aurora_log_clk_0) begin
    if(aurora_reset_0)
        temp_ddr_wr_en <= 'd0;
    else if(mem_rst)
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
        .clk_500m_i                 ( sys_clk_i                 ), // ddr System clk input
        .clk_200m_i                 ( clk_ref_i                 ), // ddr Reference clk input
        .sys_clk_i                  ( aurora_log_clk_0          ), // aurora clk , write ddr
        .sys_rst_i                  ( aurora_rst_0              ),
        .xdma_user_clk_i            ( pcie_clk_250m             ), // xdma clk , read ddr
        .xdma_rst_i                 ( xdma_rst                  ), // active high , within xdma and aurora clk
    
        .eds_rx_start_i             ( eds_rx_start              ),
        .eds_rx_end_i               ( eds_rx_end                ),
        .pcie_eds_rx_end_o          ( pcie_eds_rx_end           ),
        .pmt_rx_start_i             ( pmt_rx_start              ),
        .pmt_rx_end_i               ( pmt_rx_end                ),
        .pcie_pmt_rx_end_o          ( pcie_pmt_rx_end           ),
        .fbc_rx_start_i             ( fbc_rx_start              ),
        .fbc_rx_end_i               ( fbc_rx_end                ),
        .pcie_fbc_rx_end_o          ( pcie_fbc_rx_end           ),
        .aurora_wr_en_i             ( temp_ddr_wr_en            ),
        .aurora_wr_data_i           ( temp_ddr_wr_data          ),
        .xdma_err_reset_i           ( 0                         ),
        
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
    
        // ddr complete reset
        .init_calib_complete_o      ( init_calib_complete            ),
        // ddr interface
        .ddr3_dq                    ( ddr3_dq_fpga                   ),
        .ddr3_dqs_n                 ( ddr3_dqs_n_fpga                ),
        .ddr3_dqs_p                 ( ddr3_dqs_p_fpga                ),
        .ddr3_addr                  ( ddr3_addr_fpga                 ),
        .ddr3_ba                    ( ddr3_ba_fpga                   ),
        .ddr3_ras_n                 ( ddr3_ras_n_fpga                ),
        .ddr3_cas_n                 ( ddr3_cas_n_fpga                ),
        .ddr3_we_n                  ( ddr3_we_n_fpga                 ),
        .ddr3_reset_n               ( ddr3_reset_n                   ),
        .ddr3_ck_p                  ( ddr3_ck_p_fpga                 ),
        .ddr3_ck_n                  ( ddr3_ck_n_fpga                 ),
        .ddr3_cke                   ( ddr3_cke_fpga                  ),
        .ddr3_cs_n                  ( ddr3_cs_n_fpga                 ),
        .ddr3_dm                    ( ddr3_dm_fpga                   ),
        .ddr3_odt                   ( ddr3_odt_fpga                  )
    );

  //**************************************************************************//

  // Memory Models instantiations

  //**************************************************************************//



  genvar r,i;

  generate

    for (r = 0; r < CS_WIDTH; r = r + 1) begin: mem_rnk

      if(DQ_WIDTH/16) begin: mem

        for (i = 0; i < NUM_COMP; i = i + 1) begin: gen_mem

          ddr3_model u_comp_ddr3

            (

             .rst_n   (ddr3_reset_n),

             .ck      (ddr3_ck_p_sdram),

             .ck_n    (ddr3_ck_n_sdram),

             .cke     (ddr3_cke_sdram[r]),

             .cs_n    (ddr3_cs_n_sdram[r]),

             .ras_n   (ddr3_ras_n_sdram),

             .cas_n   (ddr3_cas_n_sdram),

             .we_n    (ddr3_we_n_sdram),

             .dm_tdqs (ddr3_dm_sdram[(2*(i+1)-1):(2*i)]),

             .ba      (ddr3_ba_sdram[r]),

             .addr    (ddr3_addr_sdram[r]),

             .dq      (ddr3_dq_sdram[16*(i+1)-1:16*(i)]),

             .dqs     (ddr3_dqs_p_sdram[(2*(i+1)-1):(2*i)]),

             .dqs_n   (ddr3_dqs_n_sdram[(2*(i+1)-1):(2*i)]),

             .tdqs_n  (),

             .odt     (ddr3_odt_sdram[r])

             );

        end

      end

      if (DQ_WIDTH%16) begin: gen_mem_extrabits

        ddr3_model u_comp_ddr3

          (

           .rst_n   (ddr3_reset_n),

           .ck      (ddr3_ck_p_sdram),

           .ck_n    (ddr3_ck_n_sdram),

           .cke     (ddr3_cke_sdram[r]),

           .cs_n    (ddr3_cs_n_sdram[r]),

           .ras_n   (ddr3_ras_n_sdram),

           .cas_n   (ddr3_cas_n_sdram),

           .we_n    (ddr3_we_n_sdram),

           .dm_tdqs ({ddr3_dm_sdram[DM_WIDTH-1],ddr3_dm_sdram[DM_WIDTH-1]}),

           .ba      (ddr3_ba_sdram[r]),

           .addr    (ddr3_addr_sdram[r]),

           .dq      ({ddr3_dq_sdram[DQ_WIDTH-1:(DQ_WIDTH-8)],

                      ddr3_dq_sdram[DQ_WIDTH-1:(DQ_WIDTH-8)]}),

           .dqs     ({ddr3_dqs_p_sdram[DQS_WIDTH-1],

                      ddr3_dqs_p_sdram[DQS_WIDTH-1]}),

           .dqs_n   ({ddr3_dqs_n_sdram[DQS_WIDTH-1],

                      ddr3_dqs_n_sdram[DQS_WIDTH-1]}),

           .tdqs_n  (),

           .odt     (ddr3_odt_sdram[r])

           );

      end

    end

  endgenerate

    

    





  //***************************************************************************

  // Reporting the test case status

  // Status reporting logic exists both in simulation test bench (sim_tb_top)

  // and sim.do file for ModelSim. Any update in simulation run time or time out

  // in this file need to be updated in sim.do file as well.

  //***************************************************************************
  
  always @(posedge pcie_clk_250m ) begin
      if(m_axi_arvalid && m_axi_arready)
          m_axi_araddr <= m_axi_araddr + 'h1000;
  end
  
  initial begin
      wait (init_calib_complete);
      $display("Calibration Done");

      #1000000;
      adc_start_i = 1;
      #1000_000_000;
      $finish;

      #1000_000;
      m_axi_arvalid = 1;
      wait(m_axi_arready);
      #4_000;
      m_axi_arvalid = 0;
      m_axi_rready = 1;
      wait(m_axi_rlast);
      #4_000;
      m_axi_rready = 0;
      #40_000;
  
  
      m_axi_arvalid = 1;
      wait(m_axi_arready);
      #4_000;
      m_axi_arvalid = 0;
      m_axi_rready = 1;
      wait(m_axi_rlast);
      #4_000;
      m_axi_rready = 0;
      #40_000;
  
  
  
      
      $finish;
  end
  
    

endmodule



