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
// `define DLY #1

module aurora_8b10b_0_FRAME_GEN
(
    // User Interface
    // output              aurora_txen_o       ,
    // input   [31:0]      aurora_txdata_i     ,
    // input               aurora_tx_emp_i     ,
    input               pcie_pmt_rx_end_i   ,

    input               erase_ack_i         ,
    input   [8-1:0]     erase_status_reg_i  ,
    input   [2-1:0]     startup_ack_i       ,
    input   [16-1:0]    startup_last_pack_i ,
    input               startup_rst_i       ,
    input               flash_rd_valid_i    ,
    input   [16-1:0]    flash_rd_data_i     ,
    // System Interface
    input               USER_CLK,
    input               RESET,
    input               CHANNEL_UP,

    output              tx_tvalid,
    output  wire [31:0] tx_data,
    output  wire [3:0]  tx_tkeep,
    output  wire        tx_tlast,
    input               tx_tready
);


//***************************Internal Register/Wire Declarations***************************
parameter                       TCQ             = 0.1       ;
localparam  [5-1:0]             TX_IDLE         = 'b00001  ;
localparam  [5-1:0]             TX_PMT_END      = 'b00010  ;
localparam  [5-1:0]             TX_ERASE_ACK    = 'b00100  ;
localparam  [5-1:0]             TX_PROGRAM_ACK  = 'b01000  ;
localparam  [5-1:0]             TX_RD_FLASH     = 'b10000  ;

wire                            reset_c                     ;
wire                            dly_data_xfer               ;
wire                            up_edge_pcie_pmt_rx_end     ;
wire                            tx_state_temp_pose      = 0 ;

reg                             aurora_txen            = 'd0;
wire                            aurora_tx_prog_empty        ;
wire                            aurora_tx_full              ;
wire                            aurora_tx_empty             ;
wire                            aurora_tx_sbiterr           ;
wire                            aurora_tx_dbiterr           ;
wire        [31:0]              aurora_txdata               ;

reg         [5-1:0]             tx_state        = TX_IDLE   ;
reg         [5-1:0]             tx_state_next   = TX_IDLE   ;
reg         [4:0]               channel_up_cnt  = 'd0       ;
reg         [15:0]              len_cnt         = 'd0       ;
reg         [1:0]               startup_ack_r   = 'd0       ;

reg                             pcie_pmt_rx_end_reg1;
reg                             pcie_pmt_rx_end_reg2;
reg                             pcie_pmt_rx_end_reg3;

reg flash_rd_valid = 'd0;
always @(posedge USER_CLK) begin
    if(RESET || startup_rst_i)
        flash_rd_valid <= #TCQ 'd0;
    else if(flash_rd_valid_i)
        flash_rd_valid <= #TCQ ~flash_rd_valid;
end

reg flash_rd_valid_r = 'd0;
always @(posedge USER_CLK) begin
    flash_rd_valid_r <= #TCQ flash_rd_valid && flash_rd_valid_i;
end
// // debug code
// reg [10-1:0] flash_fifo_cnt = 'd0;
// always @(posedge USER_CLK) begin
//     if(flash_rd_valid_r)
//         flash_fifo_cnt <= #TCQ flash_fifo_cnt + 1;
//     else if(tx_state[4] && tx_tlast)
//         flash_fifo_cnt <= #TCQ 'd0;
// end


reg [32-1:0] flash_rd_data_r = 'd0;
always @(posedge USER_CLK) begin
    if(flash_rd_valid_i)
        flash_rd_data_r <= #TCQ {flash_rd_data_r[16-1:0]
                                ,flash_rd_data_i[8]
                                ,flash_rd_data_i[9]
                                ,flash_rd_data_i[10]
                                ,flash_rd_data_i[11]
                                ,flash_rd_data_i[12]
                                ,flash_rd_data_i[13]
                                ,flash_rd_data_i[14]
                                ,flash_rd_data_i[15]
                                ,flash_rd_data_i[0]
                                ,flash_rd_data_i[1]
                                ,flash_rd_data_i[2]
                                ,flash_rd_data_i[3]
                                ,flash_rd_data_i[4]
                                ,flash_rd_data_i[5]
                                ,flash_rd_data_i[6]
                                ,flash_rd_data_i[7]};
end

aurora_tx_fifo aurora_tx_fifo_inst(
    .clk                    ( USER_CLK                  ),
    .srst                   ( RESET || startup_rst_i    ),
    .din                    ( flash_rd_data_r           ),
    .wr_en                  ( flash_rd_valid_r          ),
    .rd_en                  ( aurora_txen               ),
    .dout                   ( aurora_txdata             ),
    .prog_empty             ( aurora_tx_prog_empty      ),
    .full                   ( aurora_tx_full            ),
    .empty                  ( aurora_tx_empty           ),
    .sbiterr                ( aurora_tx_sbiterr         ),
    .dbiterr                ( aurora_tx_dbiterr         )
);
//*********************************Main Body of Code**********************************

always @ (posedge USER_CLK)
begin
      if(RESET)
          channel_up_cnt <= #TCQ 5'd0;
      else if(CHANNEL_UP)
            if(&channel_up_cnt)
                channel_up_cnt <= #TCQ channel_up_cnt;
            else 
                channel_up_cnt <= #TCQ channel_up_cnt + 1'b1;
      else
            channel_up_cnt <= #TCQ 5'd0;
end

assign dly_data_xfer = (&channel_up_cnt);

  //Generate RESET signal when Aurora channel is not ready
assign reset_c = RESET || !dly_data_xfer;

always @ (posedge USER_CLK)begin
    pcie_pmt_rx_end_reg1 <= #TCQ pcie_pmt_rx_end_i;
    pcie_pmt_rx_end_reg2 <= #TCQ pcie_pmt_rx_end_reg1;
    pcie_pmt_rx_end_reg3 <= #TCQ pcie_pmt_rx_end_reg2;
end

assign  up_edge_pcie_pmt_rx_end = pcie_pmt_rx_end_reg2 && (~pcie_pmt_rx_end_reg3);

    //______________________________ Transmit Data  __________________________________   

always @(posedge USER_CLK) begin
    if(reset_c)
        tx_state <= #TCQ TX_IDLE;
    else 
        tx_state <= #TCQ tx_state_next;
end

always @(*)begin
    tx_state_next = tx_state;
    case(tx_state)
        TX_IDLE: begin
            if(up_edge_pcie_pmt_rx_end)begin
                tx_state_next = TX_PMT_END;
            end
            else if(erase_ack_i)begin
                tx_state_next = TX_ERASE_ACK;
            end
            else if(startup_ack_i)
                tx_state_next = TX_PROGRAM_ACK;
            else if(~aurora_tx_prog_empty)
                tx_state_next = TX_RD_FLASH;
        end

        TX_PMT_END: begin
            if(tx_tlast) begin
                tx_state_next = TX_IDLE;
            end
        end

        TX_ERASE_ACK: begin
            if(tx_tlast) begin
                tx_state_next = TX_IDLE;
            end
        end

        TX_PROGRAM_ACK: begin
            if(tx_tlast) begin
                tx_state_next = TX_IDLE;
            end
        end

        TX_RD_FLASH: begin
            if(tx_tlast) begin
                tx_state_next = TX_IDLE;
            end
        end
        default: tx_state_next = TX_IDLE;
    endcase
	
end
			
always @(posedge USER_CLK)
begin
    if(tx_state[0]) begin
        len_cnt <= #TCQ 'd0;
    end
    else begin
        if(tx_tlast) begin
            len_cnt <= #TCQ 'd0;
        end
        else if(tx_tvalid) begin
            len_cnt <= #TCQ len_cnt + 1'd1;
        end
    end
end 

always @(posedge USER_CLK) begin
    if(|startup_ack_i)
        startup_ack_r <= #TCQ startup_ack_i;
    else
        startup_ack_r <= #TCQ 'd0;
end

always @(posedge USER_CLK) begin
    if(tx_state[4])begin
        aurora_txen <= #TCQ tx_tvalid;
    end
    else begin
        aurora_txen <= #TCQ 'd0;
    end
end

assign  aurora_txen_o = 1'b0;
assign  tx_tvalid   = tx_state[4:1] ? tx_tready : 1'b0;
assign  tx_tkeep    = 4'b1111;
assign  tx_data	    = tx_state[1] ? ((len_cnt == 'd0) ? {16'h55aa,16'h0002} : {31'd0,1'b1})  :
                      tx_state[2] ? ((len_cnt == 'd0) ? {16'h55aa,16'h0200} : {24'd0,erase_status_reg_i[7:0]})  :
                      tx_state[3] ? ((len_cnt == 'd0) ? {16'h55aa,16'h0201} : {startup_ack_r[1],15'd0,startup_last_pack_i[15:0]})  :      // 0x80XX  program err
                      tx_state[4] ? ((len_cnt == 'd0) ? {16'h55aa,16'h0300} : aurora_txdata)  :
                      32'd0;
assign  tx_tlast    = tx_state[1] ? (len_cnt == 'd1) && tx_tready :
                      tx_state[2] ? (len_cnt == 'd1) && tx_tready :
                      tx_state[3] ? (len_cnt == 'd1) && tx_tready :
                      tx_state[4] ? (len_cnt == 'd255) && tx_tready :
                      'd0;

endmodule
