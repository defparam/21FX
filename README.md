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

Updates
---------------------------------------------------------------------
9/23/2015 - Boards came back from OSHPark and no flaws were found. Components
were soldered onto the board and the bootloader was tested successfully. So
far there are no issues found with this design.

TODO
---------------------------------------------------------------------
Update bootcode.hex with a bootloader supplied by byuu for use with
his Controller Port Serial Cable.


@defparam
