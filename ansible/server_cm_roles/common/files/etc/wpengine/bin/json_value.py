#! /usr/bin/python
import json
import string
import sys

if len(sys.argv) < 2:
    sys.exit('Usage: %s dot.separated.path' % sys.argv[0])

j = json.load(sys.stdin)
keys = string.split(sys.argv[1], '.')
v = j
for key in keys:
    if key in v:
        v = v[key]
    else:
        sys.exit('No key %s in input.' % sys.argv[1])
print v
