/* Copyright (c) 2009-2013 by the author(s)
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * =============================================================================
 *
 * This is a wrapper module for the OpenRISC processor that adds
 * the compare-and-swap (CAS) unit on the data port to allow for atomic
 * accesses to data elements.
 *
 * Author(s):
 *   Stefan Wallentowitz <stefan.wallentowitz@tum.de>
 */

module or1200_module (
`ifdef OPTIMSOC_DEBUG_ENABLE_ITM
                      trace_itm,
`endif
`ifdef OPTIMSOC_DEBUG_ENABLE_STM
                      trace_stm,
`endif
   /*AUTOARG*/
   // Outputs
   dbg_lss_o, dbg_is_o, dbg_wp_o, dbg_bp_o, dbg_dat_o, dbg_ack_o,
   iwb_cyc_o, iwb_adr_o, iwb_stb_o, iwb_we_o, iwb_sel_o, iwb_dat_o,
   iwb_bte_o, iwb_cti_o, dwb_cyc_o, dwb_adr_o, dwb_stb_o, dwb_we_o,
   dwb_sel_o, dwb_dat_o, dwb_bte_o, dwb_cti_o,
   // Inputs
   clk_i, bus_clk_i, rst_i, bus_rst_i, dbg_stall_i, dbg_ewt_i,
   dbg_stb_i, dbg_we_i, dbg_adr_i, dbg_dat_i, pic_ints_i, iwb_ack_i,
   iwb_err_i, iwb_rty_i, iwb_dat_i, dwb_ack_i, dwb_err_i, dwb_rty_i,
   dwb_dat_i
   );

   parameter ID = 0;

   input          clk_i;
   input          bus_clk_i;
   input          rst_i;
   input          bus_rst_i;

   input          dbg_stall_i;  // External Stall Input
   input          dbg_ewt_i;    // External Watchpoint Trigger Input
   output [3:0]   dbg_lss_o;    // External Load/Store Unit Status
   output [1:0]   dbg_is_o;     // External Insn Fetch Status
   output [10:0]  dbg_wp_o;     // Watchpoints Outputs
   output         dbg_bp_o;     // Breakpoint Output
   input          dbg_stb_i;     // External Address/Data Strobe
   input          dbg_we_i;      // External Write Enable
   input [31:0]   dbg_adr_i;    // External Address Input
   input [31:0]   dbg_dat_i;    // External Data Input
   output [31:0]  dbg_dat_o;    // External Data Output
   output         dbg_ack_o;    // External Data Acknowledge (not WB compatible)

   input [19:0]   pic_ints_i;

   //
   // Instruction WISHBONE interface
   //
   input           iwb_ack_i;   // normal termination
   input           iwb_err_i;   // termination w/ error
   input           iwb_rty_i;   // termination w/ retry
   input [31:0]    iwb_dat_i;   // input data bus
   output          iwb_cyc_o;   // cycle valid output
   output [31:0]   iwb_adr_o;   // address bus outputs
   output          iwb_stb_o;   // strobe output
   output          iwb_we_o;    // indicates write transfer
   output [3:0]    iwb_sel_o;   // byte select outputs
   output [31:0]   iwb_dat_o;   // output data bus
   output [1:0]    iwb_bte_o;
   output [2:0]    iwb_cti_o;

   //
   // Data WISHBONE interface
   //
   input           dwb_ack_i;   // normal termination
   input           dwb_err_i;   // termination w/ error
   input           dwb_rty_i;   // termination w/ retry
   input [31:0]    dwb_dat_i;   // input data bus
   output          dwb_cyc_o;   // cycle valid output
   output [31:0]   dwb_adr_o;   // address bus outputs
   output          dwb_stb_o;   // strobe output
   output          dwb_we_o;    // indicates write transfer
   output [3:0]    dwb_sel_o;   // byte select outputs
   output [31:0]   dwb_dat_o;   // output data bus
   output [1:0]    dwb_bte_o;
   output [2:0]    dwb_cti_o;

`ifdef OPTIMSOC_DEBUG_ENABLE_ITM
   output [`DEBUG_ITM_PORTWIDTH-1:0] trace_itm;
`endif

`ifdef OPTIMSOC_DEBUG_ENABLE_STM
   output [`DEBUG_STM_PORTWIDTH-1:0] trace_stm;
`endif

   wire            core_ack_i;  // normal termination
   wire            core_err_i;  // termination w/ error
   wire            core_rty_i;  // termination w/ retry
   wire [31:0]     core_dat_i;  // input data bus
   wire            core_cyc_o;  // cycle valid wire
   wire [31:0]     core_adr_o;  // address bus outputs
   wire            core_stb_o;  // strobe output
   wire            core_we_o;   // indicates write transfer
   wire [3:0]      core_sel_o;  // byte select outputs
   wire [31:0]     core_dat_o;  // output data bus
   wire [1:0]      core_bte_o;
   wire [2:0]      core_cti_o;

   /* or1200_top AUTO_TEMPLATE(
    .pm_clksd_o      (),
    .pm_dc_gate_o    (),
    .pm_ic_gate_o    (),
    .pm_dmmu_gate_o  (),
    .pm_immu_gate_o  (),
    .pm_tt_gate_o    (),
    .pm_cpu_gate_o   (),
    .pm_wakeup_o     (),
    .pm_lvolt_o      (),
    .pm_cpustall_i   (1'b0),
    .iwb_clk_i       (bus_clk_i),
    .iwb_rst_i       (bus_rst_i),
    .dwb_clk_i       (bus_clk_i),
    .dwb_rst_i       (bus_rst_i),
    .dwb_\(.*\)      (core_\1[]),
    .clmode_i        (2'b00),
    .sig_tick (),
    ); */

   or1200_top #(.dw(32),.aw(32),.ppic_ints(20),.coreid(ID))
   u_cpu(
`ifdef OR1200_WB_CAB
         .iwb_cab_o                     (iwb_cab_o),
         .dwb_cab_o                     (dwb_cab_o),
`endif
`ifdef OR1200_BIST
          .mbist_so_o   (mbist_so_o),
          .mbist_si_i   (mbist_si_i)
          .mbist_ctrl_i (mbist_ctrl_i[`OR1200_MBIST_CTRL_WIDTH-1:0]),
`endif
`ifdef OR1200_MP_COREID_AS_PORT
         .coreid_i                      (ID),
`endif
`ifdef OPTIMSOC_DEBUG_ENABLE_ITM
         .trace_itm                     (trace_itm[`DEBUG_ITM_PORTWIDTH-1:0]),
`endif
`ifdef OPTIMSOC_DEBUG_ENABLE_STM
         .trace_stm                     (trace_stm[`DEBUG_STM_PORTWIDTH-1:0]),
