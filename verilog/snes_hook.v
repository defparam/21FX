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
	input                clk,
	input                rst_n,
	input [7:0]          addr,
	inout [7:0]          data,
	input                PARD_n,
	input                PAWR_n,
	input                USB_RXFn,
	input                USB_TXEn,
	output reg           USB_RDn,
	output reg           USB_WRn,
	input                USB_CLK,
	output reg           USB_OEn,
	output reg           ROM_oe_n,
	output reg           ROM_wr_n,	
	output reg [3:0]     glitch_force
);
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
		.PA(addr),                    // RAW SNES addr bus
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
		USB_OEn      = 1;
		ROM_oe_n     = 1;
		ROM_wr_n     = 1;
		data_out     = 0;
		data_enable  = 0;
		glitch_force = 4'bZZZZ;
		if (rst_low_enable &&  (addr == 8'hFC)) begin
			data_out        = 8'h84; //Bit 7 and Bit 2 // These lines override the vector when reset vector is detected
			glitch_force[2] = 1'b1;
			glitch_force[1] = 1'b1;
		end
		if (rst_low_enable && (addr == 8'hFD)) begin
			data_out        = 8'h21; //Bit 5 and Bit 0
			glitch_force[3] = 1'b1;
			glitch_force[0] = 1'b1;
		end
		if (addr == 8'hFF && ~PARD_n) begin
			USB_OEn = 0;
		end
	   else if (addr == 8'hFE && ~PARD_n) begin
			data_out = {6'b0,USB_RXFn,USB_TXEn};
			data_enable = 1;
		end
		else if (addr[7] && |addr[6:2] && ~PARD_n) begin // If there is a read to addr $2184-$21FF, return contents addressed in ROM 
			ROM_oe_n = 0;
		end
	end
	
	reg ftdi_rd_go;
	reg ftdi_wr_go;
	
	always @(posedge clk or negedge rst_n) begin
		if (~rst_n) begin
			ftdi_rd_go <= 1'b0;
			ftdi_wr_go <= 1'b0;
		end
		else
		if (bus_latch) begin
			ftdi_rd_go <= 1'b0;
			ftdi_wr_go <= 1'b0;
			if ((addr == 8'hFF) && (~PAWR_n)) begin
				ftdi_wr_go <= 1'b1;
			end
			if ((addr == 8'hFF) && (~PARD_n)) begin
				ftdi_rd_go <= 1'b1;
			end
		end
	end
	
	reg rd_m0,rd_m1;
	reg wr_m0,wr_m1;
	reg in_prog;
	always @(posedge USB_CLK or negedge rst_n) begin
		if (~rst_n) begin
			rd_m0   <= 1'b0; 
			rd_m1   <= 1'b0;
			wr_m0   <= 1'b0; 
			wr_m1   <= 1'b0;
			in_prog <= 1'b0;
			USB_RDn <= 1'b1;
			USB_WRn <= 1'b1;
		end else begin
			rd_m0 <= ftdi_rd_go;
			rd_m1 <= rd_m0;
			wr_m0 <= ftdi_wr_go;
			wr_m1 <= wr_m0;
			USB_RDn <= 1'b1;
			USB_WRn <= 1'b1;
			if (~in_prog && rd_m1) begin
				USB_RDn <= 1'b0;
				in_prog <= 1'b1;
			end	
			if (~in_prog && wr_m1) begin
				USB_WRn <= 1'b0;
				in_prog <= 1'b1;
			end
			if (~rd_m1 && ~wr_m1) in_prog <= 1'b0;
		end
	end

	assign data = (rst_low_enable | rst_high_enable | data_enable) ? data_out : 8'hZZ; // Bi-directional databus assignments
	
endmodule
