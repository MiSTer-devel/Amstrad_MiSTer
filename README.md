# Amstrad CPC 6128 for MiSTer
This core is port of [CoreAmstrad by Renaud Hélias](https://github.com/renaudhelias/CoreAmstrad).

## New features in this port
* 2 disk drives with real write support.
* Selectable 6128/664 mode with separate ROM sets
* Multiface 2
* Better CPU timings due to more presize model.

## Installation
place RBF and amstrad.rom into root of SD card. Or you can rename ROM to boot.rom and put it into Amstrad folder.

## Disk support
Put some *.DSK files to Amstrad folder and mount it from OSD menu.
important Basic commands:
* cat - list the files on mounted disk.
* run" - load and start the program. ex: run"equinox

## ROM
Rom has following structure:

OS6128 + BASIC1.1 + AMSDOS + MF2 + OS664 + BASIC664 + AMSDOS + MF2

Every part is 16KB. You can create your own ROM if you have a special preference.
