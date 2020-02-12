#!/usr/bin/env python3
"""
Word-wrap all NKIs in a collection to ensure that there are none
that wrap to four lines.
"""
from vwfbuild import vwfcvt, ca65_bytearray
from dtefe import dte_compress, dte_uncompress
import argparse
import heapq
import sys

def vwf_wrap(bpebuf, wrap_width, widths, minchar=32):
    """Iterate over lines of text no longer than wrap_width

bpebuf -- the byte string to convert
wrap_width -- maximum pixels per line
widths -- width in pixel of each character's glyph starting at 0x20
minchar -- first code unit in widths

Return an iterator over the lines."""
    total_pixels = 0  # pen position
    last_space_offset = 0  # Offset at which to insert '\n'
    last_space_pixels = 0  # total_pixels after last space
    line_start_offset = 0
    for y, c in enumerate(bpebuf):
        c = bpebuf[y]
        total_pixels += widths[c - minchar]
        if c == 32:  # Space
            # beq isspace taken
            last_space_pixels = total_pixels
            last_space_offset = y
        elif total_pixels >= wrap_width:
            # bcc nextchar not taken
            total_pixels -= last_space_pixels
            yield bpebuf[line_start_offset:last_space_offset]
            line_start_offset = last_space_offset + 1
    lastline = bpebuf[line_start_offset:]
    if lastline: yield lastline

def vwf_fill(bpebuf, wrap_width, vwfChrWidths):
    return "\n".join(vwf_wrap(bpebuf, wrap_width, vwfChrWidths))

def parse_argv(argv):
    parser = argparse.ArgumentParser(
        description="Check and compress NKIs for robotfindskitten."
    )
    parser.add_argument("nkis", metavar="NKI", nargs='+',
                        help="list of NKI files")
    parser.add_argument("--wrap-font",
                        help="filename of 8x8 pixel font for word wrap check")
    parser.add_argument("--wrap-width", type=int, default=112,
                        help="pixel width for word wrap check")
    return parser.parse_args(argv[1:])


# Compress for for robotfindskitten
def nki_main(argv=None):

    # Load input files
    args = parse_argv(argv or sys.argv)
    lines = []
    for filename in args.nkis:
        with open(filename, 'rU') as infp:
            lines.extend(row.strip() for row in infp)

    # Remove blank lines and comments
    lines = [row.encode('ascii')
             for row in lines
             if row and not row.startswith('#')]

    # Diagnostic for line length.  RFK RFC forbids lines longer than
    # 72 characters, and longer lines may wrap to more than 3 lines.
    lgst = heapq.nlargest(10, lines, len)
    if len(lgst[0]) > 72:
        print("Some NKIs are too long (more than 72 characters):", file=sys.stderr)
        print("\n".join(line.decode("ascii") for line in lgst if len(line) > 72), file=sys.stderr)
    else:
        print("Longest NKI is OK at %d characters. Don't let it get any longer."
              % len(lgst[0]), file=sys.stderr)
        print(lgst[0], file=sys.stderr)

    # Some 70- to 72-character NKIs were found to wrap to 4 lines
    # anyway.
    if args.wrap_font:
        vwfChrWidths, _ = vwfcvt(args.wrap_font)
        wrapped = [list(vwf_wrap(x, args.wrap_width, vwfChrWidths))
                   for x in lines]
        wrapped = [x for x in wrapped if len(x) > 3]
        if wrapped:
            msg = (
                "%d NKIs exceed 3 lines and will display incorrectly:\n"
                if len(wrapped) > 1
                else "%d NKI exceeds 3 line and will display incorrectly:\n"
            )
            print(msg % (len(wrapped),), file=sys.stderr)
            print("\n\n".join("\n".join(line.decode("ascii") for line in x)
                            for x in wrapped),
                  file=sys.stderr)

    oldinputlen = sum(len(line) + 1 for line in lines)

    lines, replacements, _ = dte_compress(lines)

    finallen = len(replacements) * 2 + sum(len(line) + 1 for line in lines)
    stkd = max(dte_uncompress(line, replacements)[1] for line in lines)
    print("from %d to %d bytes with peak stack depth: %d"
          % (oldinputlen, finallen, stkd), file=sys.stderr)

    replacements = b''.join(replacements)
    num_nkis = len(lines)
    lines = b''.join(line + b'\x00' for line in lines)
    outfp = sys.stdout
    outfp.write("""; Generated with dte.py; do not edit
.export NUM_NKIS, nki_descriptions, nki_replacements
NUM_NKIS = %d
.segment "NKIDATA"
nki_descriptions:
%s
nki_replacements:
%s
""" % (num_nkis, ca65_bytearray(lines), ca65_bytearray(replacements)))
    

def main(argv):
    vwffilename = "../tilesets/vwf7.png"
    nkifilename = "../src/wraptofourlines.nki"

    widths, _ = vwfcvt(vwffilename)
    with open(nkifilename, "r") as infp:
        nkis = [x.strip() for x in infp]
    nkis = [x for x in nkis if x and not x.startswith("#")]

    for x in nkis:
        lines = list(vwf_wrap(x, 112, widths))
        print(lines)


if __name__=='__main__':
    if 'idlelib' in sys.modules:
        nki_main([
            sys.argv[0],
            "--wrap-width", "112", "--wrap-font", "../tilesets/vwf7.png",
            "../src/fixed.nki", "../src/default.nki",
##            "../src/wraptofourlines.nki",
        ])
    else:
        nki_main()
