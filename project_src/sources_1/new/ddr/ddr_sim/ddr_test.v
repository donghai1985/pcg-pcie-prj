`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: zas
// Engineer: songyuxin
// 
// Create Date: 2023/08/25
// Design Name: PCG
// Module Name: xdma_vout_ctrl
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


module ddr_test #(
    parameter                               TCQ                 = 0.1           ,  
    parameter                               ADDR_WIDTH          = 28            ,
    parameter                               MEM_DATA_BITS       = 512           ,
    parameter                               BURST_LEN           = 64            
)(
    // clk & rst 
    input                                   ddr_clk_i               ,
    input                                   ddr_rst_i               ,
    
    output                                  wr_ddr_req_o            ,
    output      [ 8-1:0]                    wr_ddr_len_o            ,
    output      [ADDR_WIDTH-1:0]            wr_ddr_addr_o           ,
    input                                   ddr_fifo_rd_req_i       ,
    output      [MEM_DATA_BITS - 1:0]       wr_ddr_data_o           ,
    input                                   wr_ddr_finish_i         ,

    output                                  rd_ddr_req_o            ,  
    output      [ 8-1:0]                    rd_ddr_len_o            ,
    output      [ADDR_WIDTH-1:0]            rd_ddr_addr_o           ,
    input                                   rd_ddr_data_valid_i     ,
    input       [MEM_DATA_BITS - 1:0]       rd_ddr_data_i           ,
    input                                   rd_ddr_finish_i          
    
);

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Parameter Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
localparam                          ST_IDLE                 = 3'd0;
localparam                          ST_WRITE                = 3'd1;
localparam                          ST_READ                 = 3'd2;
localparam                          ST_END                  = 3'd3;
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Register Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
reg     [3-1:0]         state       = ST_IDLE;
reg     [3-1:0]         state_next  = ST_IDLE;


reg                                 wr_ddr_req              = 'd0; 
reg     [ 8-1:0]                    wr_ddr_len              = BURST_LEN; 
reg     [19-1:0]                    wr_burst_line           = 'd0;
reg     [ADDR_WIDTH-1:0]            wr_ddr_addr             = 'd0;
reg     [MEM_DATA_BITS - 1:0]       wr_ddr_data             = 'd0;

reg                                 rd_ddr_req              = 'd0; 
reg     [ 8-1:0]                    rd_ddr_len              = BURST_LEN; 
reg     [19-1:0]                    rd_burst_line           = 'd0;
reg     [ADDR_WIDTH-1:0]            rd_ddr_addr             = 'd0;
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Wire Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

wire vio_st_rst     ;
wire vio_ddr_test_en;




//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Logic Design
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

ddr_test_vio your_instance_name (
  .clk(ddr_clk_i),                // input wire clk
  .probe_out0(vio_st_rst     ),  // output wire [0 : 0] probe_out0
  .probe_out1(vio_ddr_test_en)  // output wire [0 : 0] probe_out1
);


always @(posedge ddr_clk_i) begin
    if(ddr_rst_i)
        state <= #TCQ ST_IDLE;
    else if(vio_st_rst)
        state <= #TCQ ST_IDLE;
    else
        state <= #TCQ state_next;
end

always @(*) begin
    state_next = state;
    case (state)
        ST_IDLE: begin
            if(vio_ddr_test_en)
                state_next = ST_WRITE; 
        end

        ST_WRITE: begin
            if(wr_ddr_finish_i)
                state_next = ST_READ;
        end

        ST_READ: begin
            if(rd_ddr_finish_i)
                state_next = ST_END;
        end

        ST_END: begin
            state_next = ST_IDLE;
        end
        default: state_next = ST_IDLE;
    endcase
end


always @(posedge ddr_clk_i) begin
    if(~vio_ddr_test_en)
        wr_ddr_req <= #TCQ 'd0;
    else if(state==ST_IDLE && state_next==ST_WRITE)
        wr_ddr_req <= #TCQ 'd1;
    else if(ddr_fifo_rd_req_i || wr_ddr_finish_i)
        wr_ddr_req <= #TCQ 'd0;
end

always @(posedge ddr_clk_i) begin
    if(~vio_ddr_test_en)
        wr_burst_line <= #TCQ 'd0;
    else if(state==ST_IDLE && state_next==ST_WRITE)
        wr_burst_line <= #TCQ wr_burst_line + 1;
end

always@(posedge ddr_clk_i)begin
    wr_ddr_addr <= #TCQ {wr_burst_line[19-1:0],9'd0};  // 通过burst line控制突发首地址, 共8MBytes
end

always @(posedge ddr_clk_i) begin
    if(~vio_ddr_test_en)
        wr_ddr_data <= #TCQ 'd0;
    else if(state==ST_WRITE)begin
        if(ddr_fifo_rd_req_i)
            wr_ddr_data <= #TCQ wr_ddr_data + 1;
    end
end

assign wr_ddr_req_o     =  wr_ddr_req; 
assign wr_ddr_len_o     =  wr_ddr_len; 
assign wr_ddr_addr_o    =  wr_ddr_addr;
assign wr_ddr_data_o    =  wr_ddr_data;


always @(posedge ddr_clk_i) begin
    if(~vio_ddr_test_en)
        rd_ddr_req <= #TCQ 'd0;
    else if(state==ST_WRITE && state_next==ST_READ)
        rd_ddr_req <= #TCQ 'd1;
    else if(rd_ddr_data_valid_i || rd_ddr_finish_i || state==ST_IDLE)
        rd_ddr_req <= #TCQ 'd0;
end

always @(posedge ddr_clk_i) begin
    if(~vio_ddr_test_en)
        rd_burst_line <= #TCQ 'd0;
    else if(state==ST_WRITE && state_next==ST_READ)
        rd_burst_line <= #TCQ rd_burst_line + 1;
end

always@(posedge ddr_clk_i)begin
    rd_ddr_addr <= #TCQ {rd_burst_line[19-1:0],9'd0};  // 通过burst line控制突发首地址, 共8MBytes
end

assign rd_ddr_req_o     =  rd_ddr_req; 
assign rd_ddr_len_o     =  rd_ddr_len; 
assign rd_ddr_addr_o    =  rd_ddr_addr;
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


endmodule
