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

module aurora_8b10b_0_FRAME_RX#(
    parameter           TCQ                 = 0.1
)(
    // User Interface
    output  reg         pmt_aurora_rxen_o   ,
    output  reg [31:0]  pmt_aurora_rxdata_o ,
    
    output  reg         pmt_rx_start_o      ,
    // output  reg         pmt_rx_end_o        ,
    // output  wire        pmt_rx_error_o      ,

    // startup flash
    output  wire        erase_multiboot_o   ,
    output  wire        startup_rst_o       ,
    output  wire        startup_finish_o    ,
    output  wire        startup_o           ,
    output  wire [31:0] startup_pack_cnt_o  ,
    output  wire        startup_vld_o       ,
    output  wire [31:0] startup_data_o      ,
    output  wire        read_flash_o        ,

    // System Interface
    input               USER_CLK            ,      
    input               RESET               ,
    input               CHANNEL_UP          ,
    
    input               rx_tvalid           ,
    input   [31:0]      rx_data             ,
    input   [3:0]       rx_tkeep            ,
    input               rx_tlast            
);

//***************************Internal Register/Wire Declarations***************************

parameter           PKG_LENGTH          = 1000;    //包头32bit + 有效数据1000*32bit

localparam          RX_IDLE             = 'd0;   // FSM IDLE
localparam          RX_CHECK            = 'd1;   // FSM CHECK PMT START/END
localparam          RX_EDS              = 'd2;   // FSM PMT RX
localparam          RX_STARTUP          = 'd3;   
localparam          RX_PROGRAM          = 'd4;   
localparam          RX_PROGRAM_LAST     = 'd5;   

wire                rx_error            ;

reg     [3-1:0]     rx_state            = RX_IDLE;
reg     [3-1:0]     rx_next_state       = RX_IDLE;

reg     [15:0]      len_cnt             = 'd0;
reg     [31:0]      frame_cnt           = 'd0;
reg                 pmt_rx_start_pulse  = 'd0;
reg                 pmt_rx_end_pulse    = 'd0;

