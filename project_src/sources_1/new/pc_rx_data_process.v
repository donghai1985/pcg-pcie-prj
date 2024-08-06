`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2022/08/22 10:32:24
// Design Name: 
// Module Name: pc_rx_data_process
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


module pc_rx_data_process(

	input	wire		pcie_clk_250m,
	input	wire		rst,
	
	output	wire		fifo_data_P2L_en,
	input	wire[127:0]	fifo_data_P2L,
	input	wire		fifo_data_P2L_emp
    
);

assign		fifo_data_P2L_en	=	~fifo_data_P2L_emp;

endmodule
