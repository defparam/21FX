// SNES-Hook - A tiny 5V CPLD device to hijack reset on the SNES console
//
// Copyright (C) 2015 Evan Custodio
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
////////////////////////////////////////////////////////////////////////////
//
// Project Name: SNES-Hook
// Author: Evan Custodio (@defparam)
//
// Module Name: snes_bus_sync (Verilog)
//
// Interfaces: (1) SNES raw address bus and read/write enable signals
//             (2) Synced address bus and databus outputs
//             (3) Synced latch event signal during an address bus change
//
// Clock Domains: (1) 40 MHz (clk) - sourced on board clock
//                (2) async RAW snes ports, (typically switches around 2MHz - 3MHz)
//
// Description: A bus access is defined as an SNES access to the address A bus.
// The difference here between this module and the port sync module is that the port
// sync module has read and write enable signals to help realize the bus access. This
// module just observe the address bus for "address switches". Once this module synchronizes
// an address bus "switch" then logic in the 40Mhz domain can safely analyse Address A bus
// accesses. We use this in SNES-Tap to help locate when the processor accesses the reset vector
// and the NMI vector.


module snes_bus_sync (
	input        clk,              // clock (40 MHz and reset)
	input        rst_n,
	input  [7:0] PA,               // RAW SNES addr bus
	input  [7:0] D,                // RAW SNES data bus
	output [7:0] PA_sync,          // Safely synchronized SNES addr bus
	output [7:0] D_sync,           // Safely synchronized SNES data bus
	output       event_latch       // Bus change event (detects changes in PA)
);

	parameter OUT_OF_SYNC = 2'b01;
	parameter IN_SYNC     = 2'b10;

	reg [7:0] D_store;
	reg [7:0] PA_store [0:2];
	reg [1:0] sync_state = IN_SYNC;
	reg [4:0] clk_count = 0;

	reg bus_latch = 0;


	always @(posedge clk or negedge rst_n) begin
		if (~rst_n) begin
			PA_store[0] <= 8'b0; // reset all regs
			PA_store[1] <= 8'b0;
			PA_store[2] <= 8'b0;
			D_store     <= 8'b0;
			clk_count   <= 5'b0;
			bus_latch   <= 1'b0;
			sync_state  <= IN_SYNC;
		end
		else begin
			PA_store[0] <= PA;          // These registers are used for both metastability protection
			PA_store[1] <= PA_store[0]; // and for address bus "change" detection (3 stages)
			PA_store[2] <= PA_store[1];
			
			clk_count <= clk_count + 1; // Rolling clock counter
			
			if (clk_count == 18) begin  // Stop the clock at 18 clocks, addr bus has gone quiet
				bus_latch <= 0;
				clk_count <= clk_count;
			end
			
			if (sync_state == IN_SYNC) begin // IN_SYNC state means the bus has settled and events/outputs have been reported
				// The addr bus has been pipelined for 3 stages, move into the OUT_OF_SYNC state once a change in addr is detected
				// we also ignore this check if 5 cycles haven't gone by on the previous check
				if (((PA != PA_store[0]) || (PA_store[1] != PA_store[0]) || (PA_store[2] != PA_store[1])) && (clk_count > 5)) begin
					sync_state <= OUT_OF_SYNC; // go to OUT_OF_SYNC
					bus_latch <= 0;            // initialize
					clk_count <= 0;
				end
			end else if (sync_state == OUT_OF_SYNC) begin
				clk_count <= 0;
				bus_latch  <= 0;
				// The addr bus has under gone a change, detect when it has settled and move back into IN_SYNC
				if ((PA == PA_store[0]) && (PA_store[1] == PA_store[0]) && (PA_store[2] == PA_store[1])) begin
					sync_state <= IN_SYNC;
				end
			end
			// No other state exists, but move in IN_SYNC if the state is indeterminate
			else sync_state <= IN_SYNC;
			
			// According to the SNES bus timing specs, you can safely latch the data and addr 5x50meg cycles after addr change
			// (slow bus access)
			if (clk_count == 5) begin
				bus_latch <= 1;
				D_store   <= D;
			end

		end
	end
	
	// Report back safe synchronized bus events and data/addr
	assign D_sync         = D_store;
	assign PA_sync        = PA_store[2];
	assign event_latch    = bus_latch;

endmodule
