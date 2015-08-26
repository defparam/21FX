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
// Module Name: snes_hook (Verilog)
//
// Interfaces: (1) 40 MHz clock in
//             (2) address bus B and databus inputs
//             (3) SNES Reset and Address bus B Read and Write (all active low)
//
// Clock Domains: (1) 40 MHz (clk) - sourced on board clock
//                (2) async RAW snes addr/data bus, (typically switches around 2MHz - 3MHz)
//
// Description: This is the top level module for the SNES-Hook CPLD. It's only job ia to come
// out of reset search for the SNES CPU access to vector $00FFFC and override the reset vector
// to point to $2184. Futhermore the CPLD sits on address range $2184-$21FF and feeds its ROM
// contents to the SNES CPU during access. A primary bootloader is intended to be stored in this
// ROM and is defined in bootcode.hex


module snes_hook (
	input       clk,
	input       rst_n,
	input [7:0] addr,
	inout [7:0] data,
	input       PARD_n,
	input       PAWR_n
);

    reg [7:0] rom [0:123];
	initial $readmemh("bootcode.hex",rom); // define ROM with instructions from bootcode.hex
	
	parameter ST_SEARCH_FOR_RST_START = 2'b00;
	parameter ST_SEARCH_FOR_RST_HIGH  = 2'b10;
	parameter ST_SEARCH_FOR_RST_DONE  = 2'b11;
	parameter ST_RST_DONE             = 2'b01;

	reg [1:0] rst_search_state;
	reg       rst_low_enable;
	reg       rst_high_enable;
	reg       data_enable;
	wire      bus_latch;
	reg [7:0] data_out;
	
	snes_bus_sync bus_sync (
		.clk(clk),                    // clock (40 MHz and reset)
		.rst_n(rst_n),
		.D(data),                     // RAW SNES data bus
		.PA(addr),                    // RAW SNES addr bus
		.D_sync(),                    // Safely synchronized SNES data bus
		.PA_sync(),                   // Safely synchronized SNES addr bus
		.event_latch(bus_latch)       // Bus change event (detects changes in PA)
	);

	// Emulation RST vector hooking logic
	//
	// In this statemachine we assume the processor just came out of reset.
	// With that assumption we know that the first two address that will be
	// accessed is $00:FFFC and $00:FFFD. If we want to change the reset
	// vector address we need to identify the CPU cycle when the address is
	// on the data bus.

	always @(posedge clk or negedge rst_n) begin
		if (~rst_n) begin // reset regs
			rst_search_state  <= ST_SEARCH_FOR_RST_START;
			rst_low_enable    <= 1'b0;
			rst_high_enable   <= 1'b0;
		end else begin
			rst_low_enable  <= 1'b0; // helper flags default low
			rst_high_enable <= 1'b0;
		
			case (rst_search_state)
				// This is the first state, SNES has been reset and we are waiting for the
				// processor to go to the reset vector low address
				ST_SEARCH_FOR_RST_START: begin
					rst_low_enable <= 1'b1;
					if ((addr == 8'hFC) && (bus_latch)) begin // address found! next wait for the high word address
						rst_high_enable <= 1'b1;
						rst_search_state <= ST_SEARCH_FOR_RST_HIGH; // go to the high word search state
					end
				end
				
				ST_SEARCH_FOR_RST_HIGH: begin
					rst_low_enable <= 1'b1;
					rst_high_enable <= 1'b1;
					if ((addr == 8'hFD) && (bus_latch)) begin // address found! next wait until the bus leave this address
						rst_search_state <= ST_SEARCH_FOR_RST_DONE;
					end
				end
				
				ST_SEARCH_FOR_RST_DONE: begin
					rst_low_enable <= 1'b1;
					rst_high_enable <= 1'b1;			
					if ((addr != 8'hFD) && (bus_latch)) begin // Reset vector is complete drop the enable flag and go to a loop state
						rst_low_enable <= 1'b0;
						rst_high_enable <= 1'b0;
						rst_search_state <= ST_RST_DONE;
					end
				end
					
				ST_RST_DONE: begin // stay in a loop state until reset
					rst_low_enable <= 1'b0;
					rst_high_enable <= 1'b0;		
				end
				
				default:
					rst_search_state <= ST_SEARCH_FOR_RST_START;
			endcase	
		end 
	end

	
	always @(*) begin
		data_out = 0;
		data_enable = 0;
		
		if (rst_low_enable &&  (addr == 8'hFC)) data_out = 8'h84; // These lines override the vector when reset vector is detected
		if (rst_high_enable && (addr == 8'hFD)) data_out = 8'h21;
		
		if (addr[7] && |addr[6:2] && ~PARD_n) begin // If there is a read to addr $2184-$21FF, return contents addressed in ROM 
			data_out = rom[addr-8'h84];
			data_enable = 1;
		end

	end
		

	assign data = (rst_low_enable | rst_high_enable | data_enable) ? data_out : 8'hZZ; // Bi-directional databus assignments

endmodule
