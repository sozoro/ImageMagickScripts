#! /usr/bin/env nix-shell
#!nix-shell -i bash -p imagemagick

# appended_xx.jpgを結合してPDF（output.pdf）を作成する。

convert -density 200 -colorspace RGB appended_*.jpg output.pdf