reg                 erase_multiboot     = 'd0;
reg                 startup_rst         = 'd0;
reg                 startup_finish      = 'd0;
reg                 startup             = 'd0;
reg     [31:0]      startup_pack_cnt    = 'd0;
reg                 startup_vld         = 'd0;
reg     [31:0]      startup_data        = 'd0;
reg                 read_flash          = 'd0;
//*********************************Main Body of Code**********************************
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
            else if(rx_tvalid && rx_data == 32'h55aa_0100)
                rx_next_state = RX_STARTUP;
            else if(rx_tvalid && rx_data == 32'h55aa_0200)
                rx_next_state = RX_PROGRAM;
            else if(rx_tvalid && rx_data == 32'h55aa_0201)
                rx_next_state = RX_PROGRAM_LAST;
        end
        
        RX_CHECK: begin
            if(rx_tvalid && rx_tlast)
                rx_next_state = RX_IDLE;
            // else if(rx_error)
            //     rx_next_state = RX_IDLE;
        end

        RX_EDS: begin
            if(rx_tvalid && rx_tlast)
                rx_next_state = RX_IDLE;
            // else if(rx_error)
            //     rx_next_state = RX_IDLE;
        end

        RX_STARTUP: begin
            if(rx_tvalid && rx_tlast)
                rx_next_state = RX_IDLE;
        end
        
        RX_PROGRAM: begin
            if(rx_tvalid && rx_tlast)
                rx_next_state = RX_IDLE;
        end

        RX_PROGRAM_LAST: begin
            if(rx_tvalid && rx_tlast)
                rx_next_state = RX_IDLE;
        end
        default: rx_next_state = RX_IDLE;
    endcase
end

always @(posedge USER_CLK) begin
    if(rx_state==RX_IDLE)begin
        len_cnt <= 'd0;
    end
    else begin
        if(rx_tvalid)
            len_cnt <= len_cnt + 1;
    end
end

// pmt start/end singal, delay 30 clk
always @(posedge USER_CLK) begin
    if(rx_state==RX_CHECK)begin
        if(rx_tvalid && rx_tlast && len_cnt=='d0)begin
            pmt_rx_start_pulse <= #TCQ (rx_data=='d1);
            pmt_rx_end_pulse   <= #TCQ (rx_data=='d0); 
        end
        else begin
            pmt_rx_start_pulse <= #TCQ 'd0;
            pmt_rx_end_pulse   <= #TCQ 'd0;
        end
    end
    else begin
            pmt_rx_start_pulse <= #TCQ 'd0;
            pmt_rx_end_pulse   <= #TCQ 'd0;
    end
end

always @(posedge USER_CLK) begin
    if(pmt_rx_start_pulse)
        pmt_rx_start_o <= #TCQ 'd1;
    else if(pmt_rx_end_pulse)
        pmt_rx_start_o <= #TCQ 'd0;
end

// reg [7:0] rx_start_cnt;
// reg [7:0] rx_end_cnt;
// always @(posedge USER_CLK)
// begin
//     if(RESET) begin
//         pmt_rx_start_o  <= #TCQ 1'b0;
//         rx_start_cnt    <= #TCQ 'd0;
//     end
//     else if(pmt_rx_start_pulse) begin
//         pmt_rx_start_o  <= #TCQ 1'b1;
//         rx_start_cnt    <= #TCQ rx_start_cnt + 1'd1;
//     end
//     else if(rx_start_cnt == 'd30) begin
//         pmt_rx_start_o  <= #TCQ 1'b0;
//         rx_start_cnt    <= #TCQ 'd0;
//     end
//     else if(pmt_rx_start_o) begin
//         pmt_rx_start_o  <= #TCQ 1'b1;
//         rx_start_cnt    <= #TCQ rx_start_cnt + 1'd1;
//     end
//     else begin
//         pmt_rx_start_o  <= #TCQ 1'b0;
//         rx_start_cnt    <= #TCQ 'd0;
//     end
// end

// always @(posedge USER_CLK)
// begin
//     if(RESET) begin
//         pmt_rx_end_o <= #TCQ 1'b0;
//         rx_end_cnt   <= #TCQ 'd0;
//     end
//     else if(pmt_rx_end_pulse) begin
//         pmt_rx_end_o <= #TCQ 1'b1;
//         rx_end_cnt   <= #TCQ rx_end_cnt + 1'd1;
//     end
//     else if(rx_end_cnt == 'd30) begin
//         pmt_rx_end_o <= #TCQ 1'b0;
//         rx_end_cnt   <= #TCQ 'd0;
//     end
//     else if(pmt_rx_end_o) begin
//         pmt_rx_end_o <= #TCQ 1'b1;
//         rx_end_cnt   <= #TCQ rx_end_cnt + 1'd1;
//     end
//     else begin
//         pmt_rx_end_o <= #TCQ 1'b0;
//         rx_end_cnt   <= #TCQ 'd0;
//     end
// end

// pmt data
always @(posedge USER_CLK) begin
    if(rx_state==RX_EDS)begin
        if(rx_tvalid)begin   // len_cnt==0: frame count (dele)
            pmt_aurora_rxen_o   <= #TCQ 'd1;
            pmt_aurora_rxdata_o <= #TCQ rx_data;
        end
        else begin
            pmt_aurora_rxen_o   <= #TCQ 'd0; 
        end
    end
    else begin
        pmt_aurora_rxen_o <= #TCQ 'd0;
    end
end

// startup command
always @(posedge USER_CLK) begin
    if(rx_state==RX_STARTUP)begin
        if(rx_tvalid && rx_tlast && len_cnt=='d0)begin
            erase_multiboot <= #TCQ (rx_data=='d1);
            startup_rst     <= #TCQ (rx_data=='d2);
            read_flash      <= #TCQ (rx_data=='d3); 
        end
        else begin
            erase_multiboot <= #TCQ 'd0;
            startup_rst     <= #TCQ 'd0; 
            read_flash      <= #TCQ 'd0; 
        end
    end
    else begin
        erase_multiboot <= #TCQ 'd0;
        startup_rst     <= #TCQ 'd0; 
        read_flash      <= #TCQ 'd0; 
    end
end

always @(posedge USER_CLK) begin
    if(rx_state==RX_PROGRAM)begin
        if(rx_tvalid && (|len_cnt))begin
            startup_vld      <= #TCQ 'd1;
            startup_data     <= #TCQ rx_data;
        end
        else begin
            startup_vld      <= #TCQ 'd0;
        end
    end
    else begin
        startup_vld     <= #TCQ 'd0;
    end
end

always @(posedge USER_CLK) begin
    if(rx_state==RX_PROGRAM)begin
        if(rx_tvalid && len_cnt=='d0)begin
            startup_pack_cnt <= #TCQ rx_data;
        end
    end
    else if(rx_state==RX_PROGRAM_LAST)begin
        if(rx_tvalid && rx_tlast && len_cnt=='d0)begin
            startup_pack_cnt <= #TCQ rx_data;
        end
    end
end

always @(posedge USER_CLK) begin
    if(rx_state==RX_PROGRAM && rx_tvalid && len_cnt=='d0)
        startup <= #TCQ 'd1;
    else 
        startup <= #TCQ 'd0;
end

always @(posedge USER_CLK) begin
    if(rx_state==RX_PROGRAM_LAST && rx_tvalid && rx_tlast)
        startup_finish <= #TCQ 'd1;
    else 
        startup_finish <= #TCQ 'd0;
end

assign erase_multiboot_o  = erase_multiboot ;
assign startup_rst_o      = startup_rst     ;
assign startup_finish_o   = startup_finish  ;
assign startup_o          = startup         ;
assign startup_pack_cnt_o = startup_pack_cnt;
assign startup_vld_o      = startup_vld     ;
assign startup_data_o     = startup_data    ;
assign read_flash_o       = read_flash      ;
// test debug code
// reg [15:0]  test_cnt2;
// reg         rx_error2;

// always @(posedge USER_CLK)
// begin
//     if(RESET) begin
//         test_cnt2    <=    'd0;
//         rx_error2    <=    1'b0;
//     end
//     else if(pmt_rx_start_o) begin
//         test_cnt2    <=    'd0;
//         rx_error2    <=    1'b0;
//     end
//     else if(pmt_aurora_rxen_o) begin
//         test_cnt2    <=    test_cnt2 + 1'd1;
//         if(test_cnt2 == pmt_aurora_rxdata_o[15:0]) begin
//             rx_error2        <=    rx_error2;
//         end
//         else begin
//             rx_error2        <=    1'b1;
//         end
//     end
//     else begin
//         test_cnt2        <=    test_cnt2;
//         rx_error2        <=    rx_error2;
//     end
// end


// reg   rx_check_error = 'd0;
// always @(posedge USER_CLK) begin
//     if(RESET || ~CHANNEL_UP)
//         rx_check_error <= #TCQ 'd0;
//     else if(rx_state==RX_CHECK && rx_tvalid && rx_tlast)begin
//         if(len_cnt=='d0)
//             rx_check_error <= #TCQ 'd0;
//         else 
//             rx_check_error <= #TCQ 'd1;
//     end
// end

// reg rx_pmt_leng_error = 'd0;
// reg rx_pmt_frame_error = 'd0;
// always @(posedge USER_CLK) begin
//     if(RESET || ~CHANNEL_UP)begin
//         frame_cnt <= #TCQ 'd0;
//     end
//     else if(rx_state==RX_EDS)begin
//         if(rx_tvalid && rx_tlast)
//             frame_cnt <= #TCQ frame_cnt + 1; 
//     end
// end
// always @(posedge USER_CLK) begin
//     if(RESET || ~CHANNEL_UP)begin
//         rx_pmt_leng_error <= #TCQ 'd0;
//     end
//     else if(rx_state==RX_EDS && rx_tvalid && rx_tlast)begin
//         if(len_cnt == PKG_LENGTH - 1)
//             rx_pmt_leng_error <= #TCQ 'd0;
//         else 
//             rx_pmt_leng_error <= #TCQ 'd1;
//     end
// end

// assign pmt_rx_error_o = rx_pmt_leng_error || rx_check_error;

endmodule
