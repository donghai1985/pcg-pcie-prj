`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/06/21
// Design Name: songyuxin
// Module Name: mem_read_arbi
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module mem_read_arbi#(
    parameter                           TCQ             = 0.1   ,
    parameter                           MEM_DATA_BITS   = 256   ,
    parameter                           ADDR_WIDTH      = 30    
)(
    input                               ddr_rst_i               ,
    input                               ddr_clk_i               ,

    input                               ch0_rd_ddr_req          ,
    input       [8-1:0]                 ch0_rd_ddr_len          ,
    input       [ADDR_WIDTH-1:0]        ch0_rd_ddr_addr         ,
    output                              ch0_rd_ddr_data_valid   ,
    output      [MEM_DATA_BITS - 1:0]   ch0_rd_ddr_data         ,
    output                              ch0_rd_ddr_finish       ,
    
    input                               ch1_rd_ddr_req          ,
    input       [8-1:0]                 ch1_rd_ddr_len          ,
    input       [ADDR_WIDTH-1:0]        ch1_rd_ddr_addr         ,
    output                              ch1_rd_ddr_data_valid   ,
    output      [MEM_DATA_BITS - 1:0]   ch1_rd_ddr_data         ,
    output                              ch1_rd_ddr_finish       ,
    
    input                               ch2_rd_ddr_req          ,
    input       [8-1:0]                 ch2_rd_ddr_len          ,
    input       [ADDR_WIDTH-1:0]        ch2_rd_ddr_addr         ,
    output                              ch2_rd_ddr_data_valid   ,
    output      [MEM_DATA_BITS - 1:0]   ch2_rd_ddr_data         ,
    output                              ch2_rd_ddr_finish       ,
    
    input                               ch3_rd_ddr_req          ,
    input       [8-1:0]                 ch3_rd_ddr_len          ,
    input       [ADDR_WIDTH-1:0]        ch3_rd_ddr_addr         ,
    output                              ch3_rd_ddr_data_valid   ,
    output      [MEM_DATA_BITS - 1:0]   ch3_rd_ddr_data         ,
    output                              ch3_rd_ddr_finish       ,

    output reg                          rd_ddr_req              ,
    output reg  [8-1:0]                 rd_ddr_len              ,
    output reg  [ADDR_WIDTH-1:0]        rd_ddr_addr             ,
    input                               rd_ddr_data_valid       ,
    input       [MEM_DATA_BITS - 1:0]   rd_ddr_data             ,
    input                               rd_ddr_finish               
);

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Parameter Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

localparam                              IDLE        = 6'd0;

localparam                              CH0_CHECK   = 6'd1;
localparam                              CH0_BEGIN   = 6'd2;
localparam                              CH0_READ    = 6'd3;
localparam                              CH0_END     = 6'd4;

localparam                              CH1_CHECK   = 6'd5;
localparam                              CH1_BEGIN   = 6'd6;
localparam                              CH1_READ    = 6'd7;
localparam                              CH1_END     = 6'd8;

localparam                              CH2_CHECK   = 6'd9;
localparam                              CH2_BEGIN   = 6'd10;
localparam                              CH2_READ    = 6'd11;
localparam                              CH2_END     = 6'd12;

localparam                              CH3_CHECK   = 6'd13;
localparam                              CH3_BEGIN   = 6'd14;
localparam                              CH3_READ    = 6'd15;
localparam                              CH3_END     = 6'd16;

//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Register Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
reg     [5:0]                           read_state      = IDLE;
reg     [5:0]                           read_state_next = IDLE;
reg     [15:0]                          cnt_timer       = 'd0;

reg                                     rd_ddr_finish_d0;
reg                                     rd_ddr_finish_d1;
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Wire Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>



//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Instance Module
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


//////////////////////////////////////////////////////////////////////////////////
// *********** Logic Design
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
always@(posedge ddr_clk_i)
begin
    rd_ddr_finish_d0 <= #TCQ rd_ddr_finish;
    rd_ddr_finish_d1 <= #TCQ rd_ddr_finish_d0;
end

always@(posedge ddr_clk_i)
begin
    if(ddr_rst_i)
        read_state <= #TCQ IDLE;
    else if(cnt_timer > 'd8000)
        read_state <= #TCQ IDLE;
    else
        read_state <= #TCQ read_state_next;
end

// once burst timeout check
always@(posedge ddr_clk_i)
begin
    if(read_state==IDLE)
        cnt_timer <= #TCQ 'd0;
    else if(read_state == CH0_CHECK || read_state == CH1_CHECK || read_state == CH2_CHECK || read_state == CH3_CHECK )
        cnt_timer <= #TCQ 'd0;
    else
        cnt_timer <= #TCQ cnt_timer + 'd1;
end

always@(*)
begin
    read_state_next = read_state;
    case(read_state)
        IDLE:
            read_state_next = CH0_CHECK;
        // channel 0
        CH0_CHECK:
            if(ch0_rd_ddr_req && ch0_rd_ddr_len != 'd0)
                read_state_next = CH0_BEGIN;
            else
                read_state_next = CH1_CHECK;
        CH0_BEGIN:
            read_state_next = CH0_READ;
        CH0_READ:
            if(rd_ddr_finish_d1)
                read_state_next = CH0_END;
            else
                read_state_next = CH0_READ;
        CH0_END:
            read_state_next = CH1_CHECK;
        // channel 1
        CH1_CHECK:
            if(ch1_rd_ddr_req && ch1_rd_ddr_len != 'd0)
                read_state_next = CH1_BEGIN;
            else
                read_state_next = CH2_CHECK;
        CH1_BEGIN:
            read_state_next = CH1_READ;
        CH1_READ:
            if(rd_ddr_finish_d1)
                read_state_next = CH1_END;
            else
                read_state_next = CH1_READ;
        CH1_END:
            read_state_next = CH2_CHECK;
        // channel 2
        CH2_CHECK:
            if(ch2_rd_ddr_req  && ch2_rd_ddr_len != 'd0)
                read_state_next = CH2_BEGIN;
            else
                read_state_next = CH3_CHECK;
        CH2_BEGIN:
            read_state_next = CH2_READ;
        CH2_READ:
            if(rd_ddr_finish_d1)
                read_state_next = CH2_END;
            else
                read_state_next = CH2_READ;
        CH2_END:
            read_state_next = CH3_CHECK;
        // channel 3
        CH3_CHECK:
            if(ch3_rd_ddr_req  && ch3_rd_ddr_len != 'd0)
                read_state_next = CH3_BEGIN;
            else
                read_state_next = CH0_CHECK;
        CH3_BEGIN:
            read_state_next = CH3_READ;
        CH3_READ:
            if(rd_ddr_finish_d1)
                read_state_next = CH3_END;
            else
                read_state_next = CH3_READ;
        CH3_END:
            read_state_next = CH0_CHECK;        
        default:
            read_state_next = IDLE;
    endcase
end

always@(posedge ddr_clk_i)begin
    case(read_state)
        CH0_BEGIN:
            begin
                rd_ddr_len  <= #TCQ ch0_rd_ddr_len;
                rd_ddr_addr <= #TCQ ch0_rd_ddr_addr;
            end
        CH1_BEGIN:
            begin
                rd_ddr_len  <= #TCQ ch1_rd_ddr_len;
                rd_ddr_addr <= #TCQ ch1_rd_ddr_addr;
            end
        CH2_BEGIN:
            begin
                rd_ddr_len  <= #TCQ ch2_rd_ddr_len;
                rd_ddr_addr <= #TCQ ch2_rd_ddr_addr;
            end
        CH3_BEGIN:
            begin
                rd_ddr_len  <= #TCQ ch3_rd_ddr_len;
                rd_ddr_addr <= #TCQ ch3_rd_ddr_addr;
            end
        default:/*default*/;
    endcase
end

always@(posedge ddr_clk_i)
begin
    if(read_state==IDLE)
        rd_ddr_req <= #TCQ 1'b0;
    else if(read_state == CH0_BEGIN || read_state == CH1_BEGIN || read_state == CH2_BEGIN || read_state == CH3_BEGIN)
        rd_ddr_req <= #TCQ 1'b1;
    else if(rd_ddr_data_valid)  // ddr respond, generate read valid.
        rd_ddr_req <= #TCQ 1'b0;
    else
        rd_ddr_req <= #TCQ rd_ddr_req;
end

assign ch0_rd_ddr_finish = (read_state == CH0_END);
assign ch1_rd_ddr_finish = (read_state == CH1_END);
assign ch2_rd_ddr_finish = (read_state == CH2_END);
assign ch3_rd_ddr_finish = (read_state == CH3_END);

assign ch0_rd_ddr_data_valid = (read_state == CH0_READ) ? rd_ddr_data_valid : 1'b0;
assign ch1_rd_ddr_data_valid = (read_state == CH1_READ) ? rd_ddr_data_valid : 1'b0;
assign ch2_rd_ddr_data_valid = (read_state == CH2_READ) ? rd_ddr_data_valid : 1'b0;
assign ch3_rd_ddr_data_valid = (read_state == CH3_READ) ? rd_ddr_data_valid : 1'b0;

assign ch0_rd_ddr_data = (read_state == CH0_READ) ? rd_ddr_data : {MEM_DATA_BITS{1'd0}};
assign ch1_rd_ddr_data = (read_state == CH1_READ) ? rd_ddr_data : {MEM_DATA_BITS{1'd0}};
assign ch2_rd_ddr_data = (read_state == CH2_READ) ? rd_ddr_data : {MEM_DATA_BITS{1'd0}};
assign ch3_rd_ddr_data = (read_state == CH3_READ) ? rd_ddr_data : {MEM_DATA_BITS{1'd0}};
endmodule 