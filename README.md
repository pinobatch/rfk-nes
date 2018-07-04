robotfindskitten for NES
========================

robotfindskitten is a "Zen simulation" originally written by Leonard
Richardson as an entry to a game jam in 1997.  It won by default.

This program implements [robotfindskitten] on the Nintendo
Entertainment System, mostly following the [RFK RFC] with
a few minor willful deviations to fit NES constraints.

[robotfindskitten]: http://robotfindskitten.org/
[RFK RFC]: http://robotfindskitten.org/download/rfk-rfc/rfk-01.pdf

Build
-----
Install ca65, GNU Make, Python 3, and Pillow per instructions at
<https://github.com/pinobatch/nrom-template/>

Play
----
In this game, you are robot (`#`).  Your job is to find a
kitten hiding from Sirhan.  This task is complicated by the
existence of various things which are not kitten.  Robot must
touch items to determine if they are kitten or not.
The game ends when robotfindskitten.

Use the Control Pad on controller 1 or controller 2 to move robot.
Bump into an object to see if it is kitten.  If it is, you win!
If not, the description of a non-kitten item (NKI) will appear on
your side of the status.

Customize
---------
The files `src/*.nki` define non-kitten items.  The `makefile`
defines which files are used.  Each nonblank line in these files
that does not start with a `#` (robot) defines one NKI and MUST NOT
exceed 72 characters nor use code points outside Basic Latin (ASCII).

Deviations
----------
There are two instances of robot, one for each controller port.
Each moves independently and has its own half of the Status.
As robot is not kitten, finding robot displays a special NKI.

Because of the reduced width available for NKI text in a two-robot
simulation, the Status is four lines instead of three, with the NKI
occupying the second through fourth lines.  The underscores
separating the Status from the Field overlap the fourth line.

The Field consists of 48 by 24 cells, each occupying 5 by 7 pixels.
NKI count cannot be configured, nor is diagonal movement possible.
Because items in the Field are drawn as sprites, there is a limit on
how many items can occupy one row of the Field.

To quit the simulation, turn off the power, or if the simulation
has been exit patched, press the Reset button on the Control Deck.
(Examples of exit patched simulations include the one included in
_Action 53_.)

NKI descriptions are hardcoded because the NES has no file system.
Because this port of robotfindskitten was developed for _Action 53_,
more included NKIs allude to the first two volumes of _Action 53_
than one might expect otherwise.  As described in "Customize", one
can edit the NKI files and reassemble the program for a larger pool,
but this pool cannot exceed 28 KiB once compressed with digram tree
encoding (DTE), also called [byte pair encoding] (BPE).

[byte pair encoding]: https://en.wikipedia.org/wiki/Byte_pair_encoding

Legal
-----
Copyright 2014 Damian Yerrick

zlib License
