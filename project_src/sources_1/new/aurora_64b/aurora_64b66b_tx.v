
`timescale 1 ns / 1 ps

//////////////////////////////////////////////////////////////////////////////////
// Company: zas
// Engineer: songyuxin
// 
// Create Date: 2023/10/10
// Design Name: PCG
// Module Name: aurora_64b66b_tx
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


module aurora_64b66b_tx #(
    parameter               TCQ         = 0.1
)(
    input                   pcie_eds_rx_end_i               ,
    input                   pcie_pmt_rx_end_i               ,
    
    // System Interface
    input                   USER_CLK                        ,
    input                   RESET                           ,
    input                   CHANNEL_UP                      ,
    
    output                  tx_tvalid_o                     ,
    output  [64-1:0]        tx_tdata_o                      ,
    output  [8-1:0]         tx_tkeep_o                      ,
    output                  tx_tlast_o                      ,
    input                   tx_tready_i                     
);

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Parameter Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

localparam                  TX_IDLE             = 'b001     ;  // tx_state[0]
localparam                  TX_EDS_RX_END       = 'b010     ;  // tx_state[1]
localparam                  TX_PMT_RX_END       = 'b100     ;  // tx_state[2]

//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Register Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
reg     [3-1:0]             tx_state            = TX_IDLE   ;
reg     [3-1:0]             tx_state_next       = TX_IDLE   ;
reg     [4:0]               channel_up_cnt      = 'd0       ;

reg     [15:0]              len_cnt             = 'd0       ;

reg                         tx_tvalid           = 'd0       ;
reg     [63:0]              tx_tdata            = 'd0       ;  
reg                         tx_tlast            = 'd0       ; 

//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Wire Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
wire                        reset_c                         ;
wire                        dly_data_xfer                   ;

//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Instance Module
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

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

//______________________________ Transmit Data  __________________________________   

reg pcie_eds_rx_end_d       = 'd0;
reg pcie_eds_rx_end_pose    = 'd0;
reg pcie_pmt_rx_end_d       = 'd0;
reg pcie_pmt_rx_end_pose    = 'd0;
always @(posedge USER_CLK) begin
    pcie_pmt_rx_end_d <= #TCQ pcie_pmt_rx_end_i;
    pcie_pmt_rx_end_pose <= #TCQ (~pcie_pmt_rx_end_d) && pcie_pmt_rx_end_i;
end

always @(posedge USER_CLK) begin
    pcie_eds_rx_end_d <= #TCQ pcie_eds_rx_end_i;
    pcie_eds_rx_end_pose <= #TCQ (~pcie_eds_rx_end_d) && pcie_eds_rx_end_i;
end

always @(posedge USER_CLK) begin
    if(reset_c)
        tx_state <= #TCQ TX_IDLE;
    else 
        tx_state <= #TCQ tx_state_next;
end

always @(*) begin
    tx_state_next = tx_state;
    case(tx_state)
        TX_IDLE: begin
            if(pcie_eds_rx_end_pose)
                tx_state_next = TX_EDS_RX_END;
            else if(pcie_pmt_rx_end_pose)
                tx_state_next = TX_PMT_RX_END;
        end 

        TX_EDS_RX_END,
        TX_PMT_RX_END: begin
            if(tx_tlast && tx_tvalid && tx_tready_i)
                tx_state_next = TX_IDLE; 
        end

        default:tx_state_next = TX_IDLE;
    endcase
end

wire tx_state_flag ;
assign tx_state_flag = (|tx_state[2:1]);

// tx count
always @(posedge USER_CLK) begin
    if(tx_state_flag)begin
        if(tx_tlast && tx_tvalid && tx_tready_i)
            len_cnt <= #TCQ 'd0;
        else if(tx_tready_i && tx_tvalid)
            len_cnt <= #TCQ len_cnt + 1;
    end
    else begin
        len_cnt <= #TCQ 'd0;
    end
end

always @(posedge USER_CLK)begin
    if(tx_state_flag)begin
        if(tx_tlast && tx_tvalid && tx_tready_i)
            tx_tvalid <= #TCQ 'd0;
        else 
            tx_tvalid <= #TCQ tx_tready_i;
    end
    else begin
        tx_tvalid <= #TCQ 1'b0;
    end
end

always @(posedge USER_CLK)
begin
    if((tx_state[1] && tx_tvalid && tx_tready_i)) begin
        if(len_cnt == 'd0) begin
            tx_tdata <= #TCQ 'h55aa_0001;    
        end
        else if(len_cnt == 'd1) begin
            tx_tdata <= #TCQ 'h0000_0001;
        end
    end
    else if((tx_state[2] && tx_tvalid && tx_tready_i)) begin
        if(len_cnt == 'd0) begin
            tx_tdata <= #TCQ 'h55aa_0001;    
        end
        else if(len_cnt == 'd1) begin
            tx_tdata <= #TCQ 'h0000_0002;
        end
    end
end

always @(posedge USER_CLK)
begin
    if((tx_state[1] || tx_state[2]) && (len_cnt == 'd1))
        tx_tlast <= #TCQ tx_tready_i && tx_tvalid;
    else if(tx_tlast && tx_tvalid && tx_tready_i)
        tx_tlast <= #TCQ 1'b0;
end   

assign tx_tvalid_o              = tx_tvalid && (|len_cnt);
assign tx_tdata_o               = tx_tdata;  
assign tx_tkeep_o               = 8'hFF;
assign tx_tlast_o               = tx_tlast; 

//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


endmodule
