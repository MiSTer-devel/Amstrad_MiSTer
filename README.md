# Amstrad CPC 6128 for MiSTer
This core is port of [CoreAmstrad by Renaud Hélias](https://github.com/renaudhelias/CoreAmstrad).

## New features in this port
* 2 disk drives with real write support.
* Selectable 6128/664 mode with separate ROM sets
* Multiface 2
* Better CPU timings due to more presize model.
* Selectable expansion ROM loading.

## Installation
place RBF and amstrad.rom into root of SD card. Or you can rename ROM to boot.rom and put it into Amstrad folder.

## Disk support
Put some *.DSK files into Amstrad folder and mount it from OSD menu.
important Basic commands:
* cat - list the files on mounted disk.
* run" - load and start the program. ex: run"equinox
* |a, |b - switch between drives

## Boot ROM
Boot ROM has following structure:

OS6128 + BASIC1.1 + AMSDOS + MF2 + OS664 + BASIC664 + AMSDOS + MF2

Every part is 16KB. You can create your own ROM if you have a special preference.

## Expansion ROM
Expansion ROM should have file extension .eXX, where XX is hex number 00-FF of ROM page to load.
Every page is 16KB. It's possible to load larger ROM. In this case every 16KB block will be loaded in subsequent pages.

### Special extensions:
* eZZ - LowROM(OS)
* eZ0 - LowROM(OS) + Page 0(Basic) + subsequent pages depending on size.

### Notes
You can load several expansions. With every load the system will reboot. System ROM also can be replaced the same way.
To restore original ROM you have to reload the core (Alt-F12).

CPC664 model has only 64KB RAM - use this model for programs not compatible with 128KB RAM.

CPC6128 model has 64KB+512KB RAM. Upper 448KB are visible in special OS ROM or application aware of 512KB expansion.

## Multiface 2
* Multiface 2 can be activated with F11.
* USER LED shows if the MF2 ROM/RAM is active.
* Returning from the MF2 menu via (r)eturn makes the device invisible.
* Visibility can be restored via machine reset (original MF 2+).
* For loading a saved game, MF2 must be visible.
* ROM version is 8D.
