#!/usr/bin/env python
from __future__ import with_statement, division, print_function
from collections import defaultdict
import sys, heapq
from vwfbuild import ca65_bytearray

heapq_cheat_sheet = """
A heap is a data structure that, like a search tree, allows
O(log n) insertion of an element and removal of the smallest
element.  Turning an array into a heap is faster than doing so
for a search tree, but arbitrary removal isn't fast.  Heaps are
useful for building Huffman trees and priority queues.

Python heapq module quick reference:
h = []
    create a new heap
heapq.heapify(h)
    convert list to heap in place in linear time
h.sort()
    convert list to heap in place in n log n time
heapq.heappush(h, el)
    add item
h[0]
    peek smallest item
el = heapq.heappop(h)
    remove and return smallest item
el2 = heapq.heappushpop(h, el)
    add then remove smallest item (2.6+)
el2 = heapq.heapreplace(h, el)
    remove smallest item then add
it = heapq.merge(a, b, ...)
    merge multiple already sorted iterables
ls = heapq.nsmallest(n, iterable, key=lambda x: x)
ls = heapq.nlargest(n, iterable, key=lambda x: x)
    find the n smallest or largest elements
    use min() or max() for n=1, or sorted()[:n] for large n
"""

dte_problem_definition = """
Byte pair encoding, dual tile encoding, or digram coding is a static
dictionary compression method first disclosed to the public by Philip
Gage in 1994.  Each symbol in the compressed data represents a
sequence of two symbols, which may be compressed symbols or literals.
Its size performance is comparable to LZW but without needing RAM
for a dynamic dictionary.
http://www.drdobbs.com/a-new-algorithm-for-data-compression/184402829

The decompression is as follows:

for each symbol in the input:
    push the symbol on the stack
    while the stack is not empty:
        pop a symbol from the stack
        if the symbol is literal:
            emit the symbol
        else:
            push the second child
            push the first child

I'm not guaranteeing that it's optimal, but here's a greedy
compressor:

scan for frequencies of all symbol pairs
while a pair has high enough frequency:
    allocate a new symbol
    replace the old pair with the new symbol
    decrease count of replaced pairs
    increase count of newly created pairs

This is O(k*n) because of the replacements.

"""

lipsum = """"But I must explain to you how all this mistaken idea of denouncing pleasure and praising pain was born and I will give you a complete account of the system, and expound the actual teachings of the great explorer of the truth, the master-builder of human happiness. No one rejects, dislikes, or avoids pleasure itself, because it is pleasure, but because those who do not know how to pursue pleasure rationally encounter consequences that are extremely painful. Nor again is there anyone who loves or pursues or desires to obtain pain of itself, because it is pain, but because occasionally circumstances occur in which toil and pain can procure him some great pleasure. To take a trivial example, which of us ever undertakes laborious physical exercise, except to obtain some advantage from it? But who has any right to find fault with a man who chooses to enjoy a pleasure that has no annoying consequences, or one who avoids a pain that produces no resultant pleasure?
On the other hand, we denounce with righteous indignation and dislike men who are so beguiled and demoralized by the charms of pleasure of the moment, so blinded by desire, that they cannot foresee the pain and trouble that are bound to ensue; and equal blame belongs to those who fail in their duty through weakness of will, which is the same as saying through shrinking from toil and pain. These cases are perfectly simple and easy to distinguish. In a free hour, when our power of choice is untrammelled and when nothing prevents our being able to do what we like best, every pleasure is to be welcomed and every pain avoided. But in certain circumstances and owing to the claims of duty or the obligations of business it will frequently occur that pleasures have to be repudiated and annoyances accepted. The wise man therefore always holds in these matters to this principle of selection: he rejects pleasures to secure other greater pleasures, or else he endures pains to avoid worse pains.
--M. T. Cicero, "Extremes of Good and Evil", tr. H. Rackham"""

MINFREQ = 4

def dte_count_changes(s, pairfrom, pairto):
    """Count changes to pair frequencies after replacing a given string."""
    # Collect pair frequency updates
    # Assuming hi->$:
    # ghij -> gh -1, g$ +1, ij -1, $j + 1
    # ghihij -> gh -1, g$ -1, ih -1, $$ + 1, ij -1, $j +1
    newpairfreqs = defaultdict(lambda: 0)
    i, ilen = 0, len(s)
    lastsym = None
    while i < ilen - 1:
        if s[i:i + 2] != pairfrom:
            lastsym = s[i]
            i += 1
            continue
        if i > 0:
            newpairfreqs[lastsym + pairto] += 1
            newpairfreqs[lastsym + pairfrom[0]] -= 1
        lastsym = pairto

        # eat up nonoverlapping pairs of a replacement two at a time
        # ghij -> g$j
        # ghihij -> g$$j
        # ghihihij -> g$$$j
        nollen = 0
        while i < ilen:
            i += 2
            nollen += 1
            nextsym = s[i:i + 2]
            if nextsym != pairfrom:
                break
        if nollen >= 2:
            newpairfreqs[pairto + pairto] += nollen // 2

        if nextsym:
            newpairfreqs[pairto + nextsym[0]] += 1
            newpairfreqs[pairfrom[1] + nextsym[0]] -= 1
    return newpairfreqs

def dte_newsymbol(lines, replacements, pairfreqs):
    """Find the biggest pair frequency and turn it into a new symbol."""

    # I don't know how to move elements around in the heap, so instead,
    # I'm recomputing the highest value every time.  When frequencies
    # are equal, prefer low numbered symbols for a less deep stack.
    strpair, freq = min(pairfreqs.iteritems(), key=lambda x: (-x[1], x[0]))
    if freq < MINFREQ:
        return True

    expected_freq = sum(line.count(strpair) for line in lines)
    try:
        assert freq == expected_freq
    except AssertionError:
        print("frequency of %s in pairfreqs: %d\nfrequency in inputdata: %d"
              % (repr(strpair), freq, expected_freq),
              file=sys.stderr)
        raise

    # Allocate new symbol
    newsym = chr(128 + len(replacements))
    replacements.append(strpair)

    # Update pair frequencies
    del pairfreqs[strpair]
    for line in lines:
        for k, v in dte_count_changes(line, strpair, newsym).iteritems():
            if v:
                pairfreqs[k] += v

    return False

def dte_uncompress(line, replacements):
    outbuf = bytearray()
    s = []
    maxstack = 0
    for c in line:
        s.append(c)
        while s:
            maxstack = max(len(s), maxstack)
            c = ord(s.pop())
            if 0 <= c - 128 < len(replacements):
                repl = replacements[c - 128]
                s.extend(reversed(repl))
##                print("%02x: %s" % (c, repr(repl)), file=sys.stderr)
##                print(repr(s), file=sys.stderr)
            else:
                outbuf.append(c)
    return str(outbuf), maxstack

def main(argv=None):
##    inputdata = "The fat cat sat on the mat."
##    inputdata = 'boooooobies booooooobies'
##    inputdata = lipsum

    # Load input files
    argv = argv or sys.argv
    lines = []
    for filename in argv[1:]:
        with open(filename, 'rU') as infp:
            lines.extend(row.strip() for row in infp)

    # Remove blank lines and comments
    lines = [row for row in lines if row and not row.startswith('#')]

    # Diagnostic for line length (RFK RFC forbids lines longer than 72)
    lgst = heapq.nlargest(10, lines, len)
    if len(lgst[0]) > 72:
        print("Some NKIs are too long (more than 72 characters):", file=sys.stderr)
        print("\n".join(line for line in lgst if len(line) > 72), file=sys.stderr)
    else:
        print("Longest NKI is OK at %d characters. Don't let it get any longer."
              % len(lgst[0]), file=sys.stderr)
        print(lgst[0], file=sys.stderr)

    # Initial frequency pair scan
    pairfreqs = defaultdict(lambda: 0)
    for line in lines:
        i, ilen = 0, len(line)
        while i < ilen - 1:
            key = line[i:i + 2]
            if all(c >= ' ' for c in key):
                pairfreqs[line[i:i + 2]] += 1
            # nonoverlapping matches: ooo is one OO, not two
            if i < ilen - 3 and all(line[i + 2] == k for k in key):
                i += 1
            i += 1

    oldinputlen = sum(len(line) + 1 for line in lines)
    replacements = []
    lastmaxpairs = 0
    done = False
    while len(replacements) < 128 and not done:
##        curinputlen = sum(len(line) + 1 for line in lines)
##        print("text:%5d bytes; dict:%4d bytes; pairs:%5d"
##              % (curinputlen, 2 * len(replacements), len(pairfreqs)),
##              file=sys.stderr)
        done = dte_newsymbol(lines, replacements, pairfreqs)
        newsymbol = chr(len(replacements) + 127)
        for i in xrange(len(lines)):
            lines[i] = lines[i].replace(replacements[-1], newsymbol)
        if len(pairfreqs) >= lastmaxpairs * 2:
            for i in list(pairfreqs):
                if pairfreqs[i] <= 0:
                    del pairfreqs[i]
            lastmaxpairs = len(pairfreqs)
##        for strpair, freq in pairfreqs.items():
##            if inputdata.count(strpair) != freq:
##                print("Frequency pair scan problem: %s %d!=%d"
##                      % (strpair, freq, inputdata.count(strpair)))
    print("%d replacements; highest remaining frequency is %d"
          % (len(replacements), max(pairfreqs.values())), file=sys.stderr)
    finallen = len(replacements) * 2 + sum(len(line) + 1 for line in lines)
    stkd = max(dte_uncompress(line, replacements)[1] for line in lines)
    print("from %d to %d bytes with peak stack depth: %d"
          % (oldinputlen, finallen, stkd), file=sys.stderr)

    replacements = ''.join(replacements)
    num_nkis = len(lines)
    lines = ''.join(line + '\x00' for line in lines)
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

if __name__=='__main__':
    main()
