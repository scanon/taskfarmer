#!/bin/sh

# Sample wrapper script.


cat > tmp.$$
hexdump $@ tmp.$$
rm tmp.$$
