# SNES-Hook (An SNES Primary Bootloader)
This project includes Altium and verilog design files for an SNES CPLD 
expansion port to perform a simple reset hijacking and present a primary 
bootloader for the SNES to use. The bootloader is intended to be used in
conjunction with byuu's Controller Port Serial Cable for uploading
executable code into WRAM. 

SNES-Hook v1.0 (Full Release)
---------------------------------------------------------------------
This a preliminary full release of SNES-Hook. In the release is the 
verilog files, Altium board design files and the quartus project which 
targets the MAX7000S CPLD on the SNES-Hook board.

SNES-Hook v1.1 REV B (Full Release)
---------------------------------------------------------------------
Updated top verilog file to include 2 more force/glitch outputs for
providing extra current strength on the glitched lines.

Updates
---------------------------------------------------------------------
1/31/2016 - REV B Boards came back from OSHPark and no flaws were found. Components
were soldered onto the board and the bootloader was tested successfully. So
far there are no issues found with this design. 2 new outputs were added to the
glitched address lines to ensure that SNES-Hook will win in bus contention.

TODO
---------------------------------------------------------------------
Update bootcode.hex with a bootloader supplied by byuu for use with
his Controller Port Serial Cable.


@defparam
