#!/bin/bash
#
# Pocket Transcoder
#
# Transcodes FLAC to Opus in parallel

# Uses GNU Parallel
# @article{Tange2011a,
#  title = {GNU Parallel - The Command-Line Power Tool},
#  author = {O. Tange},
#  address = {Frederiksberg, Denmark},
#  journal = {;login: The USENIX Magazine},
#  month = {Feb},
#  number = {1},
#  volume = {36},
#  url = {http://www.gnu.org/s/parallel},
#  year = {2011},
#  pages = {42-47}
# }


# TODO: Test case-sensitivity of file extension

E_BADPATH=62
E_BADARGS=63
E_MISSINGPROGRAM=64

if [ ! -e `which ffmpeg` ]
then
    echo "You need ffmpeg installed."
    exit $E_MISSING_PROGRAM
fi

print_usage() {
  echo "\`$(basename $0)\` transcodes a directory structure of FLAC files to Opus files, preserving tags and structure"
  echo
  echo "Usage: $(basename $0) [library/root] filter ~/dest/dir"
  echo
  echo "Library root is the root of your music library (transcoded dir structure will mirror relative paths from here). It will be recursed over, looking for FLAC files to transcode"
  echo "Filter will be passed to \`find\` as a DIRECTORY path filter, and .FLAC files in matched directories will be transcoded."
  echo "Dest dir is where transcoded music will be placed"
  echo
  echo "Example: $(basename $0) ~/Music Visions ~/temp/transcode"
  echo
  echo "         In this case, '~/Music/Haken/Visions/02 Nocturnal Conspiracy.flac'"
  echo "         will be transcoded to '~/temp/transcode/Haken/Visions/02 Nocturnal Conspiracy.m4a'"
  echo
}

fail_args() {
  print_usage
  exit $E_BADARGS
}

if [ $# -eq 2 ]
  then
    libsrc_root=`pwd`
    filter=$1
    libdst_root=${2%/}
elif [ $# -eq 3 ]
  then
    libsrc_root=${1%/}
    filter=$2
    libdst_root=${3%/}
else
  fail_args
fi

if [ ! -d "${libsrc_root}" ] || [ ! -d "${libdst_root}" ]
  then 
    echo "Directory error"
    fail_args
fi

c_libsrc_root=$( cd "${libsrc_root}" ; pwd -P )
#echo "Canonical library root is ${c_libsrc_root}"
c_libdst_root=$( cd "${libdst_root}" ; pwd -P )
#echo "Canonical destination root is ${c_libdst_root}"

cd "$libsrc_root"

flac_files=$(find -L . -type f -path "*${filter}*/*" -name "*.flac")
flac_relative_paths=$( echo "$flac_files" | sed "s/\.\/\(.*\)\.flac/\1/g" )

other_files=$(find -L . -type f -path "*${filter}*/*" \( -name "*.jpg" -o -name "*.png" -o -name "*.mp3" -o -name "*.mp4" -o -name "*.m4a" -o -name "*.ogg" -o -name "*.oga" \) )
other_relative_paths=$( echo "$other_files" | sed "s/\.\/\(.*\)/\1/g" )

echo    "+--------------->"
echo -n "| Files to transcode: "
echo "${flac_files}" | wc -l
echo -n "| Files to copy: "
echo "${other_files}" | wc -l
echo    "+-------------------------->"

# Create directory paths
find -L . -type d -path "*${filter}*" -exec mkdir -p "${c_libdst_root}/{}" \;



# Transcode files
export c_libdst_root

transcode_file() {
  echo -e "\r $1"
  ffmpeg -y -loglevel error -i "./$1.flac" -vn -c:a libopus -b:a 144k -vbr on "$c_libdst_root/$1.opus"
}
export -f transcode_file

# It's a good idea to let GNU Parallel use all the visible "cores", even if the
# CPU is presenting extra cores because of hyperthreading. Don't set the core
# count manually.
echo
echo "Transcoding..."
parallel -u --eta "transcode_file {}" ::: "$flac_relative_paths"

if [ $? -ne 0 ]
  then
    echo
    echo "Transcoding cancelled."
    exit 130
fi

echo
echo
echo "Copying additional files (JPG, PNG, MP3, MP4, M4A, OGG, OGA)..."
# Yes, we're going to poop on $IFS here. If something needs to happen after here, we should reset $IFS.
IFS=$'\n'
for other in $other_relative_paths; do
  cp -v "./$other" "$c_libdst_root/$other"
done

# This is the machine that goes "bing"!
tput bel
echo
echo "Transcoding complete."






