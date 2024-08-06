
###############################################################################
# Timing Constraints
###############################################################################

create_clock -period 10.000 -name sys_clk [get_ports pcie_sys_clk_p]
create_clock -period 10.000 -name FPGA_MASTER_CLOCK [get_ports FPGA_MASTER_CLOCK_P]
create_clock -period 10.000 -name gtrefclk0_in [get_ports GTXQ2_0_P]
#create_clock -period 10.000 -name gtrefclk1_in [get_ports GTXQ2_1_P]

# set_clock_groups -asynchronous -group [get_clocks gtrefclk0_in -include_generated_clocks]
#set_clock_groups -asynchronous -group [get_clocks gtrefclk1_in -include_generated_clocks]
set_clock_groups -name async_clk_group -asynchronous -group [get_clocks gtrefclk0_in -include_generated_clocks] -group [get_clocks FPGA_MASTER_CLOCK -include_generated_clocks] -group [get_clocks sys_clk -include_generated_clocks]

set_false_path -from [get_pins {aurora_64b66b_exdes_inst_1/xpm_cdc_rx_signal_inst/syncstages_ff_reg[1][0]/C}] -to [get_pins aurora_rx_data_process_inst/pmt_rx_start_d0_reg/D]
set_false_path -from [get_clocks -of_objects [get_pins clk_pll_inst/inst/mmcm_adv_inst/CLKOUT2]] -to [get_clocks -of_objects [get_pins aurora_64b66b_exdes_inst_1/aurora_64b66b_0_block_i/clock_module_i/mmcm_adv_inst/CLKOUT0]]
set_false_path -from [get_clocks -of_objects [get_pins aurora_64b66b_exdes_inst_1/aurora_64b66b_0_block_i/clock_module_i/mmcm_adv_inst/CLKOUT0]] -to [get_clocks -of_objects [get_pins xdma_0_inst/inst/xdma_0_pcie2_to_pcie3_wrapper_i/pcie2_ip_i/inst/inst/gt_top_i/pipe_wrapper_i/pipe_clock_int.pipe_clock_i/mmcm_i/CLKOUT3]]
set_false_path -from [get_clocks aurora_8b10b_exdes_inst_0/aurora_module_i/aurora_8b10b_0_i/inst/gt_wrapper_i/aurora_8b10b_0_multi_gt_i/gt0_aurora_8b10b_0_i/gtxe2_i/TXOUTCLK] -to [get_clocks -of_objects [get_pins xdma_0_inst/inst/xdma_0_pcie2_to_pcie3_wrapper_i/pcie2_ip_i/inst/inst/gt_top_i/pipe_wrapper_i/pipe_clock_int.pipe_clock_i/mmcm_i/CLKOUT3]]


