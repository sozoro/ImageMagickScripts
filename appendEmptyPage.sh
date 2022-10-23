#!/usr/bin/env nix-shell
#!nix-shell --pure -i bash -p imagemagick gawk getopt

# set -x

opts=`getopt --unquoted --options "o:lr" -- $@`

args=""
output=""
gravity="West"

eval `echo $opts | awk \
  '{ for(i=1; i<=NF; i++) {
       switch($i) {
         case "-o":
           i++
           printf "output=\""$i"\"; "
           break
         case "-l":
           printf "gravity=\"East\"; "
           break
         case "-r":
           printf "gravity=\"West\"; "
           break
         case "--":
           i++
           for(; i<=NF; i++) {
             printf "args=$args\" "$i"\"; "
           }
           break
       }
     }
  }'`

input=`echo $args | awk '{ print $1 }'`

if [ -z $input ]; then
  echo "no input file" >&2
  exit 1
fi

if [ -z $output ]; then
  output=`echo $input | sed -r 's/^(.*)(\.[^\.]*)$/\1_aep\2/'`
fi

wxh=`identify $input | awk '{ print $3 }'`
width=`echo $wxh | sed 's/x.*$//'`
height=`echo $wxh | sed 's/^.*x//'`

# convert -list gravity

convert $input -gravity $gravity -extent $(($width*2))x${height} $output
