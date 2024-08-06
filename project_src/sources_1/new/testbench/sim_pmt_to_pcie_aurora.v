`timescale 1 ns / 1 ps

module sim_pmt_to_pcie_aurora #(
    parameter                   TCQ             = 0.1
)(
    input           aurora_clk_i            ,
    input           aurora_rst_i            ,

    input           adc_start_i             ,
    input           pcie_adc_end_i          ,

    output          pmt_aurora_rxen_o       ,
    output  [31:0]  pmt_aurora_rxdata_o     ,

    output          pmt_rx_start_o          ,
    output          pmt_rx_end_o            

);

wire    [31:0]      tx_data;
wire                tx_tvalid;
wire                tx_tready;
wire    [3:0]       tx_tkeep;
wire                tx_tlast;

wire    [31:0]      rx_data;
wire                rx_tvalid;
wire    [3:0]       rx_tkeep;
wire                rx_tlast;

wire                aurora_txen;
reg     [31:0]      aurora_txdata           = 'd0;
reg     [15:0]      aurora_rd_data_count    = 'd0;


always @(posedge aurora_clk_i) begin
    if(aurora_rst_i)begin
        aurora_txdata        <= #TCQ 'd0;
    end
    else if(aurora_txen)begin
        aurora_txdata        <= #TCQ aurora_txdata        + 1;
    end 
end

always @(posedge aurora_clk_i) begin
    if(aurora_rst_i)begin
        aurora_rd_data_count <= #TCQ 'd0;
    end
    else if(adc_start_i)begin
        aurora_rd_data_count <= #TCQ aurora_rd_data_count + 1;
    end 
end



sim_pmt_aurora_tx sim_pmt_aurora_tx_inst(
    // User Interface
    .aurora_txen                ( aurora_txen               ),	
    .aurora_txdata              ( aurora_txdata             ),	
    .aurora_rd_data_count       ( aurora_rd_data_count[10:0]),
    .adc_start                  ( adc_start_i               ),
    .adc_end                    ( pcie_adc_end_i            ),

    // System Interface
    .USER_CLK                   ( aurora_clk_i              ),      
    .RESET                      ( aurora_rst_i              ),
    .CHANNEL_UP                 ( 'd1                       ),
    .tx_tvalid                  ( tx_tvalid                 ),
    .tx_data                    ( tx_data                   ),
    .tx_tkeep                   ( tx_tkeep                  ),
    .tx_tlast                   ( tx_tlast                  ),
    .tx_tready                  ( 1                 )
);

aurora_8b10b_0_FRAME_RX frame_rx_i
(
    // User Interface
    .pmt_aurora_rxen_o          ( pmt_aurora_rxen_o         ),	
    .pmt_aurora_rxdata_o        ( pmt_aurora_rxdata_o       ),	
    .pmt_rx_start_o             ( pmt_rx_start_o            ),
    .pmt_rx_end_o               ( pmt_rx_end_o              ),

    // System Interface
    .USER_CLK                   ( aurora_clk_i              ),      
    .RESET                      ( aurora_rst_i              ),
    .CHANNEL_UP                 ( 'd1                       ),

    .rx_tvalid                  ( tx_tvalid                 ),
    .rx_data                    ( tx_data                   ),
    .rx_tkeep                   ( tx_tkeep                  ),
    .rx_tlast                   ( tx_tlast                  )
);



endmodule