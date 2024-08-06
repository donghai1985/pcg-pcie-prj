
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


module sim_aurora_64b66b_tx #(
    parameter                   TCQ             = 0.1
)(
    // eds
    input                   eds_frame_en_i                  ,
    input                   pcie_eds_end_i                  ,
    output                  eds_tx_en_o                     ,
    input   [64:0]          eds_tx_data_i                   ,
    input   [13:0]          eds_rd_data_count_i             ,
    output                  clear_eds_buffer_o              ,

    input                   eds_encode_empty_i              ,
    output                  eds_encode_en_o                 ,
    input   [32-1:0]        precise_encode_w_data_i         ,
    input   [32-1:0]        precise_encode_x_data_i         ,

    // pmt encode
    input                   pmt_start_en_i                  ,
    input                   pcie_pmt_end_i                  ,
    output                  encode_tx_en_o                  ,
    input   [64:0]          encode_tx_data_i                ,
    input   [11:0]          encode_rd_data_count_i          ,
    output                  clear_encode_buffer_o           ,

    // FBC 
    output                  aurora_fbc_en_o                 ,
    input   [64-1:0]        aurora_fbc_data_i               ,
    input   [11-1:0]        aurora_fbc_count_i              ,
    input                   aurora_fbc_end_i                ,
    input                   aurora_fbc_empty_i              ,

    output  [32-1:0]        eds_pack_cnt_o                  ,
    output  [32-1:0]        encode_pack_cnt_o               ,
    
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

// localparam                  EDS_PACKAGE_LENG    = 'd1026    ; // header + eds + encode
localparam                  TX_IDLE             = 'd0       ;
localparam                  TX_EDS_START        = 'd1       ;
localparam                  TX_EDS_DATA         = 'd2       ;
localparam                  TX_EDS_END          = 'd3       ;
localparam                  TX_PCIE_WITE        = 'd4       ;
localparam                  TX_EDS_WITE         = 'd5       ;
localparam                  TX_ENCODE_WITE      = 'd6       ;
localparam                  TX_ENCODE           = 'd7       ;
localparam                  TX_FBC_WITE         = 'd8       ;
localparam                  TX_FBC              = 'd9       ;
localparam                  TX_FBC_START        = 'd10      ;
localparam                  TX_FBC_START_DELAY  = 'd11      ;
localparam                  TX_FBC_END_DELAY    = 'd12      ;
localparam                  TX_FBC_END          = 'd13      ;

// localparam                  CHECK_FBC_TIMEOUT   = 'd2500000 ; // 10ms

//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Register Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

reg     [4-1:0]             tx_state            = TX_IDLE   ;
reg     [4-1:0]             tx_state_next       = TX_IDLE   ;
reg     [4:0]               channel_up_cnt      = 'd0       ;

reg     [15:0]              len_cnt             = 'd0       ;
reg     [31:0]              frame_cnt           = 'd0       ;
reg     [7:0]               eds_tx_delay_cnt    = 'd0       ;
reg                         eds_last_package    = 'd0       ;

reg                         eds_frame_en_d0     = 'd0       ;
reg                         eds_frame_en_d1     = 'd0       ;

reg                         pcie_pmt_stop_en    = 'd0       ;
reg                         pmt_start_en_d0     = 'd0       ;
reg                         pmt_start_en_d1     = 'd0       ;
reg                         pcie_eds_frame_end_flag = 'd0   ;

reg     [9:0]               fbc_delay_cnt       = 'd0       ; 
reg                         aurora_fbc_end_d    = 'd0       ;
reg                         aurora_fbc_empty_d  = 'd0       ;

reg                         tx_tvalid           = 'd0       ;
reg     [63:0]              tx_tdata            = 'd0       ;  
reg                         tx_tlast            = 'd0       ; 

reg                         clear_eds_buffer    = 'd0       ;
reg                         clear_encode_buffer = 'd0       ;
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Wire Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
wire                        reset_c                         ;
wire                        dly_data_xfer                   ;
wire                        eds_frame_pose                  ;
wire                        pmt_start_pose                  ;
wire                        wait_fbc_timeout                ;

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

//EDS包帧长为帧头64bit + 64bit X/W encoder数据 + 1024*32bit,
//帧头格式为16'h55aa + 16bit指令码
//______________________________ Transmit Data  __________________________________   

always @ (posedge USER_CLK)begin
    eds_frame_en_d0 <= #TCQ eds_frame_en_i;
    eds_frame_en_d1 <= #TCQ eds_frame_en_d0;
end
always @ (posedge USER_CLK)begin
    pmt_start_en_d0 <= #TCQ pmt_start_en_i;
    pmt_start_en_d1 <= #TCQ pmt_start_en_d0;
end
always @(posedge USER_CLK) begin
    if(tx_state==TX_IDLE)
        pcie_pmt_stop_en <= #TCQ 'd0;
    else if(pcie_pmt_end_i)
        pcie_pmt_stop_en <= #TCQ 'd1;
end

reg [22-1:0] timeout_cnt = 'd0;  // 16.7ms
always @(posedge USER_CLK) begin
    if(pcie_pmt_stop_en)begin
        if(timeout_cnt[21])
            timeout_cnt <= #TCQ timeout_cnt;
        else
            timeout_cnt <= #TCQ timeout_cnt + 1;
    end
    else 
        timeout_cnt <= #TCQ 'd0;
end

assign wait_fbc_timeout  =  timeout_cnt[21];

assign pmt_start_pose   = pmt_start_en_d0 && (~pmt_start_en_d1);
assign eds_frame_pose   = eds_frame_en_d0 && (~eds_frame_en_d1);

always @(posedge USER_CLK) begin
    if(reset_c)
        tx_state <= #TCQ TX_IDLE;
    else if(pmt_start_pose || eds_frame_pose)
        tx_state <= #TCQ TX_IDLE;
    else 
        tx_state <= #TCQ tx_state_next;
end

always @(*) begin
    tx_state_next = tx_state;
    case(tx_state)
        TX_IDLE: begin
            if(eds_frame_en_d1)
                tx_state_next = TX_EDS_START;
            else if(pmt_start_en_d1)
                tx_state_next = TX_ENCODE_WITE;
        end 

        TX_EDS_START: begin
            if(tx_tlast && tx_tvalid && tx_tready_i)
                tx_state_next = TX_PCIE_WITE; 
        end

        TX_PCIE_WITE: begin
            if(eds_tx_delay_cnt=='d200)  //加延迟目的是给pcie光纤卡清buffer预留时间
                tx_state_next = TX_EDS_WITE;
        end

        TX_EDS_WITE: begin
            if(~eds_last_package)begin
                if(~eds_frame_en_d1)
                    tx_state_next = TX_EDS_END;
                else if((eds_rd_data_count_i >= 'd511) && (~eds_encode_empty_i))
                    tx_state_next = TX_EDS_DATA;
                else if(pcie_eds_frame_end_flag)
                    tx_state_next = TX_IDLE;
            end
            else begin
                if(pcie_eds_frame_end_flag)
                    tx_state_next = TX_IDLE;
                else if((eds_rd_data_count_i >= 'd511) && (~eds_encode_empty_i))
                    tx_state_next = TX_EDS_DATA;
            end
        end

        TX_EDS_END: begin
            if(tx_tlast && tx_tvalid && tx_tready_i)
                tx_state_next = TX_EDS_WITE; 
        end

        TX_EDS_DATA: begin
            if(tx_tlast && tx_tvalid && tx_tready_i)
                tx_state_next = TX_EDS_WITE; 
        end

        TX_ENCODE_WITE: begin
            if(pcie_pmt_stop_en)begin
                if((aurora_fbc_empty_i && aurora_fbc_end_i) || wait_fbc_timeout)
                    tx_state_next = TX_IDLE;
                else if(~aurora_fbc_empty_i) 
                    tx_state_next = TX_FBC_START;
            end
            else if(encode_rd_data_count_i >= 'd1023)
                tx_state_next = TX_ENCODE;
        end

        TX_ENCODE: begin
            if(tx_tlast && tx_tvalid && tx_tready_i)
                tx_state_next = TX_ENCODE_WITE; 
        end

        TX_FBC_START: begin
            if(tx_tlast && tx_tvalid && tx_tready_i)
                tx_state_next = TX_FBC_START_DELAY;
        end

        TX_FBC_START_DELAY: begin
            if(fbc_delay_cnt == 'd1000)
                tx_state_next = TX_FBC_WITE;
        end

        TX_FBC_WITE: begin
            if(~aurora_fbc_empty_i && aurora_fbc_end_i)
                tx_state_next = TX_FBC;
            else if(aurora_fbc_empty_i && aurora_fbc_end_i)
                tx_state_next = TX_FBC_END_DELAY;
            else if(aurora_fbc_count_i >= 'd1000)
                tx_state_next = TX_FBC;
        end

        TX_FBC: begin
            if(tx_tlast && tx_tvalid && tx_tready_i)begin
                if(aurora_fbc_end_i && aurora_fbc_empty_i)
                    tx_state_next = TX_FBC_END_DELAY;
                else 
                    tx_state_next = TX_FBC_WITE;
            end
        end

        TX_FBC_END_DELAY: begin
            if(fbc_delay_cnt == 'd1000)
                tx_state_next = TX_FBC_END;
        end

        TX_FBC_END: begin
            if(tx_tlast && tx_tvalid && tx_tready_i)
                tx_state_next = TX_IDLE;
        end

        default:tx_state_next = TX_IDLE;
    endcase
end

always @(posedge USER_CLK) begin
    if(tx_state==TX_PCIE_WITE)
        eds_tx_delay_cnt <= #TCQ eds_tx_delay_cnt + 1;
    else 
        eds_tx_delay_cnt <= #TCQ 'd0;
end

// fbc 开始前delay, 错开end的延迟
always @(posedge USER_CLK) begin
    if(tx_state==TX_FBC_START_DELAY || tx_state==TX_FBC_END_DELAY)
        fbc_delay_cnt <= #TCQ fbc_delay_cnt + 1;
    else 
        fbc_delay_cnt <= 'd0;
end

always @(posedge USER_CLK) begin
    if(tx_state==TX_IDLE)
        pcie_eds_frame_end_flag <= #TCQ 'd0;
    else if(pcie_eds_end_i)
        pcie_eds_frame_end_flag <= #TCQ 'd1;
end

always @(posedge USER_CLK) begin
    if(tx_state==TX_IDLE)
        eds_last_package <= #TCQ 'd0;
    else if(tx_state==TX_EDS_WITE && tx_state_next==TX_EDS_END)
        eds_last_package <= #TCQ 'd1;
end

// always @(posedge USER_CLK) begin
//     if(tx_state==TX_IDLE)
//         frame_cnt <= #TCQ 'd0;
//     else if(tx_state==TX_EDS_DATA && tx_tlast)
//         frame_cnt <= #TCQ frame_cnt + 1;
// end

always @(posedge USER_CLK) begin
    aurora_fbc_end_d    <= #TCQ aurora_fbc_end_i;
    aurora_fbc_empty_d  <= #TCQ aurora_fbc_empty_i;
end


wire tx_state_flag ;
assign tx_state_flag = tx_state==TX_EDS_START || tx_state==TX_EDS_DATA || tx_state==TX_EDS_END || tx_state==TX_ENCODE || tx_state==TX_FBC || tx_state==TX_FBC_START || tx_state==TX_FBC_END;

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
    case (tx_state)
        TX_EDS_START: begin
            if(tx_tvalid && tx_tready_i)begin
                if(len_cnt == 'd0) begin
                    tx_tdata <= #TCQ 'h55aa_0001;    
                end
                else if(len_cnt == 'd1) begin
                    tx_tdata <= #TCQ 'h0000_0001;    //EDS包开始
                end
            end
        end 

        TX_EDS_DATA: begin
            if(tx_tvalid && tx_tready_i)begin
                if(len_cnt == 'd0) begin
                    tx_tdata <= #TCQ 'h55aa_0002;    //EDS包数据帧类型
                end
                else if(len_cnt == 'd1) begin
                    tx_tdata <= #TCQ {precise_encode_w_data_i,precise_encode_x_data_i};        //x encoder
                end
                // else if(len_cnt == 'd2) begin
                //     tx_tdata <= #TCQ precise_encode_w_data_i;        //w encoder
                // end
                else begin
                    tx_tdata <= #TCQ eds_tx_data_i;
                end
            end
        end

        TX_EDS_END: begin
            if(tx_tvalid && tx_tready_i)begin
                if(len_cnt == 'd0) begin
                    tx_tdata <= #TCQ 'h55aa_0001;
                end
                else if(len_cnt == 'd1) begin
                    tx_tdata <= #TCQ 'h0000_0000;    //EDS包结束
                end
            end
        end

        TX_ENCODE: begin
            if(tx_tvalid && tx_tready_i)begin
                if(len_cnt == 'd0) begin
                    tx_tdata <= #TCQ 'h55aa_0003;
                end
                else begin
                    tx_tdata <= #TCQ encode_tx_data_i;        //encoder
                end
            end
        end

        TX_FBC: begin
            if(tx_tvalid && tx_tready_i)begin
                if(len_cnt == 'd0) begin
                    tx_tdata <= #TCQ 'h55aa_0004;
                end
                else if(aurora_fbc_empty_d)begin
                    tx_tdata <= #TCQ 'h0;
                end
                else begin
                    tx_tdata <= #TCQ aurora_fbc_data_i;
                end
            end
        end

        TX_FBC_START: begin
            if(tx_tvalid && tx_tready_i)begin
                if(len_cnt == 'd0) begin
                    tx_tdata <= #TCQ 'h55aa_0001;
                end
                else if(len_cnt == 'd1) begin
                    tx_tdata <= #TCQ 'h0000_0002;    //FBC包开始
                end
            end
        end

        TX_FBC_END: begin
            if(tx_tvalid && tx_tready_i)begin
                if(len_cnt == 'd0) begin
                    tx_tdata <= #TCQ 'h55aa_0001;
                end
                else if(len_cnt == 'd1) begin
                    tx_tdata <= #TCQ 'h0000_0003;    //FBC包结束
                end
            end
        end
        default: /*default*/;
    endcase
end

always @(posedge USER_CLK)
begin
    case (tx_state)
        TX_EDS_START: begin
            if(len_cnt == 'd1)
                tx_tlast <= #TCQ tx_tready_i && tx_tvalid;
            else if(tx_tlast && tx_tvalid && tx_tready_i)
                tx_tlast <= #TCQ 'd0;
        end
        TX_EDS_DATA: begin
            if(len_cnt == 'd513)
                tx_tlast <= #TCQ tx_tready_i && tx_tvalid;
            else if(tx_tlast && tx_tvalid && tx_tready_i)
                tx_tlast <= #TCQ 'd0;
        end
        TX_EDS_END: begin
            if(len_cnt == 'd1)
                tx_tlast <= #TCQ tx_tready_i && tx_tvalid;
            else if(tx_tlast && tx_tvalid && tx_tready_i)
                tx_tlast <= #TCQ 'd0;
        end
        TX_ENCODE: begin
            if(len_cnt == 'd1024)
                tx_tlast <= #TCQ tx_tready_i && tx_tvalid;
            else if(tx_tlast && tx_tvalid && tx_tready_i)
                tx_tlast <= #TCQ 'd0;
        end
        TX_FBC: begin
            if(len_cnt == 'd1024)
                tx_tlast <= #TCQ tx_tready_i && tx_tvalid;
            else if(tx_tlast && tx_tvalid && tx_tready_i)
                tx_tlast <= #TCQ 'd0;
        end
        TX_FBC_START: begin
            if(len_cnt == 'd1)
                tx_tlast <= #TCQ tx_tready_i && tx_tvalid;
            else if(tx_tlast && tx_tvalid && tx_tready_i)
                tx_tlast <= #TCQ 'd0;
        end
        TX_FBC_END: begin
            if(len_cnt == 'd1)
                tx_tlast <= #TCQ tx_tready_i && tx_tvalid;
            else if(tx_tlast && tx_tvalid && tx_tready_i)
                tx_tlast <= #TCQ 'd0;
        end
        default: tx_tlast <= #TCQ 1'b0;
    endcase
end   

always @(posedge USER_CLK) clear_eds_buffer     <= #TCQ (tx_state==TX_PCIE_WITE) && (eds_tx_delay_cnt<='d75);
always @(posedge USER_CLK) clear_encode_buffer  <= #TCQ (tx_state==TX_ENCODE_WITE) && pcie_pmt_stop_en;

assign eds_encode_en_o          = ((tx_state == TX_EDS_DATA) && (len_cnt == 'd0)) ? (tx_tready_i && tx_tvalid && (~tx_tlast)) : 1'b0;
assign eds_tx_en_o              = ((tx_state == TX_EDS_DATA) && (len_cnt >= 'd2)) ? (tx_tready_i && tx_tvalid && (~tx_tlast)) : 1'b0;
assign encode_tx_en_o           = ((tx_state == TX_ENCODE) && (len_cnt >= 'd1) ) ? (tx_tready_i && tx_tvalid && (~tx_tlast)) : 1'b0;
assign aurora_fbc_en_o          = ((tx_state == TX_FBC) && (len_cnt >= 'd1) ) ? (tx_tready_i && tx_tvalid && (~tx_tlast)) : 1'b0;

assign clear_eds_buffer_o       = clear_eds_buffer   ;
assign clear_encode_buffer_o    = clear_encode_buffer;

assign tx_tvalid_o              = tx_tvalid && (|len_cnt);
assign tx_tdata_o               = tx_tdata;  
assign tx_tkeep_o               = 8'hFF;
assign tx_tlast_o               = tx_tlast; 


// check eds pack number
reg [32-1:0] eds_pack_cnt = 'd0;
reg [32-1:0] encode_pack_cnt = 'd0;

always @(posedge USER_CLK) begin
    if(tx_state==TX_EDS_START)
        eds_pack_cnt <= #TCQ 'd0;
    else if(tx_state==TX_EDS_WITE && tx_state_next==TX_EDS_DATA)begin
        if(eds_pack_cnt[31])
            eds_pack_cnt <= #TCQ eds_pack_cnt;
        else 
            eds_pack_cnt <= #TCQ eds_pack_cnt + 1;
    end
end


always @(posedge USER_CLK) begin
    if(tx_state==TX_IDLE && pmt_start_en_d1)
        encode_pack_cnt <= #TCQ 'd0;
    else if(tx_state==TX_ENCODE_WITE && tx_state_next==TX_ENCODE)begin
        if(encode_pack_cnt[31])
            encode_pack_cnt <= #TCQ encode_pack_cnt;
        else 
            encode_pack_cnt <= #TCQ encode_pack_cnt + 1;
    end
end

assign eds_pack_cnt_o    = eds_pack_cnt;
assign encode_pack_cnt_o = encode_pack_cnt;
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


endmodule
