/******************************************************************************
 This Source Code Form is subject to the terms of the
 Open Hardware Description License, v. 1.0. If a copy
 of the OHDL was not distributed with this file, You
 can obtain one at http://juliusbaxter.net/ohdl/ohdl.txt

 Description: Data cache implementation

 Copyright (C) 2012-2013
    Stefan Kristiansson <stefan.kristiansson@saunalahti.fi>
    Stefan Wallentowitz <stefan.wallentowitz@tum.de>

 ******************************************************************************/

`include "mor1kx-defines.v"

module mor1kx_dcache
  #(
    parameter OPTION_OPERAND_WIDTH = 32,
    parameter OPTION_DCACHE_BLOCK_WIDTH = 5,
    parameter OPTION_DCACHE_SET_WIDTH = 9,
    parameter OPTION_DCACHE_WAYS = 2,
    parameter OPTION_DCACHE_LIMIT_WIDTH = 32
    )
   (
    input 			      clk,
    input 			      rst,

    input 			      dc_enable_i,
    input 			      dc_access_i,
    output 			      refill_o,
    output 			      refill_done_o,

    // CPU Interface
    output 			      cpu_err_o,
    output 			      cpu_ack_o,
    output reg [31:0] 		      cpu_dat_o,
    input [31:0] 		      cpu_dat_i,
    input [OPTION_OPERAND_WIDTH-1:0]  cpu_adr_i,
    input [OPTION_OPERAND_WIDTH-1:0]  cpu_adr_match_i,
    input 			      cpu_req_i,
    input 			      cpu_we_i,
    input [3:0] 		      cpu_bsel_i,

    input 			      refill_allowed,

    // BUS Interface
    input 			      dbus_err_i,
    input 			      dbus_ack_i,
    input [31:0] 		      dbus_dat_i,
    output [31:0] 		      dbus_dat_o,
    output [31:0] 		      dbus_adr_o,
    output 			      dbus_req_o,
    output [3:0] 		      dbus_bsel_o,

    // SPR interface
    input [15:0] 		      spr_bus_addr_i,
    input 			      spr_bus_we_i,
    input 			      spr_bus_stb_i,
    input [OPTION_OPERAND_WIDTH-1:0]  spr_bus_dat_i,

    output [OPTION_OPERAND_WIDTH-1:0] spr_bus_dat_o,
    output 			      spr_bus_ack_o
    );

   // States
   localparam IDLE		= 5'b00001;
   localparam READ		= 5'b00010;
   localparam WRITE		= 5'b00100;
   localparam REFILL		= 5'b01000;
   localparam INVALIDATE	= 5'b10000;

   // Address space in bytes for a way
   localparam WAY_WIDTH = OPTION_DCACHE_BLOCK_WIDTH + OPTION_DCACHE_SET_WIDTH;
   /*
    * Tag memory layout
    *            +---------------------------------------------------------+
    * (index) -> | LRU | wayN valid | wayN tag |...| way0 valid | way0 tag |
    *            +---------------------------------------------------------+
    */

   // The tag is the part left of the index
   localparam TAG_WIDTH = (OPTION_DCACHE_LIMIT_WIDTH - WAY_WIDTH);

   // The tag memory contains entries with OPTION_DCACHE_WAYS parts of
   // each TAGMEM_WAY_WIDTH. Each of those is tag and a valid flag.
   localparam TAGMEM_WAY_WIDTH = TAG_WIDTH + 1;
   localparam TAGMEM_WAY_VALID = TAGMEM_WAY_WIDTH - 1;

   // Additionally, the tag memory entry contains an LRU value. The
   // width of this is 0 for OPTION_DCACHE_LIMIT_WIDTH==1
   localparam TAG_LRU_WIDTH = OPTION_DCACHE_WAYS*(OPTION_DCACHE_WAYS-1) >> 1;

   // Compute the total sum of the entry elements
   localparam TAGMEM_WIDTH = TAGMEM_WAY_WIDTH * OPTION_DCACHE_WAYS + TAG_LRU_WIDTH;

   // For convenience we define the position of the LRU in the tag
   // memory entries
   localparam TAG_LRU_MSB = TAGMEM_WIDTH - 1;
   localparam TAG_LRU_LSB = TAG_LRU_MSB - TAG_LRU_WIDTH + 1;

   // FSM state signals
   reg [4:0] 			      state;
   wire				      idle;
   wire				      read;
   wire				      write;
   wire				      refill;

   reg [31:0] 			      dbus_adr;
   wire [31:0] 			      next_dbus_adr;
   reg [31:0] 			      way_wr_dat;
   wire 			      refill_done;
   wire 			      refill_hit;
   reg [(1<<(OPTION_DCACHE_BLOCK_WIDTH-2))-1:0] refill_valid;
   reg [(1<<(OPTION_DCACHE_BLOCK_WIDTH-2))-1:0] refill_valid_r;
   wire				      invalidate;

   // The index we read and write from tag memory
   wire [OPTION_DCACHE_SET_WIDTH-1:0] tag_rindex;
   wire [OPTION_DCACHE_SET_WIDTH-1:0] tag_windex;

   // The data from the tag memory
   wire [TAGMEM_WIDTH-1:0] 	      tag_dout;
   wire [TAG_LRU_WIDTH-1:0] 	      tag_lru_out;
   wire [TAGMEM_WAY_WIDTH-1:0] 	      tag_way_out [OPTION_DCACHE_WAYS-1:0];

   // The data to the tag memory
   wire [TAGMEM_WIDTH-1:0] 	      tag_din;
   reg [TAG_LRU_WIDTH-1:0] 	      tag_lru_in;
   reg [TAGMEM_WAY_WIDTH-1:0] 	      tag_way_in [OPTION_DCACHE_WAYS-1:0];

   // Whether to write to the tag memory in this cycle
   reg 				      tag_we;

   // This is the tag we need to write to the tag memory during refill
   wire [TAG_WIDTH-1:0] 	      tag_wtag;

   // This is the tag we check against
   wire [TAG_WIDTH-1:0] 	      tag_tag;

   // Access to the way memories
   wire [WAY_WIDTH-3:0] 	      way_raddr[OPTION_DCACHE_WAYS-1:0];
   wire [WAY_WIDTH-3:0] 	      way_waddr[OPTION_DCACHE_WAYS-1:0];
   wire [OPTION_OPERAND_WIDTH-1:0]    way_din[OPTION_DCACHE_WAYS-1:0];
   wire [OPTION_OPERAND_WIDTH-1:0]    way_dout[OPTION_DCACHE_WAYS-1:0];
   reg [OPTION_DCACHE_WAYS-1:0]       way_we;

   // Does any way hit?
   wire 			      hit;
   wire [OPTION_DCACHE_WAYS-1:0]      way_hit;

   // This is the least recently used value before access the memory.
   // Those are one hot encoded.
   wire [OPTION_DCACHE_WAYS-1:0]      lru;

   // Register that stores the LRU value from lru
   reg [OPTION_DCACHE_WAYS-1:0]       tag_save_lru;

   // The access vector to update the LRU history is the way that has
   // a hit or is refilled. It is also one-hot encoded.
   reg [OPTION_DCACHE_WAYS-1:0]       access;

   // The current LRU history as read from tag memory and the update
   // value after we accessed it to write back to tag memory.
   wire [TAG_LRU_WIDTH-1:0]           current_lru_history;
   wire [TAG_LRU_WIDTH-1:0]           next_lru_history;

   // Intermediate signals to ease debugging
   wire [TAG_WIDTH-1:0]               check_way_tag [OPTION_DCACHE_WAYS-1:0];
   wire                               check_way_match [OPTION_DCACHE_WAYS-1:0];
   wire                               check_way_valid [OPTION_DCACHE_WAYS-1:0];

   reg 				      write_pending;

   genvar 			      i;

   assign cpu_err_o = dbus_err_i;
   assign cpu_ack_o = ((read | refill) & hit & !write_pending |
		       refill_hit) & cpu_req_i;
   assign dbus_adr_o = dbus_adr;
   assign dbus_req_o = refill;
   assign dbus_dat_o = cpu_dat_i;
   assign dbus_bsel_o = 4'b1111;

   assign tag_rindex = cpu_adr_i[WAY_WIDTH-1:OPTION_DCACHE_BLOCK_WIDTH];
   /*
    * The tag mem is written during reads and writes to write the lru info and
    * during refill and invalidate.
    */
   assign tag_windex = read | write ?
		       cpu_adr_match_i[WAY_WIDTH-1:OPTION_DCACHE_BLOCK_WIDTH] :
		       dbus_adr[WAY_WIDTH-1:OPTION_DCACHE_BLOCK_WIDTH];

   assign tag_tag = cpu_adr_match_i[OPTION_DCACHE_LIMIT_WIDTH-1:WAY_WIDTH];
   assign tag_wtag = dbus_adr[OPTION_DCACHE_LIMIT_WIDTH-1:WAY_WIDTH];

   generate
      if (OPTION_DCACHE_WAYS >= 2) begin
         // Multiplex the LRU history from and to tag memory
         assign current_lru_history = tag_dout[TAG_LRU_MSB:TAG_LRU_LSB];
         assign tag_din[TAG_LRU_MSB:TAG_LRU_LSB] = tag_lru_in;
         assign tag_lru_out = tag_dout[TAG_LRU_MSB:TAG_LRU_LSB];
      end

      for (i = 0; i < OPTION_DCACHE_WAYS; i=i+1) begin : ways
	 assign way_raddr[i] = cpu_adr_i[WAY_WIDTH-1:2];
	 assign way_waddr[i] = write ? cpu_adr_match_i[WAY_WIDTH-1:2] :
			       dbus_adr[WAY_WIDTH-1:2];
	 assign way_din[i] = way_wr_dat;

	 // compare stored tag with incoming tag and check valid bit
         assign check_way_tag[i] = tag_way_out[i][TAGMEM_WAY_WIDTH-1:0];
         assign check_way_match[i] = (check_way_tag[i] == tag_tag);
         assign check_way_valid[i] = tag_way_out[i][TAGMEM_WAY_VALID];

         assign way_hit[i] = check_way_valid[i] & check_way_match[i];

         // Multiplex the way entries in the tag memory
         assign tag_din[(i+1)*TAGMEM_WAY_WIDTH-1:i*TAGMEM_WAY_WIDTH] = tag_way_in[i];
         assign tag_way_out[i] = tag_dout[(i+1)*TAGMEM_WAY_WIDTH-1:i*TAGMEM_WAY_WIDTH];
      end
   endgenerate

   assign hit = |way_hit;

   integer w;

   always @(*) begin
      cpu_dat_o = {OPTION_OPERAND_WIDTH{1'bx}};

      // Put correct way on the data port
      for (w = 0; w < OPTION_DCACHE_WAYS; w = w + 1) begin
         if (way_hit[w] | (refill_hit & tag_save_lru[w])) begin
            cpu_dat_o = way_dout[w];
         end
      end
   end

   assign next_dbus_adr = (OPTION_DCACHE_BLOCK_WIDTH == 5) ?
			  {dbus_adr[31:5], dbus_adr[4:0] + 5'd4} : // 32 byte
			  {dbus_adr[31:4], dbus_adr[3:0] + 4'd4};  // 16 byte

   assign refill_done_o = refill_done;
   assign refill_done = refill_valid[next_dbus_adr[OPTION_DCACHE_BLOCK_WIDTH-1:2]];
   assign refill_hit = refill_valid_r[cpu_adr_match_i[OPTION_DCACHE_BLOCK_WIDTH-1:2]] &
		       cpu_adr_match_i[OPTION_DCACHE_LIMIT_WIDTH-1:
				       OPTION_DCACHE_BLOCK_WIDTH] ==
		       dbus_adr[OPTION_DCACHE_LIMIT_WIDTH-1:
				OPTION_DCACHE_BLOCK_WIDTH] &
		       refill & !write_pending;

   assign idle = (state == IDLE);
   assign refill = (state == REFILL);
   assign read = (state == READ);
   assign write = (state == WRITE);

   assign refill_o = refill;

   /*
    * SPR bus interface
    */

   // The SPR interface is used to invalidate the cache blocks. When
   // an invalidation is started, the respective entry in the tag
   // memory is cleared. When another transfer is in progress, the
   // handling is delayed until it is possible to serve it.
   //
   // The invalidation is acknowledged to the SPR bus, but the cycle
   // is terminated by the core. We therefore need to hold the
   // invalidate acknowledgement. Meanwhile we continuously write the
   // tag memory which is no problem.

   // Net that signals an acknowledgement
   reg invalidate_ack;

   // An invalidate request is either a block flush or a block invalidate
   assign invalidate = spr_bus_stb_i & spr_bus_we_i &
		       (spr_bus_addr_i == `OR1K_SPR_DCBFR_ADDR |
			spr_bus_addr_i == `OR1K_SPR_DCBIR_ADDR);

   // Acknowledge to the SPR bus.
   assign spr_bus_ack_o = invalidate_ack;

   /*
    * Cache FSM
    * Starts in IDLE.
    * State changes between READ and WRITE happens cpu_we_i is asserted or not.
    * cpu_we_i is in sync with cpu_adr_i, so that means that it's the
    * *upcoming* write that it is indicating. It only toggles for one cycle,
    * so if we are busy doing something else when this signal comes
    * (i.e. refilling) we assert the write_pending signal.
    * cpu_req_i is in sync with cpu_adr_match_i, so it can be used to
    * determined if a cache hit should cause a refill or if a write should
    * really be executed.
    */
   always @(posedge clk `OR_ASYNC_RST) begin
      if (rst | dbus_err_i) begin
	 state <= IDLE;
	 write_pending <= 0;
      end else begin
	 if (cpu_we_i)
	   write_pending <= 1;
	 else if (!cpu_req_i)
	   write_pending <= 0;

	 refill_valid_r <= refill_valid;

	 case (state)
	   IDLE: begin
	      if (invalidate) begin
		 // If there is an invalidation request
		 //
		 // Store address in dbus_adr that is muxed to the tag
		 // memory write address
		 dbus_adr <= spr_bus_dat_i;

		 // Change to invalidate state that actually accesses
		 // the tag memory
		 state <= INVALIDATE;
	      end else if (cpu_we_i | write_pending)
		state <= WRITE;
	      else if (cpu_req_i)
		state <= READ;
	   end

	   READ: begin
	      if (dc_access_i | cpu_we_i & dc_enable_i) begin
		 if (!hit & cpu_req_i & !write_pending & refill_allowed) begin
		    refill_valid <= 0;
		    refill_valid_r <= 0;
		    dbus_adr <= cpu_adr_match_i;

		    // Store the LRU information for correct replacement
                    // on refill. Always one when only one way.
                    tag_save_lru <= (OPTION_DCACHE_WAYS==1) | lru;

		    state <= REFILL;
		 end else if (cpu_we_i | write_pending) begin
		    state <= WRITE;
		 end
	      end else if (!dc_enable_i) begin
		 state <= IDLE;
	      end
	   end
	   REFILL: begin
	      if (dbus_ack_i) begin
		 dbus_adr <= next_dbus_adr;
		 refill_valid[dbus_adr[OPTION_DCACHE_BLOCK_WIDTH-1:2]] <= 1;

		 if (refill_done)
		   state <= IDLE;
	      end
	   end

	   WRITE: begin
	      if (!dc_access_i | !cpu_req_i | !cpu_we_i) begin
		 write_pending <= 0;
		 state <= READ;
	      end
	   end

	   INVALIDATE: begin
	      if (invalidate) begin
		 // Store address in dbus_adr that is muxed to the tag
		 // memory write address
		 dbus_adr <= spr_bus_dat_i;

		 state <= INVALIDATE;
	      end else begin
		 state <= IDLE;
	      end
	   end

	   default:
	     state <= IDLE;
	 endcase // case (state)
      end // else: !if(rst | dbus_err_i)
   end // always @ (posedge clk `OR_ASYNC_RST)

   // This is the combinational part of the state machine that
   // interfaces the tag and way memories.

   always @(*) begin
      // Default is to keep data, don't write and don't access
      tag_lru_in = tag_lru_out;
      for (w = 0; w < OPTION_DCACHE_WAYS; w = w + 1) begin
         tag_way_in[w] = tag_way_out[w];
      end

      tag_we = 1'b0;
      way_we = {(OPTION_DCACHE_WAYS){1'b0}};

      access = {(OPTION_DCACHE_WAYS){1'b0}};

      way_wr_dat = dbus_dat_i;

      // The default is (of course) not to acknowledge the invalidate
      invalidate_ack = 1'b0;

      case (state)
	IDLE: begin
	   // When idle we can always acknowledge the invalidate as it
	   // has the highest priority in handling. When something is
	   // changed on the state machine handling above this needs
	   // to be changed.
	   invalidate_ack = 1'b1;
	end
	READ: begin
	   if (hit) begin
	      // We got a hit. The LRU module gets the access
              // information. Depending on this we update the LRU
              // history in the tag.
              access = way_hit;

              // This is the updated LRU history after hit
              tag_lru_in = next_lru_history;

	      tag_we = 1'b1;
	   end
	end

	WRITE: begin
	   way_wr_dat = cpu_dat_i;
	   if (hit & cpu_req_i) begin
	      /* Mux cache output with write data */
	      if (!cpu_bsel_i[3])
		way_wr_dat[31:24] = cpu_dat_o[31:24];
	      if (!cpu_bsel_i[2])
		way_wr_dat[23:16] = cpu_dat_o[23:16];
	      if (!cpu_bsel_i[1])
		way_wr_dat[15:8] = cpu_dat_o[15:8];
	      if (!cpu_bsel_i[0])
		way_wr_dat[7:0] = cpu_dat_o[7:0];

	      way_we = way_hit;
	      
	      tag_lru_in = next_lru_history;

	      tag_we = 1'b1;
	   end
	end

	REFILL: begin
	   if (dbus_ack_i) begin
              // Write the data to the way that is replaced (which is
              // the LRU)
              way_we = tag_save_lru;

	      // Access pattern
	      access = tag_save_lru;

	      /* Invalidate the way on the first write */
	      if (refill_valid == 0) begin
		 for (w = 0; w < OPTION_DCACHE_WAYS; w = w + 1) begin
                    if (tag_save_lru[w]) begin
                       tag_way_in[w][TAGMEM_WAY_VALID] = 1'b0;
                    end
                 end

		 tag_we = 1'b1;
	      end

	      // After refill update the tag memory entry of the
              // filled way with the LRU history, the tag and set
              // valid to 1.
	      if (refill_done) begin
		 for (w = 0; w < OPTION_DCACHE_WAYS; w = w + 1) begin
                    if (tag_save_lru[w]) begin
                       tag_way_in[w] = { 1'b1, tag_wtag };
                    end
                 end
                 tag_lru_in = next_lru_history;

		 tag_we = 1'b1;
	      end
	   end
	end

	INVALIDATE: begin
	   invalidate_ack = 1'b1;

	   // Lazy invalidation, invalidate everything that matches tag address
           tag_lru_in = 0;
           for (w = 0; w < OPTION_DCACHE_WAYS; w = w + 1) begin
              tag_way_in[w] = 0;
           end

	   tag_we = 1'b1;
	end

	default: begin
	end
      endcase
   end

   generate
      for (i = 0; i < OPTION_DCACHE_WAYS; i=i+1) begin : way_memories
	 mor1kx_simple_dpram_sclk
	       #(
		 .ADDR_WIDTH(WAY_WIDTH-2),
		 .DATA_WIDTH(OPTION_OPERAND_WIDTH),
		 .ENABLE_BYPASS("TRUE")
		 )
	 way_data_ram
	       (
		// Outputs
		.dout			(way_dout[i]),
		// Inputs
		.clk			(clk),
		.raddr			(way_raddr[i][WAY_WIDTH-3:0]),
		.waddr			(way_waddr[i][WAY_WIDTH-3:0]),
		.we			(way_we[i]),
		.din			(way_din[i][31:0]));

      end // block: way_memories

      if (OPTION_DCACHE_WAYS >= 2) begin : gen_u_lru
         /* mor1kx_cache_lru AUTO_TEMPLATE(
          .current  (current_lru_history),
          .update   (next_lru_history),
          .lru_pre  (lru),
          .lru_post (),
          .access   (access),
          ); */

         mor1kx_cache_lru
           #(.NUMWAYS(OPTION_DCACHE_WAYS))
         u_lru(/*AUTOINST*/
	       // Outputs
	       .update			(next_lru_history),	 // Templated
	       .lru_pre			(lru),			 // Templated
	       .lru_post		(),			 // Templated
	       // Inputs
	       .current			(current_lru_history),	 // Templated
	       .access			(access));		 // Templated
      end // if (OPTIMSOC_DCACHE_WAYS >= 2)
   endgenerate

   mor1kx_simple_dpram_sclk
     #(
       .ADDR_WIDTH(OPTION_DCACHE_SET_WIDTH),
       .DATA_WIDTH(TAGMEM_WIDTH),
       .ENABLE_BYPASS("TRUE")
     )
   tag_ram
     (
      // Outputs
      .dout				(tag_dout[TAGMEM_WIDTH-1:0]),
      // Inputs
      .clk				(clk),
      .raddr				(tag_rindex),
      .waddr				(tag_windex),
      .we				(tag_we),
      .din				(tag_din));

endmodule
