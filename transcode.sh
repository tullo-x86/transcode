#!/bin/bash
#
# transcode.sh
#
# Transcodes FLAC to Opus in parallel

E_BADPATH=62
E_BADARGS=63
E_MISSINGPROGRAM=64

CPU_CORES=4

if [ ! -e /usr/bin/flac ] || [ ! -e /usr/bin/opusenc ]
then
    echo "You need opus-tools and flac installed"
    exit $E_MISSING_PROGRAM
fi

print_usage() {
  echo "$(basename $0) transcodes a directory structure of FLAC files to Opus files, keeping tags and structure"
  echo
  echo "Usage: $(basename $0) [library/root] filter ~/dest/dir bitrate"
  echo
  echo "Library root is the root of your music library (transcoded dir structure will mirror relative paths from here). It will be recursed over, looking for FLAC files to transcode"
  echo "Filter will be passed to \`find\` as a DIRECTORY path filter, and .FLAC files in matched directories will be transcoded."
  echo "Dest dir is where transcoded music will be placed"
  echo
  echo "Example: $(basename $0) ~/Music Visions ~/temp/transcode 140"
  echo
  echo "         In this case, '~/Music/Haken/Visions/02 Nocturnal Conspiracy.flac'"
  echo "         will be transcoded to '~/temp/transcode/Haken/Visions/02 Nocturnal Conspiracy.opus'"
  echo
}

fail_args() {
  print_usage
  exit $E_BADARGS
}

if [ $# -eq 3 ]
  then
    libsrc_root=`pwd`
    filter=${1%/}
    libdst_root=${2%/}
    quality=$3
elif [ $# -eq 4 ]
  then
    libsrc_root=${1%/}
    filter=${2%/}
    libdst_root=${3%/}
    quality=$4
else
  fail_args
fi

if [ ! -d "${libsrc_root}" ] || [ ! -d "${libdst_root}" ]
  then fail_args
fi

c_libsrc_root=$( cd "${libsrc_root}" ; pwd -P )
echo "Canonical library root is ${c_libsrc_root}"
c_libdst_root=$( cd "${libdst_root}" ; pwd -P )
echo "Canonical destination root is ${c_libdst_root}"

cd $libsrc_root

flac_files=$(find -L . -type f -path "*${filter}*/*" -name "*.flac")
relative_paths=$( echo "$flac_files" | sed "s/\.\/\(.*\)\.flac/\1/g" )

# Create directory paths
find -L . -type d -path "*${filter}*" -exec mkdir -p "${c_libdst_root}/{}" \;

# Transcode files
export libsrc_root
export c_libdst_root
transcode_file() {
  #echo $PWD
  #echo "flac -cds  ./$1.flac  | opusenc --quiet --bitrate $2 -  $c_libdst_root/$1.opus"
         flac -cds "./$1.flac" | opusenc --quiet --bitrate $2 - "$c_libdst_root/$1.opus"
}
export -f transcode_file

parallel -u -P $CPU_CORES --eta "transcode_file {} $quality" ::: "$relative_paths"

echo
echo "end of line."






