#!/usr/bin/env bash

a="word"
b=$a

if [ $# -eq 0 ]; then
	echo "Hel lo, world!"
else
	echo "Hello, $1!"
fi
