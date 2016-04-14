<center><img src="https://github.com/defparam/defparam.github.io/blob/master/public/sh1.png" style="width: 400px;"/></center>
# 21FX - An SNES Primary Bootloader (formerly SNES-Hook) 
This project includes Altium and verilog design files for an SNES CPLD 
expansion port to perform a simple reset hijacking and present a primary 
bootloader for the SNES to use. The bootloader is intended to be used in
conjunction with byuu's Controller Port Serial Cable for uploading
executable code into WRAM.


Updates
---------------------------------------------------------------------
4/14/2016 - REV C boards back and tested working. The boards now conform
to the new SNES expansion bridge DB-25 connector. byuu has produced the IPLROM
which is programmed to the EEPROM. Couple of issues with some power off noise
to the 232H but nothing serious



21FX - Rev C (Full Release)
---------------------------------------------------------------------
In this release we have changed the entire form factor of the board.
The board now conforms to a DB-25 connector and will mate to the new
SNES expansion bridge. We have also kept the same size CPLD and decided
to keep the IPLROM on a separate microchip 5v parallel eeprom chip. Lastly
the project no longer targets byuu's USART board. It instead has the connector
footprint for the Adafruit FT232H USB transceiver board. The IPLROM targets
all back and forth communication through this device.


SNES-Hook v1.1 REV B (Full Release)
---------------------------------------------------------------------
Updated top verilog file to include 2 more force/glitch outputs for
providing extra current strength on the glitched lines.

SNES-Hook v1.0 (Full Release)
---------------------------------------------------------------------
This a preliminary full release of SNES-Hook. In the release is the 
verilog files, Altium board design files and the quartus project which 
targets the MAX7000S CPLD on the SNES-Hook board.


@defparam
