#! /usr/bin/env nix-shell
#!nix-shell -i bash -p imagemagick

# JPEG画像を名前順に2組にして、縦書きの本のページのように右左の順に結合する。

pics=`ls -1 | grep ".*\.jpg"`

echo $pics | awk \
  -v cmd="convert +append " \
  '{ for (i=1; i<=(NF/2); i++) {
       n=int(log(NF/2)/log(10)+0.000000000000001)+1
       printf cmd$(i*2)" "$(i*2-1)" appended_%0"n"d.jpg\n", i;
     } \
   }' | bash -x
