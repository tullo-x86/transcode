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


# TODO: Copy image files
# TODO: Copy files which are already compressed in a lossy format
# TODO: Test case-sensitivity of file extension

E_BADPATH=62
E_BADARGS=63
E_MISSINGPROGRAM=64

CPU_CORES=4

if [ ! -e `which ffmpeg` ]
then
    echo "You need ffmpeg installed."
    exit $E_MISSING_PROGRAM
fi

print_usage() {
  echo "\`$(basename $0)\` transcodes a directory structure of FLAC files to M4A-encapsulated AAC files, keeping tags and structure"
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
relative_paths=$( echo "$flac_files" | sed "s/\.\/\(.*\)\.flac/\1/g" )

echo    "+--------------->"
echo -n "| Files to transcode: "
echo "${flac_files}" | wc -l
echo    "+-------------------------->"

# Create directory paths
find -L . -type d -path "*${filter}*" -exec mkdir -p "${c_libdst_root}/{}" \;



# Transcode files
export libsrc_root
export c_libdst_root
transcode_file() {
  #TODO: read tags
  #flac -cds "./$1.flac" | fdkaac -SI --profile 2 --bitrate-mode 5 --gapless-mode 2 -o "$c_libdst_root/$1.m4a" -
  ffmpeg -y -loglevel error -i "./$1.flac" -vn -c:a libfdk_aac -vbr 4 "$c_libdst_root/$1.m4a"
}
export -f transcode_file

parallel -u -P $CPU_CORES --eta "transcode_file {}" ::: "$relative_paths"

echo
echo "end of line."






