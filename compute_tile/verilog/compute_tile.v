`include "lisnoc_def.vh"
`include "optimsoc_def.vh"


module compute_tile(/*AUTOARG*/
   // Outputs
   noc_in_ready, noc_out_flit, noc_out_valid,
   // Inputs
   clk, rst, noc_in_flit, noc_in_valid, noc_out_ready
   );
   input clk;
   input rst;

   parameter vchannels = 3;
   
   input [`FLIT_WIDTH-1:0] noc_in_flit;
   input [vchannels-1:0] noc_in_valid;
   output [vchannels-1:0] noc_in_ready;
   output [`FLIT_WIDTH-1:0] noc_out_flit;
   output [vchannels-1:0] noc_out_valid;
   input [vchannels-1:0] noc_out_ready;
   
   
   parameter id       = 0;
   parameter mem_file = "sram.vmem";
   parameter cores    = 1;

   wire [31:0] 	 busms_adr_o[0:2];
   wire 	 busms_cyc_o[0:2];
   wire [31:0] 	 busms_dat_o[0:2];
   wire [3:0] 	 busms_sel_o[0:2];
   wire 	 busms_stb_o[0:2];
   wire 	 busms_we_o[0:2];
   wire 	 busms_cab_o[0:2];
   wire [2:0] 	 busms_cti_o[0:2];
   wire [1:0] 	 busms_bte_o[0:2];
   wire 	 busms_ack_i[0:2];
   wire 	 busms_rty_i[0:2];
   wire 	 busms_err_i[0:2];
   wire [31:0] 	 busms_dat_i[0:2];
   
   wire [31:0] 	 bussl_adr_i[0:1];
   wire 	 bussl_cyc_i[0:1];
   wire [31:0] 	 bussl_dat_i[0:1];
   wire [3:0] 	 bussl_sel_i[0:1];
   wire 	 bussl_stb_i[0:1];
   wire 	 bussl_we_i[0:1];
   wire 	 bussl_cab_i[0:1];
   wire [2:0] 	 bussl_cti_i[0:1];
   wire [1:0] 	 bussl_bte_i[0:1];
   wire 	 bussl_ack_o[0:1];
   wire 	 bussl_rty_o[0:1];
   wire 	 bussl_err_o[0:1];
   wire [31:0] 	 bussl_dat_o[0:1];

   wire [19:0] 	 pic_ints_i;
   assign pic_ints_i = 20'h00000;

   /* or1200_module AUTO_TEMPLATE(
    .clk_i          (clk),
    .rst_i          (rst),
    .bus_clk_i          (clk),
    .bus_rst_i          (rst),
    .dbg_.*_o       (),
    .dbg_stall_i    (1'b0),
    .dbg_ewt_i      (1'b0),
    .dbg_stb_i      (1'b0),
    .dbg_we_i       (1'b0),
    .dbg_adr_i      (32'h00000000),
    .dbg_dat_i      (32'h00000000),
    .snoop_\(.*\)_i (0),
    .snoop_\(.*\)_o (),
    .iwb_\(.*\)     (busms_\1[0][]),
    .dwb_\(.*\)     (busms_\1[1][]),
    ); */
   or1200_module #(.id(0))
   u_core0 (/*AUTOINST*/
	    // Outputs
	    .dbg_lss_o			(),			 // Templated
	    .dbg_is_o			(),			 // Templated
	    .dbg_wp_o			(),			 // Templated
	    .dbg_bp_o			(),			 // Templated
	    .dbg_dat_o			(),			 // Templated
	    .dbg_ack_o			(),			 // Templated
	    .iwb_cyc_o			(busms_cyc_o[0]),	 // Templated
	    .iwb_adr_o			(busms_adr_o[0][31:0]),	 // Templated
	    .iwb_stb_o			(busms_stb_o[0]),	 // Templated
	    .iwb_we_o			(busms_we_o[0]),	 // Templated
	    .iwb_sel_o			(busms_sel_o[0][3:0]),	 // Templated
	    .iwb_dat_o			(busms_dat_o[0][31:0]),	 // Templated
	    .dwb_cyc_o			(busms_cyc_o[1]),	 // Templated
	    .dwb_adr_o			(busms_adr_o[1][31:0]),	 // Templated
	    .dwb_stb_o			(busms_stb_o[1]),	 // Templated
	    .dwb_we_o			(busms_we_o[1]),	 // Templated
	    .dwb_sel_o			(busms_sel_o[1][3:0]),	 // Templated
	    .dwb_dat_o			(busms_dat_o[1][31:0]),	 // Templated
	    // Inputs
	    .clk_i			(clk),			 // Templated
	    .bus_clk_i			(clk),			 // Templated
	    .rst_i			(rst),			 // Templated
	    .bus_rst_i			(rst),			 // Templated
	    .dbg_stall_i		(1'b0),			 // Templated
	    .dbg_ewt_i			(1'b0),			 // Templated
	    .dbg_stb_i			(1'b0),			 // Templated
	    .dbg_we_i			(1'b0),			 // Templated
	    .dbg_adr_i			(32'h00000000),		 // Templated
	    .dbg_dat_i			(32'h00000000),		 // Templated
	    .snoop_adr_i		(0),			 // Templated
	    .snoop_ack_i		(0),			 // Templated
	    .snoop_we_i			(0),			 // Templated
	    .snoop_dat_i		(0),			 // Templated
	    .snoop_sel_i		(0),			 // Templated
	    .pic_ints_i			(pic_ints_i[19:0]),
	    .iwb_ack_i			(busms_ack_i[0]),	 // Templated
	    .iwb_err_i			(busms_err_i[0]),	 // Templated
	    .iwb_rty_i			(busms_rty_i[0]),	 // Templated
	    .iwb_dat_i			(busms_dat_i[0][31:0]),	 // Templated
	    .dwb_ack_i			(busms_ack_i[1]),	 // Templated
	    .dwb_err_i			(busms_err_i[1]),	 // Templated
	    .dwb_rty_i			(busms_rty_i[1]),	 // Templated
	    .dwb_dat_i			(busms_dat_i[1][31:0]));	 // Templated


   assign busms_cab_o[0] = 1'b0;
   assign busms_cti_o[0] = 3'b000;
   assign busms_bte_o[0] = 2'b00;
   
   assign busms_cab_o[1] = 1'b0;
   assign busms_cti_o[1] = 3'b000;
   assign busms_bte_o[1] = 2'b00;
   
   /* compute_tile_bus AUTO_TEMPLATE(
    .clk_i      (clk),
    .rst_i      (rst),
    .m_@_\(.*\)_o (busms_\2_i[\1][]),
    .m_@_\(.*\)_i (busms_\2_o[\1][]),
    .s_@_\(.*\)_o (bussl_\2_i[\1][]),
    .s_@_\(.*\)_i (bussl_\2_o[\1][]),
    ); */
   
   compute_tile_bus
     #(.dw(32),.aw(32),.sw(4))
   u_bus(/*AUTOINST*/
	 // Outputs
	 .m_0_dat_o			(busms_dat_i[0][31:0]),	 // Templated
	 .m_0_ack_o			(busms_ack_i[0]),	 // Templated
	 .m_0_err_o			(busms_err_i[0]),	 // Templated
	 .m_0_rty_o			(busms_rty_i[0]),	 // Templated
	 .m_1_dat_o			(busms_dat_i[1][31:0]),	 // Templated
	 .m_1_ack_o			(busms_ack_i[1]),	 // Templated
	 .m_1_err_o			(busms_err_i[1]),	 // Templated
	 .m_1_rty_o			(busms_rty_i[1]),	 // Templated
	 .m_2_dat_o			(busms_dat_i[2][31:0]),	 // Templated
	 .m_2_ack_o			(busms_ack_i[2]),	 // Templated
	 .m_2_err_o			(busms_err_i[2]),	 // Templated
	 .m_2_rty_o			(busms_rty_i[2]),	 // Templated
	 .s_0_dat_o			(bussl_dat_i[0][31:0]),	 // Templated
	 .s_0_adr_o			(bussl_adr_i[0][31:0]),	 // Templated
	 .s_0_sel_o			(bussl_sel_i[0][3:0]),	 // Templated
	 .s_0_we_o			(bussl_we_i[0]),	 // Templated
	 .s_0_cyc_o			(bussl_cyc_i[0]),	 // Templated
	 .s_0_stb_o			(bussl_stb_i[0]),	 // Templated
	 .s_0_cab_o			(bussl_cab_i[0]),	 // Templated
	 .s_0_cti_o			(bussl_cti_i[0][2:0]),	 // Templated
	 .s_0_bte_o			(bussl_bte_i[0][1:0]),	 // Templated
	 .s_1_dat_o			(bussl_dat_i[1][31:0]),	 // Templated
	 .s_1_adr_o			(bussl_adr_i[1][31:0]),	 // Templated
	 .s_1_sel_o			(bussl_sel_i[1][3:0]),	 // Templated
	 .s_1_we_o			(bussl_we_i[1]),	 // Templated
	 .s_1_cyc_o			(bussl_cyc_i[1]),	 // Templated
	 .s_1_stb_o			(bussl_stb_i[1]),	 // Templated
	 .s_1_cab_o			(bussl_cab_i[1]),	 // Templated
	 .s_1_cti_o			(bussl_cti_i[1][2:0]),	 // Templated
	 .s_1_bte_o			(bussl_bte_i[1][1:0]),	 // Templated
	 // Inputs
	 .clk_i				(clk),			 // Templated
	 .rst_i				(rst),			 // Templated
	 .m_0_dat_i			(busms_dat_o[0][31:0]),	 // Templated
	 .m_0_adr_i			(busms_adr_o[0][31:0]),	 // Templated
	 .m_0_sel_i			(busms_sel_o[0][3:0]),	 // Templated
	 .m_0_we_i			(busms_we_o[0]),	 // Templated
	 .m_0_cyc_i			(busms_cyc_o[0]),	 // Templated
	 .m_0_stb_i			(busms_stb_o[0]),	 // Templated
	 .m_0_cab_i			(busms_cab_o[0]),	 // Templated
	 .m_0_cti_i			(busms_cti_o[0][2:0]),	 // Templated
	 .m_0_bte_i			(busms_bte_o[0][1:0]),	 // Templated
	 .m_1_dat_i			(busms_dat_o[1][31:0]),	 // Templated
	 .m_1_adr_i			(busms_adr_o[1][31:0]),	 // Templated
	 .m_1_sel_i			(busms_sel_o[1][3:0]),	 // Templated
	 .m_1_we_i			(busms_we_o[1]),	 // Templated
	 .m_1_cyc_i			(busms_cyc_o[1]),	 // Templated
	 .m_1_stb_i			(busms_stb_o[1]),	 // Templated
	 .m_1_cab_i			(busms_cab_o[1]),	 // Templated
	 .m_1_cti_i			(busms_cti_o[1][2:0]),	 // Templated
	 .m_1_bte_i			(busms_bte_o[1][1:0]),	 // Templated
	 .m_2_dat_i			(busms_dat_o[2][31:0]),	 // Templated
	 .m_2_adr_i			(busms_adr_o[2][31:0]),	 // Templated
	 .m_2_sel_i			(busms_sel_o[2][3:0]),	 // Templated
	 .m_2_we_i			(busms_we_o[2]),	 // Templated
	 .m_2_cyc_i			(busms_cyc_o[2]),	 // Templated
	 .m_2_stb_i			(busms_stb_o[2]),	 // Templated
	 .m_2_cab_i			(busms_cab_o[2]),	 // Templated
	 .m_2_cti_i			(busms_cti_o[2][2:0]),	 // Templated
	 .m_2_bte_i			(busms_bte_o[2][1:0]),	 // Templated
	 .s_0_dat_i			(bussl_dat_o[0][31:0]),	 // Templated
	 .s_0_ack_i			(bussl_ack_o[0]),	 // Templated
	 .s_0_err_i			(bussl_err_o[0]),	 // Templated
	 .s_0_rty_i			(bussl_rty_o[0]),	 // Templated
	 .s_1_dat_i			(bussl_dat_o[1][31:0]),	 // Templated
	 .s_1_ack_i			(bussl_ack_o[1]),	 // Templated
	 .s_1_err_i			(bussl_err_o[1]),	 // Templated
	 .s_1_rty_i			(bussl_rty_o[1]));	 // Templated

   /* wb_ram_b3 AUTO_TEMPLATE(
    .wb_clk_i  (clk),
    .wb_rst_i  (rst),
    .wb_\(.*\) (bussl_\1[0][]),
    ); */
   wb_ram_b3
     #(.aw(32),.dw(32),.mem_size(131072),.memory_file("ct.vmem"))
   u_ram(/*AUTOINST*/
	 // Outputs
	 .wb_ack_o			(bussl_ack_o[0]),	 // Templated
	 .wb_err_o			(bussl_err_o[0]),	 // Templated
	 .wb_rty_o			(bussl_rty_o[0]),	 // Templated
	 .wb_dat_o			(bussl_dat_o[0][31:0]),	 // Templated
	 // Inputs
	 .wb_adr_i			(bussl_adr_i[0][31:0]),	 // Templated
	 .wb_bte_i			(bussl_bte_i[0][1:0]),	 // Templated
	 .wb_cti_i			(bussl_cti_i[0][2:0]),	 // Templated
	 .wb_cyc_i			(bussl_cyc_i[0]),	 // Templated
	 .wb_dat_i			(bussl_dat_i[0][31:0]),	 // Templated
	 .wb_sel_i			(bussl_sel_i[0][3:0]),	 // Templated
	 .wb_stb_i			(bussl_stb_i[0]),	 // Templated
	 .wb_we_i			(bussl_we_i[0]),	 // Templated
	 .wb_clk_i			(clk),			 // Templated
	 .wb_rst_i			(rst));			 // Templated
   
   /* networkadapter_ct AUTO_TEMPLATE(
    .wbs_\(.*\)   (bussl_\1[1]),
    .wbm_\(.*\)      (busms_\1[2]),
    );*/
   networkadapter_ct
     #(.tileid(id))
   u_na(/*AUTOINST*/
	// Outputs
	.noc_in_ready			(noc_in_ready[vchannels-1:0]),
	.noc_out_flit			(noc_out_flit[`FLIT_WIDTH-1:0]),
	.noc_out_valid			(noc_out_valid[vchannels-1:0]),
	.wbm_adr_o			(busms_adr_o[2]),	 // Templated
	.wbm_cyc_o			(busms_cyc_o[2]),	 // Templated
	.wbm_dat_o			(busms_dat_o[2]),	 // Templated
	.wbm_sel_o			(busms_sel_o[2]),	 // Templated
	.wbm_stb_o			(busms_stb_o[2]),	 // Templated
	.wbm_we_o			(busms_we_o[2]),	 // Templated
	.wbm_cab_o			(busms_cab_o[2]),	 // Templated
	.wbm_cti_o			(busms_cti_o[2]),	 // Templated
	.wbm_bte_o			(busms_bte_o[2]),	 // Templated
	.wbs_ack_o			(bussl_ack_o[1]),	 // Templated
	.wbs_rty_o			(bussl_rty_o[1]),	 // Templated
	.wbs_err_o			(bussl_err_o[1]),	 // Templated
	.wbs_dat_o			(bussl_dat_o[1]),	 // Templated
	// Inputs
	.clk				(clk),
	.rst				(rst),
	.noc_in_flit			(noc_in_flit[`FLIT_WIDTH-1:0]),
	.noc_in_valid			(noc_in_valid[vchannels-1:0]),
	.noc_out_ready			(noc_out_ready[vchannels-1:0]),
	.wbm_ack_i			(busms_ack_i[2]),	 // Templated
	.wbm_rty_i			(busms_rty_i[2]),	 // Templated
	.wbm_err_i			(busms_err_i[2]),	 // Templated
	.wbm_dat_i			(busms_dat_i[2]),	 // Templated
	.wbs_adr_i			(bussl_adr_i[1]),	 // Templated
	.wbs_cyc_i			(bussl_cyc_i[1]),	 // Templated
	.wbs_dat_i			(bussl_dat_i[1]),	 // Templated
	.wbs_sel_i			(bussl_sel_i[1]),	 // Templated
	.wbs_stb_i			(bussl_stb_i[1]),	 // Templated
	.wbs_we_i			(bussl_we_i[1]),	 // Templated
	.wbs_cab_i			(bussl_cab_i[1]),	 // Templated
	.wbs_cti_i			(bussl_cti_i[1]),	 // Templated
	.wbs_bte_i			(bussl_bte_i[1]));	 // Templated
   
   
endmodule // compute_tile

// Local Variables:
// verilog-library-directories:("../../or1200_module/verilog/" "../../networkadapter_ct/verilog/" "../../compute_tile_bus/verilog" "../../../../../lisnoc/rtl/dma/" "../../../../../lisnoc/rtl/router" "../../wb_ram_b3/verilog")
// verilog-auto-inst-param-value: t
// End:
