`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/06/21
// Design Name: songyuxin
// Module Name: mem_write_arbi
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
module mem_write_arbi#(
    parameter                           TCQ             = 0.1,
    parameter                           MEM_DATA_BITS   = 256,
    parameter                           ADDR_WIDTH      = 30
)(
    input                               ddr_rst_i               ,
    input                               ddr_clk_i               ,
    
    input                               ch0_wr_ddr_req          ,
    input       [8-1:0]                 ch0_wr_ddr_len          ,
    input       [ADDR_WIDTH-1:0]        ch0_wr_ddr_addr         ,
    output                              ch0_wr_ddr_data_req     ,
    input       [MEM_DATA_BITS - 1:0]   ch0_wr_ddr_data         ,
    output                              ch0_wr_ddr_finish       ,
    
    output reg                          wr_ddr_req              ,
    output reg  [8-1:0]                 wr_ddr_len              ,
    output reg  [ADDR_WIDTH-1:0]        wr_ddr_addr             ,
    input                               wr_ddr_data_req         ,
    
    output reg  [MEM_DATA_BITS - 1:0]   wr_ddr_data             ,
    input                               wr_ddr_finish            
);


//////////////////////////////////////////////////////////////////////////////////
// *********** Define Parameter Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
localparam                              IDLE         = 6'd0;
localparam                              CH0_CHECK    = 6'd1;
localparam                              CH0_BEGIN    = 6'd2;
localparam                              CH0_WRITE    = 6'd3;
localparam                              CH0_END      = 6'd4;

//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

//////////////////////////////////////////////////////////////////////////////////
// *********** Define Register Signal
//>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
reg     [5:0]                           write_state         = 6'd0;
reg     [5:0]                           write_state_next    = 6'd0;
reg     [15:0]                          cnt_timer           = 16'd0;

reg                                     wr_ddr_finish_d0;
reg                                     wr_ddr_finish_d1;

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
    wr_ddr_finish_d0 <= #TCQ wr_ddr_finish;
    wr_ddr_finish_d1 <= #TCQ wr_ddr_finish_d0;
end

always@(posedge ddr_clk_i)
begin
    if(ddr_rst_i)
        write_state <= #TCQ IDLE;
    else if(cnt_timer > 16'd8000)
        write_state <= #TCQ IDLE;
    else
        write_state <= #TCQ write_state_next;
end

// once burst timeout check
always@(posedge ddr_clk_i)
begin
    if(write_state==IDLE)
        cnt_timer <= #TCQ 16'd0;
    else if(write_state == CH0_CHECK)
        cnt_timer <= #TCQ 16'd0;
    else
        cnt_timer <= #TCQ cnt_timer + 16'd1;
end

always@(*)
begin
    write_state_next = write_state;
    case(write_state)
        IDLE:
            write_state_next = CH0_CHECK;
        CH0_CHECK:
            if(ch0_wr_ddr_req  && ch0_wr_ddr_len != 'd0) 
                write_state_next = CH0_BEGIN;
            else
                write_state_next = CH0_CHECK;
        CH0_BEGIN:
            write_state_next = CH0_WRITE;
        CH0_WRITE:
            if(wr_ddr_finish_d1)
                write_state_next = CH0_END;
            else
                write_state_next = CH0_WRITE;
        CH0_END:
            write_state_next = IDLE;
        default:
            write_state_next = IDLE;
    endcase
end

always@(posedge ddr_clk_i )begin
    case(write_state)
        CH0_BEGIN:
            begin
                wr_ddr_len  <= #TCQ ch0_wr_ddr_len;
                wr_ddr_addr <= #TCQ ch0_wr_ddr_addr;
            end                
        default:/*default*/;
    endcase
end

always@(posedge ddr_clk_i )
begin
    if(write_state==IDLE)
        wr_ddr_req <= #TCQ 1'b0;
    else if(write_state == CH0_BEGIN)
        wr_ddr_req <= #TCQ 1'b1;
    else if(wr_ddr_data_req) // ddr respond, generate write enable.
        wr_ddr_req <= #TCQ 1'b0;
end

always@(*)
begin
    case(write_state)
        CH0_WRITE:
            wr_ddr_data <= #TCQ ch0_wr_ddr_data;
        default:
            wr_ddr_data <= #TCQ {MEM_DATA_BITS{1'd0}};
    endcase
end

assign ch0_wr_ddr_finish = (write_state == CH0_END);

assign ch0_wr_ddr_data_req = (write_state == CH0_WRITE) ? wr_ddr_data_req : 1'b0; 
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


endmodule 