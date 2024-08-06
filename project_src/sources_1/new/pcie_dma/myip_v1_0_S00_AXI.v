


`timescale 1 ns / 1 ps

	module myip_v1_0_S00_AXI # (
		parameter C_S_AXI_DATA_WIDTH = 32,
		parameter C_S_AXI_ADDR_WIDTH = 32 
	)
	(	

		input wire  S_AXI_ACLK,
		input wire  S_AXI_ARESETN,

		input wire [31 : 0] S_AXI_AWADDR,
		input wire  S_AXI_AWVALID,
		output wire  S_AXI_AWREADY,
		input wire [31 : 0] S_AXI_WDATA,   
		input wire [3 : 0] S_AXI_WSTRB,
		input wire  S_AXI_WVALID,
		output wire  S_AXI_WREADY,
		output wire [1 : 0] S_AXI_BRESP,
		output wire  S_AXI_BVALID,
		input wire  S_AXI_BREADY,
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
		input wire  S_AXI_ARVALID,
		output wire  S_AXI_ARREADY,
		output wire [31 : 0] S_AXI_RDATA,
		output wire [1 : 0] S_AXI_RRESP,
		output wire  S_AXI_RVALID,
		input wire  S_AXI_RREADY,
	
		//my add  
		// output reg [31:0]	read_reg_0x0  = 'd0,
		// output reg [31:0]	read_reg_0x4  = 'd0,
		// output reg [31:0]	read_reg_0x8  = 'd0,
		// output reg [31:0]	read_reg_0xc  = 'd0,
		// output reg [31:0]	read_reg_0x10 = 'd0,
		// output reg [31:0]	read_reg_0x14 = 'd0,
		// output reg [31:0]	read_reg_0x18 = 'd0,
		output reg [31:0]	read_reg_0x1c = 'd0,
		// output reg [31:0]	read_reg_0x20 = 'd0,
		// output reg [31:0]	read_reg_0x24 = 'd0,
        output reg [31:0]   read_reg_0x28 = 'd0,
        // output reg [31:0]   read_reg_0x2c = 'd0,
        // output reg [31:0]   read_reg_0x30 = 'd0,
        // output reg [31:0]   read_reg_0x34 = 'd0,
        // output reg [31:0]   read_reg_0x38 = 'd0,
        output reg [31:0]   read_reg_0x3c = 'd0,
        // output reg [31:0]   read_reg_0x40 = 'd0,
        // startup flash
        output              erase_multiboot_o           ,
        input               erase_finish_i              ,
        output              startup_rst_o               ,
        output              startup_finish_o            ,
        output              startup_pack_vld_o          ,
        output      [15:0]  startup_pack_cnt_o          ,
        output      [15:0]  startup_pack_finish_cnt_o   ,
        output              startup_vld_o               ,
        output      [31:0]  startup_data_o              ,
        output              read_flash_o                ,
        input               startup_ack_i               ,
        input               startup_finish_ack_i        ,
	
		
        input   [31:0]      in_reg0                 ,
        input   [31:0]      in_reg1                 ,
        input   [31:0]      in_reg2                 ,
        input   [31:0]      in_reg3                 ,
    (*dont_touch = "true"*)	input	   [31:0] in_reg4,
        input   [31:0]      up_check_irq_i          ,
        input   [31:0]      up_check_frame_i        ,
        input   [31:0]      irq_timeout_fault_cnt_i ,
        output              debug_register_rst_o    ,
        output              xdma_vout_state_rst_o   ,
        input   [31:0]      xdma_idle_time_max_i    ,
        input   [31:0]      xdma_hold_time_max_i    ,
        input   [32-1:0]    aurora_pmt_soft_err_i   ,
        input   [32-1:0]    aurora_timing_soft_err_i,
        input   [32-1:0]    pmt_overflow_cnt_i      ,
        input   [32-1:0]    encode_overflow_cnt_i   ,
        input   [32-1:0]    pmt_lose_pack_cnt_i     ,
        input   [32-1:0]    pmt_lose_pack_mem_cnt_i ,
        input   [32-1:0]    wr_frame_cnt_i          ,
        input   [32-1:0]    rd_frame_cnt_i          ,
        input   [32-1:0]    err_state_cnt_i         ,
        input   [32-1:0]    Xencode_skip_cnt_i      ,
        input   [32-1:0]    ddr_last_pack_cnt_i     ,
        input   [32-1:0]    ddr_usage_max_i         ,
        input   [32-1:0]    eds_aurora_pack_cnt_i   ,
        input   [32-1:0]    pmt_aurora_pack_cnt_i   ,
        input   [32-1:0]    fbc_aurora_pack_cnt_i   ,
        input   [32-1:0]    eds_xdma_pack_cnt_i     ,
        input   [32-1:0]    pmt_xdma_pack_cnt_i     ,
        input   [32-1:0]    fbc_xdma_pack_cnt_i     ,
        input   [31:0]      in_reg5
		
		
	);
	
    reg         debug_register_rst = 'd0;
    reg         xdma_vout_state_rst = 'd0;
	// AXI4LITE signals
    reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg  	axi_awready;
	reg  	axi_wready;
	reg [1 : 0] 	axi_bresp;
	reg  	axi_bvalid;
    reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
	reg  	axi_arready;
   	reg [C_S_AXI_DATA_WIDTH-1 : 0] 	axi_rdata;
	reg [1 : 0] 	axi_rresp;
	reg  	axi_rvalid;
	
    wire [31:0] axi_rddata_trans;

	// Example-specific design signals
	// local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
	// ADDR_LSB is used for addressing 32/64 bit registers/memories
	// ADDR_LSB = 2 for 32 bits (n downto 2)
	// ADDR_LSB = 3 for 64 bits (n downto 3)
	localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
	localparam integer OPT_MEM_ADDR_BITS = 1;
	//----------------------------------------------
	//-- Signals for user logic register space example
	//------------------------------------------------
	//-- Number of Slave Registers 4
	
	
	
	
 wire    slv_reg_rden;
 wire    slv_reg_wren;
(*KEEP = "TRUE" *)	reg [C_S_AXI_DATA_WIDTH-1:0]	 reg_data_out;
	integer	 byte_index;
	reg	 aw_en;

	// I/O Connections assignments

	assign S_AXI_AWREADY	= axi_awready;
	assign S_AXI_WREADY	= axi_wready;
	assign S_AXI_BRESP	= axi_bresp;
	assign S_AXI_BVALID	= axi_bvalid;
	assign S_AXI_ARREADY	= axi_arready;
	assign S_AXI_RDATA	= axi_rdata;
	assign S_AXI_RRESP	= axi_rresp;
	assign S_AXI_RVALID	= axi_rvalid;
	// Implement axi_awready generation
	// axi_awready is asserted for one S_AXI_ACLK clock cycle when both
	// S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_awready is
	
	
	// assign axi_rddata_trans = {S_AXI_WDATA[7:0],S_AXI_WDATA[15:8],S_AXI_WDATA[23:16],S_AXI_WDATA[31:24]};
	assign axi_rddata_trans = S_AXI_WDATA;
	// de-asserted when reset is low.

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_awready <= 1'b0;
	      aw_en <= 1'b1;
	    end 
	  else
	    begin    
	      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
	        begin
	          // slave is ready to accept write address when 
	          // there is a valid write address and write data
	          // on the write address and data bus. This design 
	          // expects no outstanding transactions. 
	          axi_awready <= 1'b1;
	          aw_en <= 1'b0;
	        end
	        else if (S_AXI_BREADY && axi_bvalid)
	            begin
	              aw_en <= 1'b1;
	              axi_awready <= 1'b0;
	            end
	      else           
	        begin
	          axi_awready <= 1'b0;
	        end
	    end 
	end       

	// Implement axi_awaddr latching
	// This process is used to latch the address when both 
	// S_AXI_AWVALID and S_AXI_WVALID are valid. 

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_awaddr <= 0;
	    end 
	  else
	    begin    
	      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
	        begin
	          // Write Address latching 
	          axi_awaddr <= S_AXI_AWADDR;
	        end
	    end 
	end       

	// Implement axi_wready generation
	// axi_wready is asserted for one S_AXI_ACLK clock cycle when both
	// S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_wready is 
	// de-asserted when reset is low. 

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_wready <= 1'b0;
	    end 
	  else
	    begin    
	      if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID && aw_en )
	        begin
	          // slave is ready to accept write data when 
	          // there is a valid write address and write data
	          // on the write address and data bus. This design 
	          // expects no outstanding transactions. 
	          axi_wready <= 1'b1;
	        end
	      else
	        begin
	          axi_wready <= 1'b0;
	        end
	    end 
	end       

	// Implement memory mapped register select and write logic generation
	// The write data is accepted and written to memory mapped registers when
	// axi_awready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted. Write strobes are used to
	// select byte enables of slave registers while writing.
	// These registers are cleared when reset (active low) is applied.
	// Slave register write enable is asserted when valid address and data are available
	// and the slave is ready to accept the write address and write data.
	assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;

	always @( posedge S_AXI_ACLK )
	begin
	    if (slv_reg_wren)begin
	        case ( axi_awaddr )
	            // 'h0000_0000: read_reg_0x0 <= axi_rddata_trans;
	            // 'h0000_0004: read_reg_0x4 <= axi_rddata_trans;           
	            // 'h0000_0008: read_reg_0x8 <= axi_rddata_trans;            
	            // 'h0000_000c: read_reg_0xc <= axi_rddata_trans;    
	            // 'h0000_0010: read_reg_0x10 <= axi_rddata_trans;    
	            // 'h0000_0014: read_reg_0x14 <= axi_rddata_trans;    
	            // 'h0000_0018: read_reg_0x18 <= axi_rddata_trans;    
	            'h0000_001c: read_reg_0x1c <= axi_rddata_trans;     // ddr fifo err reset  
	            // 'h0000_0020: read_reg_0x20 <= axi_rddata_trans;    
	            // 'h0000_0024: read_reg_0x24 <= axi_rddata_trans;    
                'h0000_0028: read_reg_0x28 <= axi_rddata_trans;     // aurora soft reset 
                // 'h0000_002c: read_reg_0x2c <= axi_rddata_trans;
                // 'h0000_0030: read_reg_0x30 <= axi_rddata_trans;
                // 'h0000_0034: read_reg_0x34 <= axi_rddata_trans;
                // 'h0000_0038: read_reg_0x38 <= axi_rddata_trans;
                'h0000_003C: read_reg_0x3c <= axi_rddata_trans;
                // 'h0000_0040: read_reg_0x40 <= axi_rddata_trans;
                'h0000_0074: debug_register_rst <= axi_rddata_trans[0];
                'h0000_0084: xdma_vout_state_rst    <= axi_rddata_trans[0];
            default : ;
	        endcase
	    end
        else begin
            read_reg_0x1c <= 'd0;
        end
	end    

    reg                 startup_pack_vld    = 'd0;
    reg                 startup_finish      = 'd0;
    reg     [15:0]      startup_pack_cnt    = 'd0;
    reg     [15:0]      startup_pack_finish_cnt    = 'd0;
    reg                 startup_vld         = 'd0;
    reg     [31:0]      startup_data        = 'd0;

    always @(posedge S_AXI_ACLK ) begin
        if(slv_reg_wren && axi_awaddr=='h0000_0040)begin
            startup_pack_vld <= 'd1;
            startup_pack_cnt <= axi_rddata_trans[15:0];
        end
        else begin
            startup_pack_vld <= 'd0;
        end
    end

    always @(posedge S_AXI_ACLK ) begin
        if(slv_reg_wren && axi_awaddr=='h0000_0038)begin
            startup_finish   <= 'd1;
            startup_pack_finish_cnt <= axi_rddata_trans[15:0];
        end
        else begin
            startup_finish   <= 'd0;
        end
    end

    always @(posedge S_AXI_ACLK ) begin
        if(slv_reg_wren && axi_awaddr=='h0000_0034)begin
            startup_vld      <= 'd1;
            startup_data     <= axi_rddata_trans;
        end
        else begin
            startup_vld      <= 'd0;
        end
    end

    reg                 erase_multiboot     = 'd0;
    reg                 startup_rst         = 'd0;
    reg                 read_flash          = 'd0;

    always @(posedge S_AXI_ACLK ) begin
        if(slv_reg_wren && axi_awaddr=='h0000_003c)begin
            erase_multiboot <= axi_rddata_trans[0];
        end
        else begin
            erase_multiboot <= 'd0;
        end
    end

    always @(posedge S_AXI_ACLK ) begin
        if(slv_reg_wren && axi_awaddr=='h0000_002c)begin
            startup_rst <= axi_rddata_trans[0];
        end
        else begin
            startup_rst <= 'd0;
        end
    end

    always @(posedge S_AXI_ACLK ) begin
        if(slv_reg_wren && axi_awaddr=='h0000_0030)begin
            read_flash <= axi_rddata_trans[0];
        end
        else begin
            read_flash <= 'd0;
        end
    end

    assign erase_multiboot_o         = erase_multiboot   ;
    assign startup_rst_o             = startup_rst       ;
    assign startup_finish_o          = startup_finish    ;
    assign startup_pack_vld_o        = startup_pack_vld  ;
    assign startup_pack_cnt_o        = startup_pack_cnt  ;
    assign startup_pack_finish_cnt_o = startup_pack_finish_cnt  ;
    assign startup_vld_o             = startup_vld       ;
    assign startup_data_o            = startup_data      ;
    assign read_flash_o              = read_flash        ;

	// Implement write response logic generation
	// The write response and response valid signals are asserted by the slave 
	// when axi_wready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted.  
	// This marks the acceptance of address and indicates the status of 
	// write transaction.

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_bvalid  <= 0;
	      axi_bresp   <= 2'b0;
	    end 
	  else
	    begin    
	      if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID)
	        begin
	          // indicates a valid write response is available
	          axi_bvalid <= 1'b1;
	          axi_bresp  <= 2'b0; // 'OKAY' response 
	        end                   // work error responses in future
	      else
	        begin
	          if (S_AXI_BREADY && axi_bvalid) 
	            //check if bready is asserted while bvalid is high) 
	            //(there is a possibility that bready is always asserted high)   
	            begin
	              axi_bvalid <= 1'b0; 
	            end  
	        end
	    end
	end   

	// Implement axi_arready generation
	// axi_arready is asserted for one S_AXI_ACLK clock cycle when
	// S_AXI_ARVALID is asserted. axi_awready is 
	// de-asserted when reset (active low) is asserted. 
	// The read address is also latched when S_AXI_ARVALID is 
	// asserted. axi_araddr is reset to zero on reset assertion.

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_arready <= 1'b0;
	      axi_araddr  <= 32'b0;
	    end 
	  else
	    begin    
	      if (~axi_arready && S_AXI_ARVALID)
	        begin
	          // indicates that the slave has acceped the valid read address
	          axi_arready <= 1'b1;
	          // Read address latching
	          axi_araddr  <= S_AXI_ARADDR;
	        end
	      else
	        begin
	          axi_arready <= 1'b0;
	        end
	    end 
	end       

	// Implement axi_arvalid generation
	// axi_rvalid is asserted for one S_AXI_ACLK clock cycle when both 
	// S_AXI_ARVALID and axi_arready are asserted. The slave registers 
	// data are available on the axi_rdata bus at this instance. The 
	// assertion of axi_rvalid marks the validity of read data on the 
	// bus and axi_rresp indicates the status of read transaction.axi_rvalid 
	// is deasserted on reset (active low). axi_rresp and axi_rdata are 
	// cleared to zero on reset (active low).  
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_rvalid <= 0;
	      axi_rresp  <= 0;
	    end 
	  else
	    begin    
	      if (axi_arready && S_AXI_ARVALID && ~axi_rvalid)
	        begin
	          // Valid read data is available at the read data bus
	          axi_rvalid <= 1'b1;
	          axi_rresp  <= 2'b0; // 'OKAY' response
	        end   
	      else if (axi_rvalid && S_AXI_RREADY)
	        begin
	          // Read data is accepted by the master
	          axi_rvalid <= 1'b0;
	        end                
	    end
	end    

	// Implement memory mapped register select and read logic generation
	// Slave register read enable is asserted when valid address is available
	// and the slave is ready to accept the read address.
    assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;
    always @(posedge S_AXI_ACLK)
    begin
          // Address decoding for reading registers
          case ( S_AXI_ARADDR )
            'h0000_0000   : reg_data_out <= in_reg0;    // golden or multiboot
            'h0000_0004   : reg_data_out <= in_reg4;    // multiboot version 
            'h0000_0014   : reg_data_out <= in_reg1;    // ddr3_init_done
            'h0000_0018   : reg_data_out <= in_reg2;    // CHANNEL_UP_DONE1 pmt
            'h0000_001c   : reg_data_out <= in_reg3;    // CHANNEL_UP_DONE2 eds
            'h0000_0020   : reg_data_out <= {31'd0,startup_finish_ack_i};
            'h0000_0024   : reg_data_out <= {31'd0,startup_ack_i};
            'h0000_0028   : reg_data_out <= read_reg_0x28;  // aurora soft reset 
            // 'h0000_002c   : reg_data_out <= read_reg_0x2c;
            // 'h0000_0030   : reg_data_out <= read_reg_0x30;
            // 'h0000_0034   : reg_data_out <= read_reg_0x34;
            // 'h0000_0038   : reg_data_out <= read_reg_0x38;
            'h0000_003c   : reg_data_out <= {30'd0,erase_finish_i,read_reg_0x3c[0]};
            // 'h0000_0040   : reg_data_out <= read_reg_0x40;
            'h0000_0044   : reg_data_out <= up_check_irq_i;
            'h0000_0048   : reg_data_out <= up_check_frame_i;
            'h0000_0050   : reg_data_out <= aurora_pmt_soft_err_i   ;
            'h0000_0054   : reg_data_out <= aurora_timing_soft_err_i;
            'h0000_0058   : reg_data_out <= pmt_overflow_cnt_i      ;
            'h0000_005c   : reg_data_out <= encode_overflow_cnt_i   ;
            'h0000_0060   : reg_data_out <= pmt_lose_pack_cnt_i     ;
            'h0000_0064   : reg_data_out <= pmt_lose_pack_mem_cnt_i ;
            'h0000_0068   : reg_data_out <= wr_frame_cnt_i          ;
            'h0000_006c   : reg_data_out <= rd_frame_cnt_i          ;
            'h0000_0070   : reg_data_out <= irq_timeout_fault_cnt_i ;
            'h0000_0074   : reg_data_out <= debug_register_rst      ;
            'h0000_0078   : reg_data_out <= xdma_idle_time_max_i    ;
            'h0000_007c   : reg_data_out <= xdma_hold_time_max_i    ;
            'h0000_0080   : reg_data_out <= err_state_cnt_i         ;
            'h0000_0084   : reg_data_out <= xdma_vout_state_rst     ;
            'h0000_0088   : reg_data_out <= Xencode_skip_cnt_i      ;
            'h0000_008c   : reg_data_out <= ddr_last_pack_cnt_i     ;
            'h0000_0090   : reg_data_out <= eds_aurora_pack_cnt_i   ;
            'h0000_0094   : reg_data_out <= pmt_aurora_pack_cnt_i   ;
            'h0000_0098   : reg_data_out <= fbc_aurora_pack_cnt_i   ;
            'h0000_009c   : reg_data_out <= eds_xdma_pack_cnt_i     ;
            'h0000_00a0   : reg_data_out <= pmt_xdma_pack_cnt_i     ;
            'h0000_00a4   : reg_data_out <= fbc_xdma_pack_cnt_i     ;
            'h0000_00a8   : reg_data_out <= ddr_usage_max_i         ;
            default : reg_data_out <= 0;
          endcase
    end

    assign debug_register_rst_o  = debug_register_rst;
    assign xdma_vout_state_rst_o = xdma_vout_state_rst;
	// Output register or memory read data
	always @( posedge S_AXI_ACLK )
	begin
	//   if ( S_AXI_ARESETN == 1'b0 )
	//     begin
	//       axi_rdata  <= 0;
	//     end 
	//   else
	    // begin    
	      // When there is a valid read address (S_AXI_ARVALID) with 
	      // acceptance of read address by the slave (axi_arready), 
	      // output the read dada 
	      if (slv_reg_rden)
	        begin
	          axi_rdata <= reg_data_out;     // register read data
	        end   
	    // end
	end    

	// Add user logic here

	// User logic ends

	endmodule
