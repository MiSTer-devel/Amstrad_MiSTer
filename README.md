# Amstrad CPC 6128 for MiSTer
This core is port of [CoreAmstrad by Renaud Hélias](https://github.com/renaudhelias/CoreAmstrad).

## Features
Besides the refactoring, this version has completely rewritten Floppy Disk Controller allowing real write to floppy.
u765 by Gyorgy Szombathelyi is used as FDC.

Unlike original CoreAmstrad, this core uses consolidated ROM (amstrad.rom) which is hardcoded to use lowROM + highROM0 + highROM7.
The ROM part probably needs to be improved in order to use custom ROMs split across separate parts. It will depends on future requests.

## Disk support
Put some *.DSK files to Amstrad folder and mount it from OSD menu.
important Basic commands:
* cat - list the files on mounted disk.
* run" - load and start the program. ex: run"equinox