`endif
          /*AUTOINST*/
         // Outputs
         .iwb_cyc_o                     (iwb_cyc_o),
         .iwb_adr_o                     (iwb_adr_o[31:0]),
         .iwb_stb_o                     (iwb_stb_o),
         .iwb_we_o                      (iwb_we_o),
         .iwb_sel_o                     (iwb_sel_o[3:0]),
         .iwb_dat_o                     (iwb_dat_o[31:0]),
         .iwb_cti_o                     (iwb_cti_o[2:0]),
         .iwb_bte_o                     (iwb_bte_o[1:0]),
         .dwb_cyc_o                     (core_cyc_o),            // Templated
         .dwb_adr_o                     (core_adr_o[31:0]),      // Templated
         .dwb_stb_o                     (core_stb_o),            // Templated
         .dwb_we_o                      (core_we_o),             // Templated
         .dwb_sel_o                     (core_sel_o[3:0]),       // Templated
         .dwb_dat_o                     (core_dat_o[31:0]),      // Templated
         .dwb_cti_o                     (core_cti_o[2:0]),       // Templated
         .dwb_bte_o                     (core_bte_o[1:0]),       // Templated
         .dbg_lss_o                     (dbg_lss_o[3:0]),
         .dbg_is_o                      (dbg_is_o[1:0]),
         .dbg_wp_o                      (dbg_wp_o[10:0]),
         .dbg_bp_o                      (dbg_bp_o),
         .dbg_dat_o                     (dbg_dat_o[31:0]),
         .dbg_ack_o                     (dbg_ack_o),
         .pm_clksd_o                    (),                      // Templated
         .pm_dc_gate_o                  (),                      // Templated
         .pm_ic_gate_o                  (),                      // Templated
         .pm_dmmu_gate_o                (),                      // Templated
         .pm_immu_gate_o                (),                      // Templated
         .pm_tt_gate_o                  (),                      // Templated
         .pm_cpu_gate_o                 (),                      // Templated
         .pm_wakeup_o                   (),                      // Templated
         .pm_lvolt_o                    (),                      // Templated
         .sig_tick                      (),                      // Templated
         // Inputs
         .clk_i                         (clk_i),
         .rst_i                         (rst_i),
         .clmode_i                      (2'b00),                 // Templated
         .pic_ints_i                    (pic_ints_i[19:0]),
         .iwb_clk_i                     (bus_clk_i),             // Templated
         .iwb_rst_i                     (bus_rst_i),             // Templated
         .iwb_ack_i                     (iwb_ack_i),
         .iwb_err_i                     (iwb_err_i),
         .iwb_rty_i                     (iwb_rty_i),
         .iwb_dat_i                     (iwb_dat_i[31:0]),
         .dwb_clk_i                     (bus_clk_i),             // Templated
         .dwb_rst_i                     (bus_rst_i),             // Templated
         .dwb_ack_i                     (core_ack_i),            // Templated
         .dwb_err_i                     (core_err_i),            // Templated
         .dwb_rty_i                     (core_rty_i),            // Templated
         .dwb_dat_i                     (core_dat_i[31:0]),      // Templated
         .dbg_stall_i                   (dbg_stall_i),
         .dbg_ewt_i                     (dbg_ewt_i),
         .dbg_stb_i                     (dbg_stb_i),
         .dbg_we_i                      (dbg_we_i),
         .dbg_adr_i                     (dbg_adr_i[31:0]),
         .dbg_dat_i                     (dbg_dat_i[31:0]),
         .pm_cpustall_i                 (1'b0));                  // Templated

   /* wb_cas_unit AUTO_TEMPLATE(
    .clk_i          (bus_clk_i),
    .rst_i          (bus_rst_i),
    .wb_core_\(.*\)_i (core_\1_o[]),
    .wb_core_\(.*\)_o (core_\1_i[]),
    .wb_bus_\(.*\)  (dwb_\1[]),
    ); */
   wb_cas_unit u_cas (/*AUTOINST*/
                      // Outputs
                      .wb_core_dat_o    (core_dat_i[31:0]),      // Templated
                      .wb_core_ack_o    (core_ack_i),            // Templated
                      .wb_core_rty_o    (core_rty_i),            // Templated
                      .wb_core_err_o    (core_err_i),            // Templated
                      .wb_bus_dat_o     (dwb_dat_o[31:0]),       // Templated
                      .wb_bus_adr_o     (dwb_adr_o[31:0]),       // Templated
                      .wb_bus_sel_o     (dwb_sel_o[3:0]),        // Templated
                      .wb_bus_bte_o     (dwb_bte_o[1:0]),        // Templated
                      .wb_bus_cti_o     (dwb_cti_o[2:0]),        // Templated
                      .wb_bus_we_o      (dwb_we_o),              // Templated
                      .wb_bus_cyc_o     (dwb_cyc_o),             // Templated
                      .wb_bus_stb_o     (dwb_stb_o),             // Templated
                      // Inputs
                      .clk_i            (bus_clk_i),             // Templated
                      .rst_i            (bus_rst_i),             // Templated
                      .wb_core_dat_i    (core_dat_o[31:0]),      // Templated
                      .wb_core_adr_i    (core_adr_o[31:0]),      // Templated
                      .wb_core_sel_i    (core_sel_o[3:0]),       // Templated
                      .wb_core_bte_i    (core_bte_o[1:0]),       // Templated
                      .wb_core_cti_i    (core_cti_o[2:0]),       // Templated
                      .wb_core_we_i     (core_we_o),             // Templated
                      .wb_core_cyc_i    (core_cyc_o),            // Templated
                      .wb_core_stb_i    (core_stb_o),            // Templated
                      .wb_bus_dat_i     (dwb_dat_i[31:0]),       // Templated
                      .wb_bus_ack_i     (dwb_ack_i),             // Templated
                      .wb_bus_rty_i     (dwb_rty_i),             // Templated
                      .wb_bus_err_i     (dwb_err_i));             // Templated

endmodule // or1200_module

// Local Variables:
// verilog-library-directories:("." "../../*/verilog/")
// verilog-auto-inst-param-value: t
// End:
