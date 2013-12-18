/* Copyright (c) 2013 by the author(s)
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
 * Submodule of the Instruction Trace Module (ITM): the trace compression module
 *
 * TODO: Find a solution for transmitting the timestamp of all instructions,
 * even though the instructions are sequential and removed by compression.
 * This is necessary to allow for cycle-accurate reconstruction of the trace.
 *
 * Author(s):
 *   Philipp Wagner <mail@philipp-wagner.com>
 */

`include "dbg_config.vh"

module itm_trace_compression(/*AUTOARG*/
   // Outputs
   trace_out_compressed, trace_out_compressed_valid,
   // Inputs
   rst, clk, trace_in, trace_in_valid
   );

   /*
    * Width of the counter of sequential instructions between two branch
    * instructions.
    * This means 2^INSTR_COUNT_WIDTH instructions between two branch
    * instructions can be compressed as one trace message. If there are more
    * sequential instructions, a new trace message is required.
    * This is a configuration parameter of the trace compression algorithm,
    * a too large value will lead to unnecessary data in each compressed
    * trace message, a too small value causes unnecessary trace messages.
    */
   localparam INSTR_COUNT_WIDTH = 8;

   localparam TRACE_IN_WIDTH = `DBG_TIMESTAMP_WIDTH + 32;
   localparam COMPRESSED_TRACE_WIDTH = `DBG_TIMESTAMP_WIDTH + 32 + INSTR_COUNT_WIDTH;

   input rst;
   input clk;

   input [TRACE_IN_WIDTH-1:0] trace_in;
   input trace_in_valid;
   output reg [COMPRESSED_TRACE_WIDTH-1:0] trace_out_compressed;
   output reg trace_out_compressed_valid;

   reg [31:0] prev_wb_pc;
   reg [INSTR_COUNT_WIDTH-1:0] instr_cnt;

   reg [31:0] stream_sa;
   reg [`DBG_TIMESTAMP_WIDTH-1:0] stream_ts;

   reg bootaddr_found;

   wire [31:0] trace_in_wb_pc;
   wire [`DBG_TIMESTAMP_WIDTH-1:0] trace_in_ts;

   assign trace_in_wb_pc = trace_in[31:0];
   assign trace_in_ts = trace_in[TRACE_IN_WIDTH-1:TRACE_IN_WIDTH-`DBG_TIMESTAMP_WIDTH];

   always @ (posedge clk) begin
      if (rst) begin
         trace_out_compressed <= {COMPRESSED_TRACE_WIDTH{1'b0}};
         trace_out_compressed_valid <= 1'b0;
         instr_cnt <= {INSTR_COUNT_WIDTH{1'b0}};
         prev_wb_pc <= 32'b0;
         bootaddr_found <= 0;
         stream_ts <= {`DBG_TIMESTAMP_WIDTH{1'b0}};
         stream_sa <= 32'b0;
      end else begin
         if (trace_in_valid && trace_in_wb_pc != {32{1'b0}} &&
             (bootaddr_found || trace_in_wb_pc == `OR1200_BOOT_ADR)) begin

            if ((prev_wb_pc + 4 == trace_in_wb_pc) ||
                (prev_wb_pc == trace_in_wb_pc)) begin
               // found a sequential instruction (no branch)
               // FIXME: handle instr_cnt overflow!
               instr_cnt <= instr_cnt + 1;

               trace_out_compressed <= 0;
               trace_out_compressed_valid <= 1'b0;
            end else begin
               // found a nonsequential program flow
               // this is the first instruction in a new dynamic basic block

               // transmit the previous basic block, we're now at the first
               // basic block
               if (bootaddr_found) begin
                  trace_out_compressed <= {stream_ts, stream_sa, instr_cnt};
                  trace_out_compressed_valid <= 1'b1;
               end

               // start new stream
               stream_sa <= trace_in_wb_pc;
               stream_ts <= trace_in_ts;
               instr_cnt <= 1;
            end

            prev_wb_pc <= trace_in_wb_pc;

            bootaddr_found <= 1'b1;
         end else begin
            trace_out_compressed <= 0;
            trace_out_compressed_valid <= 1'b0;
         end
      end
   end

endmodule
