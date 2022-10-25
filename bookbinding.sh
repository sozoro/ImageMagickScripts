#!/usr/bin/env nix-shell
#!nix-shell --pure -i bash -p imagemagick gawk getopt

set -eu

helpMessage=`cat << EOF
--- $0 ---

Bind images to a PDF in name order while merging each two images into one PDF page.

-o, --output filename
    Output PDF file name. (default: dirname.pdf)
-v, --vertical
    Vertical writing mode: Merge two images in the order right to left. (default)
-h, --horizonal
    Horizonal writing mode: Merge two images in the order left to right.
-e, --blank-top-page
    Insert a blank page at the beginning.
-d, --density integer
    Density parameter referenced by convert command when producing PDF file.
    (default: 200)
-l, --leave-tmp-dir
    Leave temporary directory without removing.
-g, --grayscale
    Make output PDF Grayscale.
--help
    Show this message and exit.
EOF`

function addBlankPage () {
  wxh=$(identify "$1" | awk '{ print $3 }')
  width=$(echo "$wxh" | sed 's/x.*$//')
  height=$(echo "$wxh" | sed 's/^.*x//')
  extent="$((width*2))x$height"

  if [ "$2" == "l" ]; then
    gravity="East"
  else
    gravity="West"
  fi

  echo "> "convert "$1" -gravity "$gravity" -extent "$extent" "$3"
  convert "$1" -gravity "$gravity" -extent "$extent" "$3"
}

tmpDir='tmp.bookbinding'
tmpFilePrefix='pdfPage_'
picExt='(jpg|JPG|png|PNG)'
tmpPicExt='jpg'

args=''
output=''
verticalWriting='true'
blankTopPage='false'
density=200
rmTmpDir='true'
grayscale=''

long_opts='output:,vertical,horizonal,blank-top-page,density:,leave-tmp-dir,grayscale,help'
opts=$(getopt --unquoted --name "$0" \
              --options 'o:vhed:lg' --longoptions "$long_opts" -- $@)

eval $(echo "$opts" | awk \
  '{ for(i=1; i<=NF; i++) {
       switch($i) {
         case "--output":
         case "-o":
           i++
           printf "output=\""$i"\"; "
           break
         case "--vertical":
         case "-v":
           printf "verticalWriting=true; "
           break
         case "--horizonal":
         case "-h":
           printf "verticalWriting=false; "
           break
         case "--blank-top-page":
         case "-e":
           printf "blankTopPage=true; "
           break
         case "--density":
         case "-d":
           i++
           printf "density="$i"; "
           break
         case "--leave-tmp-dir":
         case "-l":
           printf "rmTmpDir=false; "
           break
         case "--grayscale":
         case "-g":
           printf "grayscale=\"-type GrayScale\"; "
           break
         case "--help":
           i++
           printf "echo \"$helpMessage\"; exit 0;"
           break
         case "--":
           i++
           for(; i<=NF; i++) {
             printf "args=$args\" "$i"\"; "
           }
           break
       }
     }
  }')

# -----------------
zeroPadding='%04d'

if [ -z "$output" ]; then
  output=$(basename "$(pwd)").pdf
fi

mkdir -p "$tmpDir"
echo -n "" > "$tmpDir/zero"
rm "$tmpDir/"*

function fileProcess () {
  if $blankTopPage; then
    if [ $i -eq 1 ]; then
      if $verticalWriting; then
        lr='r'
      else
        lr='l'
      fi
      tmpPic="$tmpDir/$tmpFilePrefix$(printf "$zeroPadding" 0).$tmpPicExt"
      addBlankPage "$file" "$lr" "$tmpPic"
    fi
    p=$((i-1))
  else
    p=$i
  fi

  if [ $p -ge 1 ]; then
    if [ $((p%2)) -eq 1 ]; then
      previous="$file"
    else
      tmpPic="$tmpDir/$tmpFilePrefix$(printf "$zeroPadding" $((p/2))).$tmpPicExt"
      if $verticalWriting; then
        echo "> "convert +append "$file" "$previous" "$tmpPic"
        convert +append "$file" "$previous" "$tmpPic"
      else
        echo "> "convert +append "$previous" "$file" "$tmpPic"
        convert +append "$previous" "$file" "$tmpPic"
      fi
    fi
  fi

  ((i++))
}

i=1
previous=''

if [ -n "$args" ]; then
  for file in $args
  do
    fileProcess
  done
else
  for file in *
  do
    if [ -f "$file" ] && (echo "$file" | sed -n -z -r 's/^.*\.'$picExt'\n$//; t; q10')
    then
      fileProcess
    fi
  done
fi

if [ $((p%2)) -eq 1 ]; then
  if $verticalWriting; then
    lr='l'
  else
    lr='r'
  fi
  tmpPic="$tmpDir/$tmpFilePrefix$(printf "$zeroPadding" $(((p+1)/2))).$tmpPicExt"
  addBlankPage "$previous" "$lr" "$tmpPic"
fi

echo "Producing PDF..."
echo "> "convert -density $density -colorspace RGB $grayscale \
  "${tmpDir}/${tmpFilePrefix}*.${tmpPicExt}" "$output"
convert -density $density -colorspace RGB $grayscale \
  "${tmpDir}/${tmpFilePrefix}*.${tmpPicExt}" "$output"

if $rmTmpDir; then
  rm -rf $tmpDir
fi

exit 0
# ------------------

if [ -n "$args" ]; then
  pagePics=$(echo "$args" | sed -e 's/^ *//' -e 's/ /\n/g')
else
  pagePics=$(ls -1 | grep -E ".*\."$picExt"$") \
    || (echo error: No images in this directory >&2; exit 1)
fi

if [ -z "$output" ]; then
  output=$(basename "$(pwd)").pdf
fi

mkdir -p "$tmpDir"
echo -n "" > "$tmpDir/zero"
rm "$tmpDir/"*

if $blankTopPage; then
  sndPage=$(echo "$pagePics" | awk 'NR==1{ print }')
  pagePics=$(echo "$pagePics" | awk 'NR>1{ print }')
  if $verticalWriting; then
    lr="r"
  else
    lr="l"
  fi
  addBlankPage "$sndPage" $lr "${tmpDir}/${tmpFilePrefix}00.${tmpPicExt}"
fi

numOfPagePics=$(echo "$pagePics" | wc -l)

if [ -n "$pagePics" ] && [ $(($numOfPagePics % 2)) -eq 1 ]; then
  lastPage=$(echo "$pagePics" | awk 'END{ print }')
  pagePics=$(echo "$pagePics" | awk 'NR<'"$numOfPagePics"'{ print }')
  if $verticalWriting; then
    lr="l"
  else
    lr="r"
  fi
  addBlankPage "$lastPage" $lr "${tmpDir}/${tmpFilePrefix}last.${tmpPicExt}"
fi

if [ "$numOfPagePics" -gt 1 ]; then
  if $verticalWriting; then
    fstFile='"\""$(i*2)"\""'
    sndFile='"\""$(i*2-1)"\""'
  else
    fstFile='"\""$(i*2-1)"\""'
    sndFile='"\""$(i*2)"\""'
  fi

  echo "$pagePics" | awk -F '\n' -v RS='\n\n' \
    -v cmd="convert +append" \
    '{ n=int(log(NF/2)/log(10)+0.000000000000001)+1
       output="\"'$tmpDir/$tmpFilePrefix'%0"n"d.'$tmpPicExt'\""
       for (i=1; i<=(NF/2); i++) {
         printf cmd" "'"$fstFile"'" "'"$sndFile"'" "output"\n", i;
       } \
     }' | bash -x
fi

echo "Producing PDF..."
convert -density $density -colorspace RGB $grayscale \
  "${tmpDir}/${tmpFilePrefix}*.${tmpPicExt}" "$output"

if $rmTmpDir; then
  rm -rf $tmpDir
fi
