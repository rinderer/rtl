/**
 * This file is part of OpTiMSoC.
 *
 * OpTiMSoC is free hardware: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation, either version 3 of
 * the License, or (at your option) any later version.
 *
 * As the LGPL in general applies to software, the meaning of
 * "linking" is defined as using the OpTiMSoC in your projects at
 * the external interfaces.
 *
 * OpTiMSoC is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with OpTiMSoC. If not, see <http://www.gnu.org/licenses/>.
 *
 * =================================================================
 *
 * Single Port RAM with Byte Select
 *
 * The width of the data and address bus can be configured using the DW and
 * AW parameters. To support byte selects DW must be a multiple of 8.
 *
 * Most of the code is taken from the ORPSoCv2 project (or1200_tpram_32x32)
 * of opencores.org.
 *
 * (c) by the author(s)
 *
 * Author(s):
 *    Stefan Wallentowitz, stefan.wallentowitz@tum.de
 *    Markus Goehrle, markus.goehrle@tum.de
 *    Philipp Wagner, philipp.wagner@tum.de
 */

 module sram_sp(/*AUTOARG*/
   // Outputs
   dout,
   // Inputs
   clk, rst, ce, we, oe, addr, din, sel
   );

   parameter MEM_SIZE = 'hx;
   
   // address width
   parameter AW = 32;

   // data width (word size)
   // Valid values: 32, 16 and 8
   parameter DW = 32;

   // type of the memory implementation
   parameter MEM_IMPL_TYPE = "plain";
   // VMEM memory file to load in simulation
   parameter MEM_FILE = "sram.vmem";

   // byte select width (must be a power of two)
   localparam SW = (DW == 32) ? 4 :
                   (DW == 16) ? 2 :
                   (DW ==  8) ? 1 : 'hx;


   // ensure that parameters are set to allowed values
   // TODO: Check if synthesis tools statically check this statement and remove
   //       it. Otherwise we'll need some defines here.
   initial begin
      if (DW % 8 != 0) begin
         $display("sp_ram: the data port width (parameter DW) must be a multiple of 8");
         $stop;
      end

      if ((1 << clog2(SW)) != SW) begin
         $display("sp_ram: the byte select width (paramter SW = DW/8) must be a power of two");
         $stop;
      end
   end

   input           clk;  // Clock
   input           rst;  // Reset
   input           ce;   // Chip enable input
   input           we;   // Write enable input
   input           oe;   // Output enable input
   input [AW-1:0]  addr; // address bus inputs
   input [DW-1:0]  din;  // input data bus
   input [SW-1:0]  sel;  // select bytes
   output [DW-1:0] dout; // output data bus

   // validate the memory address (check if it's inside the memory size bounds)
`ifdef OPTIMSOC_RAM_VALIDATE_ADDRESS
   always @(posedge clk) begin
      if (addr > MEM_SIZE) begin
         $display("sp_ram: access to out-of-bounds memory address detected!");
         $stop;
      end
   end
`endif

   generate
      if (MEM_IMPL_TYPE == "PLAIN") begin
         sram_sp_impl_plain
            #(/*AUTOINSTPARAM*/
              // Parameters
              .AW                       (AW),
              .DW                       (DW),
              .MEM_SIZE                 (MEM_SIZE),
              .MEM_FILE                 (MEM_FILE))
            u_impl(/*AUTOINST*/
                   // Outputs
                   .dout                (dout[DW-1:0]),
                   // Inputs
                   .clk                 (clk),
                   .rst                 (rst),
                   .ce                  (ce),
                   .we                  (we),
                   .oe                  (oe),
                   .addr                (addr[AW-1:0]),
                   .din                 (din[DW-1:0]),
                   .sel                 (sel[SW-1:0]));
      end else if (MEM_IMPL_TYPE == "XILINX_SPARTAN6") begin // if (MEM_IMPL_TYPE == "PLAIN")
         sram_sp_impl_xilinx_spartan6
            #(/*AUTOINSTPARAM*/
              // Parameters
              .MEM_SIZE                 (MEM_SIZE))
            u_impl(/*AUTOINST*/
                   // Outputs
                   .dout                (dout[31:0]),
                   // Inputs
                   .clk                 (clk),
                   .rst                 (rst),
                   .sel                 (sel[3:0]),
                   .addr                (addr[AW-1:0]),
                   .we                  (we),
                   .ce                  (ce),
                   .din                 (din[31:0]));
      end else begin
//         $display("Unsupported memory type: ", MEM_IMPL_TYPE);
//         $stop;
      end
   endgenerate

`include "optimsoc_functions.vh"
   
 endmodule
