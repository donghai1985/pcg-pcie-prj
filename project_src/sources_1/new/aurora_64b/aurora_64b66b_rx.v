
`timescale 1 ns / 1 ps

//////////////////////////////////////////////////////////////////////////////////
// Company: zas
// Engineer: songyuxin
// 
// Create Date: 2023/10/13
// Design Name: PCG
// Module Name: aurora_64b66b_rx
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


module aurora_64b66b_rx #(
    parameter                   TCQ             = 0.1
)(
    // eds
    output                      eds_rx_start_o      ,
    output                      eds_aurora_rxen_o   ,
    output      [64-1:0]        eds_aurora_rxdata_o ,

    output                      fbc_rx_start_o      ,
    // output                      fbc_aurora_rxen_o   , // 与 eds 分时复用
    // output      [64-1:0]        fbc_aurora_rxdata_o ,
    // pmt encode
    output                      pmt_rx_start_o      ,
    output                      encoder_rxen_o      ,
    output      [64-1:0]        encoder_rxdata_o    ,
    output      [32-1:0]        eds_aurora_pack_cnt_o   ,
    output      [32-1:0]        pmt_aurora_pack_cnt_o   ,
    output      [32-1:0]        fbc_aurora_pack_cnt_o   ,

    // System Interface
    input                       USER_CLK            ,      
    input                       RESET               ,
    input                       CHANNEL_UP          ,
    
    input                       rx_tvalid_i         ,
    input       [64-1:0]        rx_tdata_i          ,
    input       [8-1:0]         rx_tkeep_i          ,
    input                       rx_tlast_i          
);

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Parameter Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

parameter           EDS_PKG_LENGTH    =    1026;    
//EDS包帧长为帧头64bit + 64bit X/W encoder数据 + 1024*64bit,
//帧头格式为16'h55aa + 16bit指令码

localparam          RX_IDLE         = 'b00001;   // FSM IDLE
localparam          RX_CHECK        = 'b00010;   // FSM CHECK EDS START/END
localparam          RX_EDS          = 'b00100;   // FSM EDS RX
localparam          RX_ENCODE       = 'b01000;   // FSM ENCODE RX
localparam          RX_FBC          = 'b10000;   // FSM FBC

//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Register Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

reg     [4:0]       rx_state                = RX_IDLE;
reg     [4:0]       rx_next_state           = RX_IDLE;

reg     [4:0]       channel_up_cnt          = 'd0;
reg     [15:0]      len_cnt                 = 'd0;

reg                 eds_rx_start_pulse      = 'd0;
reg                 eds_rx_end_pulse        = 'd0;
reg                 fbc_rx_start_pulse      = 'd0;
reg                 fbc_rx_end_pulse        = 'd0;
reg                 pmt_rx_start_pulse      = 'd0;
reg                 pmt_rx_end_pulse        = 'd0;

reg                 eds_rx_start_temp       = 'd0;
reg                 fbc_rx_start_temp       = 'd0;
reg                 pmt_rx_start_temp       = 'd0;

reg                 eds_aurora_rxen         = 'd0;
reg     [63:0]      eds_aurora_rxdata       = 'd0;
reg                 encoder_rxen            = 'd0;
reg     [63:0]      encoder_rxdata          = 'd0;
reg                 fbc_aurora_rxen         = 'd0;
reg     [63:0]      fbc_aurora_rxdata       = 'd0;
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Wire Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
wire                reset_c                         ;
wire                dly_data_xfer                   ;
// wire                rx_error                        ;


//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Instance Module
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

// widen_enable #(
//     .WIDEN_TYPE         ( 1                     ),  // 1 = posedge lock
//     .WIDEN_NUM          ( 15                    )
// )eds_start_widen_inst(
//     .clk_i              ( USER_CLK              ),
//     .rst_i              ( RESET                 ),

//     .src_signal_i       ( eds_rx_start_pulse    ),
//     .dest_signal_o      ( eds_rx_start_o        )    
// );
// widen_enable #(
//     .WIDEN_TYPE         ( 1                     ),  // 1 = posedge lock
//     .WIDEN_NUM          ( 15                    )
// )eds_end_widen_inst(
//     .clk_i              ( USER_CLK              ),
//     .rst_i              ( RESET                 ),

//     .src_signal_i       ( eds_rx_end_pulse      ),
//     .dest_signal_o      ( eds_rx_end_o          )    
// );
// widen_enable #(
//     .WIDEN_TYPE         ( 1                     ),  // 1 = posedge lock
//     .WIDEN_NUM          ( 15                    )
// )fbc_start_widen_inst(
//     .clk_i              ( USER_CLK              ),
//     .rst_i              ( RESET                 ),

//     .src_signal_i       ( fbc_rx_start_pulse    ),
//     .dest_signal_o      ( fbc_rx_start_o        )    
// );
// widen_enable #(
//     .WIDEN_TYPE         ( 1                     ),  // 1 = posedge lock
//     .WIDEN_NUM          ( 15                    )
// )fbc_end_widen_inst(
//     .clk_i              ( USER_CLK              ),
//     .rst_i              ( RESET                 ),

//     .src_signal_i       ( fbc_rx_end_pulse      ),
//     .dest_signal_o      ( fbc_rx_end_o          )    
// );
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Logic Design
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
always @ (posedge USER_CLK)begin
    if(RESET)
        channel_up_cnt <= #TCQ 'd0;
    else if(CHANNEL_UP)
        if(channel_up_cnt[4])
            channel_up_cnt <= #TCQ channel_up_cnt;
        else 
            channel_up_cnt <= #TCQ channel_up_cnt + 1'b1;
    else
        channel_up_cnt <= #TCQ 'd0;
end

assign dly_data_xfer = channel_up_cnt[4];

//Generate RESET signal when Aurora channel is not ready
assign reset_c = !dly_data_xfer;

always @(posedge USER_CLK) begin
    if(reset_c)
        rx_state <= #TCQ RX_IDLE;
    else 
        rx_state <= #TCQ rx_next_state;
end

always @(*) begin
    rx_next_state = rx_state;
    case (rx_state)
        RX_IDLE: begin
            if(rx_tvalid_i && rx_tdata_i[31:0] == 'h55aa_0001)
                rx_next_state = RX_CHECK;
            else if(rx_tvalid_i && rx_tdata_i[31:0] == 'h55aa_0002)
                rx_next_state = RX_EDS;
            else if(rx_tvalid_i && rx_tdata_i[31:0] == 'h55aa_0003)
                rx_next_state = RX_ENCODE;
            else if(rx_tvalid_i && rx_tdata_i[31:0] == 'h55aa_0004)
                rx_next_state = RX_FBC;
        end
        
        RX_CHECK,
        RX_EDS,
        RX_ENCODE,
        RX_FBC: begin
            if(rx_tvalid_i && rx_tlast_i)
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
        if(rx_tvalid_i)
            len_cnt <= len_cnt + 1;
    end
end

always @(posedge USER_CLK) begin
    if(rx_state[1])begin
        if(rx_tvalid_i && rx_tlast_i && len_cnt=='d0)begin
            eds_rx_start_pulse <= #TCQ (rx_tdata_i[2:0]=='d1);
            eds_rx_end_pulse   <= #TCQ (rx_tdata_i[2:0]=='d0);
            fbc_rx_start_pulse <= #TCQ (rx_tdata_i[2:0]=='d2);
            fbc_rx_end_pulse   <= #TCQ (rx_tdata_i[2:0]=='d3);
            pmt_rx_start_pulse <= #TCQ (rx_tdata_i[2:0]=='d4);
            pmt_rx_end_pulse   <= #TCQ (rx_tdata_i[2:0]=='d5);
        end
        else begin
            eds_rx_start_pulse <= #TCQ 'd0;
            eds_rx_end_pulse   <= #TCQ 'd0;
            fbc_rx_start_pulse <= #TCQ 'd0;
            fbc_rx_end_pulse   <= #TCQ 'd0;
            pmt_rx_start_pulse <= #TCQ 'd0;
            pmt_rx_end_pulse   <= #TCQ 'd0;
        end
    end
    else begin
            eds_rx_start_pulse <= #TCQ 'd0;
            eds_rx_end_pulse   <= #TCQ 'd0;
            fbc_rx_start_pulse <= #TCQ 'd0;
            fbc_rx_end_pulse   <= #TCQ 'd0;
            pmt_rx_start_pulse <= #TCQ 'd0;
            pmt_rx_end_pulse   <= #TCQ 'd0;
    end
end

always @(posedge USER_CLK) begin
    if(rx_state[2])begin
        if(rx_tvalid_i)begin   // len_cnt==0: Xencode; len_cnt==1: Wencode.
            eds_aurora_rxen     <= #TCQ 'd1;
            eds_aurora_rxdata   <= #TCQ rx_tdata_i;
        end
        else begin
            eds_aurora_rxen     <= #TCQ 'd0; 
        end
    end
    else if(rx_state[4])begin
        if(rx_tvalid_i)begin 
            eds_aurora_rxen     <= #TCQ 'd1;
            eds_aurora_rxdata   <= #TCQ rx_tdata_i;
        end
        else begin
            eds_aurora_rxen     <= #TCQ 'd0; 
        end
    end
    else begin
        eds_aurora_rxen <= #TCQ 'd0;
    end
end


always @(posedge USER_CLK) begin
    if(rx_state[3])begin
        if(rx_tvalid_i)begin 
            encoder_rxen    <= #TCQ 'd1;
            encoder_rxdata  <= #TCQ rx_tdata_i;
        end
        else begin
            encoder_rxen    <= #TCQ 'd0; 
        end
    end
    else 
        encoder_rxen <= #TCQ 'd0;
end

// always @(posedge USER_CLK) begin
//     if(rx_state[4])begin
//         if(rx_tvalid_i)begin 
//             fbc_aurora_rxen     <= #TCQ 'd1;
//             fbc_aurora_rxdata   <= #TCQ rx_tdata_i;
//         end
//         else begin
//             fbc_aurora_rxen     <= #TCQ 'd0; 
//         end
//     end
//     else begin
//         fbc_aurora_rxen <= #TCQ 'd0;
//     end
// end

always @(posedge USER_CLK) begin
    if(eds_rx_start_pulse)
        eds_rx_start_temp <= #TCQ 'd1;
    else if(eds_rx_end_pulse)
        eds_rx_start_temp <= #TCQ 'd0;
end

always @(posedge USER_CLK) begin
    if(fbc_rx_start_pulse)
        fbc_rx_start_temp <= #TCQ 'd1;
    else if(fbc_rx_end_pulse)
        fbc_rx_start_temp <= #TCQ 'd0;
end

always @(posedge USER_CLK) begin
    if(pmt_rx_start_pulse)
        pmt_rx_start_temp <= #TCQ 'd1;
    else if(pmt_rx_end_pulse)
        pmt_rx_start_temp <= #TCQ 'd0;
end

assign eds_rx_start_o       = eds_rx_start_temp;
assign fbc_rx_start_o       = fbc_rx_start_temp;
assign pmt_rx_start_o       = pmt_rx_start_temp;
assign eds_aurora_rxen_o    = eds_aurora_rxen  ;
assign eds_aurora_rxdata_o  = eds_aurora_rxdata;
assign encoder_rxen_o       = encoder_rxen;  
assign encoder_rxdata_o     = encoder_rxdata;
// assign fbc_aurora_rxen_o    = fbc_aurora_rxen  ;
// assign fbc_aurora_rxdata_o  = fbc_aurora_rxdata;
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

// 统计 eds pmt fbc分别传输了多少数据包，和timing板的统计数据交叉对比，验证数据完整性
// check eds pack number
reg [32-1:0] eds_aurora_pack_cnt = 'd0;
reg [32-1:0] pmt_aurora_pack_cnt = 'd0;
reg [32-1:0] fbc_aurora_pack_cnt = 'd0;

always @(posedge USER_CLK) begin
    if(eds_rx_start_pulse)
        eds_aurora_pack_cnt <= #TCQ 'd0;
    else if(rx_state[2] && rx_next_state[0])begin
        eds_aurora_pack_cnt <= #TCQ eds_aurora_pack_cnt + 1;
    end
end

always @(posedge USER_CLK) begin
    if(pmt_rx_start_pulse)
        pmt_aurora_pack_cnt <= #TCQ 'd0;
    else if(rx_state[3] && rx_next_state[0])begin
        pmt_aurora_pack_cnt <= #TCQ pmt_aurora_pack_cnt + 1;
    end
end

always @(posedge USER_CLK) begin
    if(fbc_rx_start_pulse)
        fbc_aurora_pack_cnt <= #TCQ 'd0;
    else if(rx_state[4] && rx_next_state[0])begin
        fbc_aurora_pack_cnt <= #TCQ fbc_aurora_pack_cnt + 1;
    end
end

assign eds_aurora_pack_cnt_o = eds_aurora_pack_cnt;
assign pmt_aurora_pack_cnt_o = pmt_aurora_pack_cnt;
assign fbc_aurora_pack_cnt_o = fbc_aurora_pack_cnt;
endmodule
