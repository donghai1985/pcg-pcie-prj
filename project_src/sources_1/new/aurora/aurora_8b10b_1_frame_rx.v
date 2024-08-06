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

module aurora_8b10b_1_FRAME_RX #(
    parameter           TCQ                 = 0.1
)(
    // User Interface
    output  reg             eds_aurora_rxen_o   ,
    output  reg     [31:0]  eds_aurora_rxdata_o ,
        
    output  wire            eds_rx_start_o      ,
    output  wire            eds_rx_end_o        ,
    output  wire            eds_rx_error_o      ,
    
    input   wire            pmt_rx_start_i      ,
    input   wire            pcie_pmt_rx_end_i   ,
    
    // input   wire            x_w_encoder_test_en_i ,
    output  wire            encoder_data_en_o   ,
    output  wire    [31:0]  w_encoder_data_o    ,
    output  wire    [31:0]  x_encoder_data_o    ,

    output  reg             fbc_aurora_rxen_o   ,
    output  reg     [31:0]  fbc_aurora_rxdata_o ,
    output  wire            fbc_rx_start_o      ,
    output  wire            fbc_rx_end_o        ,
    // System Interface
    input   wire            USER_CLK            ,      
    input   wire            RESET               ,
    input   wire            CHANNEL_UP          ,
    
    input   wire            rx_tvalid           ,
    input   wire    [31:0]  rx_data             ,
    input   wire    [3:0]   rx_tkeep            ,
    input   wire            rx_tlast            
);

//***************************Internal Register/Wire Declarations***************************

parameter           EDS_PKG_LENGTH    =    1026;    
//EDS包帧长为帧头32bit + 32bit帧计数器 + 64bit X/W encoder数据 + 1024*32bit,
//帧头格式为16'h55aa + 16bit指令码

localparam          RX_IDLE         = 'b00001;   // FSM IDLE
localparam          RX_CHECK        = 'b00010;   // FSM CHECK EDS START/END
localparam          RX_EDS          = 'b00100;   // FSM EDS RX
localparam          RX_ENCODE       = 'b01000;   // FSM ENCODE RX
localparam          RX_FBC          = 'b10000;   // FSM FBC

reg     [4:0]       rx_state        = RX_IDLE;
reg     [4:0]       rx_next_state   = RX_IDLE;

wire                rx_error        ;
reg     [15:0]      len_cnt                 = 'd0;
reg     [23:0]      eds_frame_cnt           = 'd0;

reg                 eds_rx_start_pulse      = 'd0;
reg                 eds_rx_end_pulse        = 'd0;
reg                 fbc_rx_start_pulse      = 'd0;
reg                 fbc_rx_end_pulse        = 'd0;
// reg                 eds_rx_start_exp        = 'd0;
// reg     [7:0]       eds_rx_start_exp_cnt    = 'd0;
// reg                 eds_rx_end_exp          = 'd0;
// reg     [7:0]       eds_rx_end_exp_cnt      = 'd0;

reg                 pmt_rx_start_reg1;
reg                 pmt_rx_start_reg2;
reg                 pcie_pmt_rx_end_reg1;
reg                 pcie_pmt_rx_end_reg2;
reg                 x_w_encoder_test_en_reg1;
reg                 x_w_encoder_test_en_reg2;

reg     [15:0]      test_cnt        = 'd0;
reg     [15:0]      cnt_20us        = 'd0;
reg                 encoder_data_en = 'd0;
reg     [31:0]      w_encoder_data  = 'd0;
reg     [31:0]      x_encoder_data  = 'd0;


widen_enable #(
    .WIDEN_TYPE         ( 1                     ),  // 1 = posedge lock
    .WIDEN_NUM          ( 10                    )
)eds_start_widen_inst(
    .clk_i              ( USER_CLK              ),
    .rst_i              ( RESET                 ),

    .src_signal_i       ( eds_rx_start_pulse    ),
    .dest_signal_o      ( eds_rx_start_o        )    
);
widen_enable #(
    .WIDEN_TYPE         ( 1                     ),  // 1 = posedge lock
    .WIDEN_NUM          ( 10                    )
)eds_end_widen_inst(
    .clk_i              ( USER_CLK              ),
    .rst_i              ( RESET                 ),

    .src_signal_i       ( eds_rx_end_pulse      ),
    .dest_signal_o      ( eds_rx_end_o          )    
);
widen_enable #(
    .WIDEN_TYPE         ( 1                     ),  // 1 = posedge lock
    .WIDEN_NUM          ( 10                    )
)fbc_start_widen_inst(
    .clk_i              ( USER_CLK              ),
    .rst_i              ( RESET                 ),

    .src_signal_i       ( fbc_rx_start_pulse    ),
    .dest_signal_o      ( fbc_rx_start_o        )    
);
widen_enable #(
    .WIDEN_TYPE         ( 1                     ),  // 1 = posedge lock
    .WIDEN_NUM          ( 10                    )
)fbc_end_widen_inst(
    .clk_i              ( USER_CLK              ),
    .rst_i              ( RESET                 ),

    .src_signal_i       ( fbc_rx_end_pulse      ),
    .dest_signal_o      ( fbc_rx_end_o          )    
);

//*********************************Main Body of Code**********************************
always @(posedge USER_CLK)
begin
    pmt_rx_start_reg1       <= #TCQ pmt_rx_start_i;
    pmt_rx_start_reg2       <= #TCQ pmt_rx_start_reg1;
    pcie_pmt_rx_end_reg1    <= #TCQ pcie_pmt_rx_end_i;
    pcie_pmt_rx_end_reg2    <= #TCQ pcie_pmt_rx_end_reg1;
end

always @(posedge USER_CLK) begin
    if(RESET || ~CHANNEL_UP)
        rx_state <= #TCQ RX_IDLE;
    else 
        rx_state <= #TCQ rx_next_state;
end

always @(*) begin
    rx_next_state = rx_state;
    case (rx_state)
        RX_IDLE: begin
            if(rx_tvalid && rx_data == 32'h55aa_0001)
                rx_next_state = RX_CHECK;
            else if(rx_tvalid && rx_data == 32'h55aa_0002)
                rx_next_state = RX_EDS;
            else if(rx_tvalid && rx_data == 32'h55aa_0003)
                rx_next_state = RX_ENCODE;
            else if(rx_tvalid && rx_data == 32'h55aa_0004)
                rx_next_state = RX_FBC;
        end
        
        RX_CHECK,
        RX_EDS,
        RX_ENCODE,
        RX_FBC: begin
            if(rx_tvalid && rx_tlast)
                rx_next_state = RX_IDLE;
        end
        default: rx_next_state = RX_IDLE;
    endcase
end

always @(posedge USER_CLK) begin
    if(rx_state[0])begin
        len_cnt <= 'd0;
    end
    else if(|rx_state[4:1])begin
        if(rx_tvalid)
            len_cnt <= len_cnt + 1;
    end
end

reg   rx_check_error = 'd0;
always @(posedge USER_CLK) begin
    if(RESET || ~CHANNEL_UP)
        rx_check_error <= #TCQ 'd0;
    else if(rx_state[1] && rx_tvalid && rx_tlast)begin
        if(len_cnt=='d0)
            rx_check_error <= #TCQ 'd0;
        else 
            rx_check_error <= #TCQ 'd1;
    end
end

always @(posedge USER_CLK) begin
    if(rx_state[1])begin
        if(rx_tvalid && rx_tlast && len_cnt=='d0)begin
            eds_rx_start_pulse <= #TCQ (rx_data[1:0]=='d1);
            eds_rx_end_pulse   <= #TCQ (rx_data[1:0]=='d0); 
            fbc_rx_start_pulse <= #TCQ (rx_data[1:0]=='d2);
            fbc_rx_end_pulse   <= #TCQ (rx_data[1:0]=='d3); 
        end
        else begin
            eds_rx_start_pulse <= #TCQ 'd0;
            eds_rx_end_pulse   <= #TCQ 'd0;
            fbc_rx_start_pulse <= #TCQ 'd0;
            fbc_rx_end_pulse   <= #TCQ 'd0;
        end
    end
    else begin
            eds_rx_start_pulse <= #TCQ 'd0;
            eds_rx_end_pulse   <= #TCQ 'd0;
            fbc_rx_start_pulse <= #TCQ 'd0;
            fbc_rx_end_pulse   <= #TCQ 'd0;
    end
end

reg rx_eds_leng_error = 'd0;
reg rx_eds_frame_error = 'd0;
always @(posedge USER_CLK) begin
    if(RESET || ~CHANNEL_UP)begin
        eds_frame_cnt <= #TCQ 'd0;
    end
    else if(rx_state[2])begin
        if(rx_tvalid && rx_tlast)
            eds_frame_cnt <= #TCQ eds_frame_cnt + 1; 
    end
end
always @(posedge USER_CLK) begin
    if(RESET || ~CHANNEL_UP)begin
        rx_eds_leng_error <= #TCQ 'd0;
    end
    else if(rx_state[2] && rx_tvalid && rx_tlast)begin
        if(len_cnt == EDS_PKG_LENGTH - 1)
            rx_eds_leng_error <= #TCQ 'd0;
        else 
            rx_eds_leng_error <= #TCQ 'd1;
    end
end
always @(posedge USER_CLK)begin
    if(RESET || ~CHANNEL_UP)begin
        rx_eds_frame_error <= #TCQ 'd0;
    end
    else if(rx_state[2] && rx_tvalid && len_cnt=='d0)begin
        if(rx_data == eds_frame_cnt)
            rx_eds_frame_error <= #TCQ 'd0;
        else 
            rx_eds_frame_error <= #TCQ 'd1;    
    end
end

always @(posedge USER_CLK) begin
    if(rx_state[2])begin
        if(rx_tvalid && len_cnt)begin   // len_cnt==0: frame count; len_cnt==1: Xencode; len_cnt==2: Wencode.
            eds_aurora_rxen_o     <= #TCQ 'd1;
            eds_aurora_rxdata_o   <= #TCQ rx_data;
        end
        else begin
            eds_aurora_rxen_o     <= #TCQ 'd0; 
        end
    end
    else if(rx_state[4])begin
        if(rx_tvalid)begin 
            eds_aurora_rxen_o     <= #TCQ 'd1;
            eds_aurora_rxdata_o   <= #TCQ rx_data;
        end
        else begin
            eds_aurora_rxen_o     <= #TCQ 'd0; 
        end
    end
    else begin
        eds_aurora_rxen_o <= #TCQ 'd0;
    end
end


// always @(posedge USER_CLK)
// begin
//     if(RESET) begin
//         eds_rx_start_exp        <= #TCQ 1'b0;
//         eds_rx_start_exp_cnt    <= #TCQ 'd0;
//     end
//     else if(eds_rx_start_pulse) begin
//         eds_rx_start_exp        <= #TCQ 1'b1;
//         eds_rx_start_exp_cnt    <= #TCQ eds_rx_start_exp_cnt + 1'd1;
//     end
//     else if(eds_rx_start_exp_cnt == 'd30) begin
//         eds_rx_start_exp        <= #TCQ 1'b0;
//         eds_rx_start_exp_cnt    <= #TCQ 'd0;
//     end
//     else if(eds_rx_start_exp) begin
//         eds_rx_start_exp        <= #TCQ 1'b1;
//         eds_rx_start_exp_cnt    <= #TCQ eds_rx_start_exp_cnt + 1'd1;
//     end
//     else begin
//         eds_rx_start_exp        <= #TCQ 1'b0;
//         eds_rx_start_exp_cnt    <= #TCQ 'd0;
//     end
// end

// assign eds_rx_start_o = eds_rx_start_exp;    

// always @(posedge USER_CLK)
// begin
//     if(RESET) begin
//         eds_rx_end_exp      <= #TCQ 1'b0;
//         eds_rx_end_exp_cnt  <= #TCQ 'd0;
//     end
//     else if(eds_rx_end_pulse) begin
//         eds_rx_end_exp      <= #TCQ 1'b1;
//         eds_rx_end_exp_cnt  <= #TCQ eds_rx_end_exp_cnt + 1'd1;
//     end
//     else if(eds_rx_end_exp_cnt == 'd30) begin
//         eds_rx_end_exp      <= #TCQ 1'b0;
//         eds_rx_end_exp_cnt  <= #TCQ 'd0;
//     end
//     else if(eds_rx_end_exp) begin
//         eds_rx_end_exp      <= #TCQ 1'b1;
//         eds_rx_end_exp_cnt  <= #TCQ eds_rx_end_exp_cnt + 1'd1;
//     end
//     else begin
//         eds_rx_end_exp      <= #TCQ 1'b0;
//         eds_rx_end_exp_cnt  <= #TCQ 'd0;
//     end
// end

// assign    eds_rx_end_o    =    eds_rx_end_exp;    

// always @(posedge USER_CLK)begin
//     x_w_encoder_test_en_reg1 <= #TCQ x_w_encoder_test_en_i;
//     x_w_encoder_test_en_reg2 <= #TCQ x_w_encoder_test_en_reg1;
// end

// always @(posedge USER_CLK) begin
//     if(pmt_rx_start_reg2 || pcie_pmt_rx_end_reg2)begin
//         test_cnt <= #TCQ 'd0;
//         cnt_20us <= #TCQ 'd0;
//     end
//     else if(x_w_encoder_test_en_reg2)begin
//         if(cnt_20us < 'd2499)begin
//             test_cnt <= #TCQ test_cnt;
//             cnt_20us <= #TCQ cnt_20us + 1;
//         end
//         else begin
//             test_cnt <= #TCQ test_cnt + 1;
//             cnt_20us <= #TCQ 'd0;
//         end
//     end
//     else begin
//         test_cnt <= #TCQ 'd0;
//         cnt_20us <= #TCQ 'd0;
//     end
// end

always @(posedge USER_CLK) begin
    // if(x_w_encoder_test_en_reg2)begin
    //     encoder_data_en <= #TCQ cnt_20us=='d2499;
    //     x_encoder_data  <= #TCQ {14'd0,test_cnt[8:0],9'd0};
    //     w_encoder_data  <= #TCQ {14'd0,test_cnt[15:0],2'd0};
    // end
    // else 
    if(rx_state[3])begin
        if(rx_tvalid && len_cnt=='d0)begin
            encoder_data_en <= #TCQ 'd0;
            x_encoder_data  <= #TCQ rx_data;
        end
        else if(rx_tvalid && len_cnt=='d1)begin
            encoder_data_en <= #TCQ 'd1;
            w_encoder_data  <= #TCQ rx_data;
        end
        else 
            encoder_data_en <= #TCQ 'd0;
    end
    else 
        encoder_data_en <= #TCQ 'd0;
end

always @(posedge USER_CLK) begin
    if(rx_state[4])begin
        if(rx_tvalid)begin 
            fbc_aurora_rxen_o     <= #TCQ 'd1;
            fbc_aurora_rxdata_o   <= #TCQ rx_data;
        end
        else begin
            fbc_aurora_rxen_o     <= #TCQ 'd0; 
        end
    end
    else begin
        fbc_aurora_rxen_o <= #TCQ 'd0;
    end
end

assign rx_error          = rx_check_error || rx_eds_leng_error || rx_eds_frame_error;
assign eds_rx_error_o    = rx_error;
assign encoder_data_en_o = encoder_data_en ;
assign w_encoder_data_o  = w_encoder_data  ;
assign x_encoder_data_o  = x_encoder_data  ;

// debug code
// reg [32-1:0] eds_data_cnt = 'd0;
// reg [32-1:0] eds_pack_cnt = 'd0;
// always @(posedge USER_CLK ) begin
//     if(eds_rx_start_o)begin
//         eds_data_cnt <= #TCQ 'd0;
//         eds_pack_cnt <= #TCQ 'd0;
//     end
//     else if(rx_state[2] && eds_aurora_rxen_o)begin
//         if(eds_data_cnt < 'h200000)begin // 8M
//             eds_data_cnt <= eds_data_cnt + 1;
//             eds_pack_cnt <= eds_pack_cnt;
//         end
//         else begin
//             eds_data_cnt <= 'd0;
//             eds_pack_cnt <= eds_pack_cnt + 1;
//         end
//     end
// end
endmodule
