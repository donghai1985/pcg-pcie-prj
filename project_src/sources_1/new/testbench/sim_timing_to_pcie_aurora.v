`timescale 1 ns / 1 ps

module sim_timing_to_pcie_aurora #(
    parameter           TCQ                     = 0.1
)(
    input               aurora_clk_i            ,
    input               aurora_rst_i            ,

    input               adc_start_i             ,
    input               pcie_adc_end_i          ,

    output              eds_rx_start_o          ,
    output              eds_rx_end_o            ,
    output              eds_aurora_rxen_o       ,
    output  [64-1:0]    eds_aurora_rxdata_o     ,
    output              fbc_rx_start_o          ,
    output              fbc_rx_end_o            ,
    output              encoder_rxen_o          ,
    output  [64-1:0]    encoder_rxdata_o        ,

    input               sys_clk_i               

);

wire    [31:0]      tx_tdata;
wire                tx_tvalid;
wire                tx_tready;
wire    [3:0]       tx_tkeep;
wire                tx_tlast;


wire       encode_tx_en ;
reg     [63:0]  encode_tx_data = 'd0;
always @(posedge aurora_clk_i) begin
    if(encode_tx_en)
        encode_tx_data <= #TCQ encode_tx_data + 1;

end     


sim_aurora_64b66b_tx sim_aurora_64b66b_tx_inst(
    // eds
    .eds_frame_en_i             ( 0             ),
    .pcie_eds_end_i             ( 0                  ),
    .eds_tx_en_o                ( eds_tx_en                     ),
    .eds_tx_data_i              ( 0                   ),
    .eds_rd_data_count_i        ( 0             ),
    .clear_eds_buffer_o         ( clear_eds_buffer              ),

    .eds_encode_empty_i         ( 1              ),
    .eds_encode_en_o            ( eds_encode_rd_en              ),
    .precise_encode_w_data_i    ( 0         ),
    .precise_encode_x_data_i    ( 0         ),

    // pmt encode
    .pmt_start_en_i             ( adc_start_i                   ),
    .pcie_pmt_end_i             ( pcie_adc_end_i                ),
    
    .encode_tx_en_o             ( encode_tx_en                  ),
    .encode_tx_data_i           ( encode_tx_data                ),
    .encode_rd_data_count_i     ( 12'd1500                      ),
    .clear_encode_buffer_o      ( clear_encode_buffer           ),

    // FBC 
    .aurora_fbc_en_o            ( aurora_fbc_en                 ),
    .aurora_fbc_data_i          ( aurora_fbc_data               ),
    .aurora_fbc_count_i         ( aurora_fbc_count              ),
    .aurora_fbc_end_i           ( 1                ),
    .aurora_fbc_empty_i         ( 1       ),

    .eds_pack_cnt_o             ( eds_pack_cnt                  ),
    .encode_pack_cnt_o          ( encode_pack_cnt               ),
    
    // System Interface
    .USER_CLK                   ( aurora_clk_i                  ),
    .RESET                      ( aurora_rst_i                  ),
    .CHANNEL_UP                 ( 'd1                           ),
    
    .tx_tvalid_o                ( tx_tvalid                     ),
    .tx_tdata_o                 ( tx_tdata                      ),
    .tx_tkeep_o                 ( tx_tkeep                      ),
    .tx_tlast_o                 ( tx_tlast                      ),
    .tx_tready_i                ( 1                     )
);

aurora_64b66b_rx aurora_64b66b_rx_inst(
    // eds
    .eds_rx_start_o             ( eds_rx_start                  ),
    .eds_rx_end_o               ( eds_rx_end                    ),
    .eds_aurora_rxen_o          ( eds_aurora_rxen_o             ),
    .eds_aurora_rxdata_o        ( eds_aurora_rxdata_o           ),
    // fbc
    .fbc_rx_start_o             ( fbc_rx_start                  ),
    .fbc_rx_end_o               ( fbc_rx_end                    ),
    // pmt encode
    .encoder_rxen_o             ( encoder_rxen_o                ), 
    .encoder_rxdata_o           ( encoder_rxdata_o              ), 
    
    // System Interface
    .USER_CLK                   ( aurora_clk_i                  ),      
    .RESET                      ( aurora_rst_i                  ),
    .CHANNEL_UP                 ( 'd1                           ),

    .rx_tvalid_i                ( tx_tvalid                     ),
    .rx_tdata_i                 ( tx_tdata                      ),
    .rx_tkeep_i                 ( tx_tkeep                      ),
    .rx_tlast_i                 ( tx_tlast                      )
);

xpm_cdc_array_single #(
    .DEST_SYNC_FF(2),   // DECIMAL; range: 2-10
    .INIT_SYNC_FF(0),   // DECIMAL; 0=disable simulation init values, 1=enable simulation init values
    .SIM_ASSERT_CHK(0), // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
    .SRC_INPUT_REG(1),  // DECIMAL; 0=do not register input, 1=register input
    .WIDTH(4)           // DECIMAL; range: 1-1024
 )
 xpm_cdc_rx_signal_inst (
    .dest_out({
        eds_rx_start_o
       ,eds_rx_end_o  
       ,fbc_rx_start_o
       ,fbc_rx_end_o  
   }), // WIDTH-bit output: src_in synchronized to the destination clock domain. This
                         // output is registered.

    .dest_clk(sys_clk_i), // 1-bit input: Clock signal for the destination clock domain.
    .src_clk(aurora_clk_i),   // 1-bit input: optional; required when SRC_INPUT_REG = 1
    .src_in({
             eds_rx_start
            ,eds_rx_end  
            ,fbc_rx_start
            ,fbc_rx_end  
        })      // WIDTH-bit input: Input single-bit array to be synchronized to destination clock
                         // domain. It is assumed that each bit of the array is unrelated to the others. This
                         // is reflected in the constraints applied to this macro. To transfer a binary value
                         // losslessly across the two clock domains, use the XPM_CDC_GRAY macro instead.

 );

endmodule