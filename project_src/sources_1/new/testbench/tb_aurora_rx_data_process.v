//~ `New testbench
`timescale  1ns / 1ps

module tb_aurora_rx_data_process;

// aurora_rx_data_process Parameters
parameter PERIOD  = 10;


// aurora_rx_data_process Inputs
reg   aurora_log_clk_0                     = 0 ;
reg   aurora_rst_0                         = 0 ;
reg   pmt_aurora_rxen_i                    = 0 ;
reg   [31:0]  pmt_aurora_rxdata_i          = 0 ;
reg   eds_rx_start_i                       = 0 ;
reg   fbc_rx_start_i                       = 0 ;
reg   pmt_rx_start_i                       = 0 ;
reg   aurora_log_clk_1                     = 0 ;
reg   aurora_rst_1                         = 0 ;
reg   eds_aurora_rxen_i                    = 0 ;
reg   [63:0]  eds_aurora_rxdata_i          = 0 ;
reg   pmt_encode_en_i                      = 0 ;
reg   [63:0]  pmt_encode_data_i            = 0 ;

// aurora_rx_data_process Outputs
wire  [31:0]  pmt_overflow_cnt_o           ;
wire  [31:0]  encode_overflow_cnt_o        ;
wire  xdma_vin_mem_clear_o                 ;
wire  aurora_rxen                          ;
wire  [63:0]  aurora_rxdata                ;


initial
begin
    forever #(4)  aurora_log_clk_0=~aurora_log_clk_0;
end


initial
begin
    forever #(3.333)  aurora_log_clk_1=~aurora_log_clk_1;
end

initial
begin
    #(PERIOD*2) aurora_rst_0  =  1;
    #(PERIOD*2) aurora_rst_0  =  0;
end


initial
begin
    #(PERIOD*2) aurora_rst_1  =  1;
    #(PERIOD*2) aurora_rst_1  =  0;
end

wire xdma_vin_mem_clear;

aurora_rx_data_process  u_aurora_rx_data_process (
    .aurora_log_clk_0        ( aurora_log_clk_0              ),
    .aurora_rst_0            ( aurora_rst_0                  ),
    .pmt_aurora_rxen_i       ( pmt_aurora_rxen_i             ),
    .pmt_aurora_rxdata_i     ( pmt_aurora_rxdata_i    [31:0] ),
    .eds_rx_start_i          ( eds_rx_start_i                ),
    .fbc_rx_start_i          ( fbc_rx_start_i                ),
    .pmt_rx_start_i          ( pmt_rx_start_i                ),
    .aurora_log_clk_1        ( aurora_log_clk_1              ),
    .aurora_rst_1            ( aurora_rst_1                  ),
    .eds_aurora_rxen_i       ( eds_aurora_rxen_i             ),
    .eds_aurora_rxdata_i     ( eds_aurora_rxdata_i    [63:0] ),
    .pmt_encode_en_i         ( pmt_encode_en_i               ),
    .pmt_encode_data_i       ( pmt_encode_data_i      [63:0] ),

    .pmt_overflow_cnt_o      ( pmt_overflow_cnt_o     [31:0] ),
    .encode_overflow_cnt_o   ( encode_overflow_cnt_o  [31:0] ),
    .xdma_vin_mem_clear_o    ( xdma_vin_mem_clear            ),
    .aurora_rxen             ( aurora_rxen                   ),
    .aurora_rxdata           ( aurora_rxdata          [63:0] )
);

always @(posedge aurora_log_clk_0) begin
    if(pmt_rx_start_i)begin
        pmt_aurora_rxen_i <= #0.1 'd1;
        pmt_aurora_rxdata_i <= #0.1 pmt_aurora_rxdata_i + 1;
    end
    else begin
        pmt_aurora_rxen_i <= #0.1 'd0;
    end
end

always @(posedge aurora_log_clk_1) begin
    if(pmt_rx_start_i)begin
        pmt_encode_en_i   <= #0.1 'd1;
        pmt_encode_data_i <= #0.1 pmt_encode_data_i + 1;
    end
    else begin
        pmt_encode_en_i <=  #0.1 'd0;
    end
end

always @(posedge aurora_log_clk_1) begin
    if(eds_rx_start_i)begin
        eds_aurora_rxen_i   <= #0.1 'd1;
        eds_aurora_rxdata_i <= #0.1 eds_aurora_rxdata_i + 1;
    end
    else begin
        eds_aurora_rxen_i <= #0.1 'd0;
    end
end

reg [2:0] temp_ddr_wr_cnt = 'd0;
always @(posedge aurora_log_clk_0) begin
    if(aurora_rst_0)
        temp_ddr_wr_cnt <= #0.1 'd0;
    else if(xdma_vin_mem_clear)
        temp_ddr_wr_cnt <= #0.1 'd0;
    else if(aurora_rxen)
        temp_ddr_wr_cnt <= #0.1 temp_ddr_wr_cnt + 1;
end

reg temp_ddr_wr_en = 'd0;
always @(posedge aurora_log_clk_0) begin
    if(aurora_rst_0)
        temp_ddr_wr_en <= #0.1 'd0;
    else if(xdma_vin_mem_clear)
        temp_ddr_wr_en <= #0.1 'd0;
    else if((&temp_ddr_wr_cnt) && aurora_rxen)
        temp_ddr_wr_en <= #0.1 'd1;
    else 
        temp_ddr_wr_en <= #0.1 'd0;
end

reg [511:0] temp_ddr_wr_data = 'd0;
always @(posedge aurora_log_clk_0) begin
    if(aurora_rxen)
        temp_ddr_wr_data <= #0.1 {aurora_rxdata,temp_ddr_wr_data[511:64]};
end


endmodule