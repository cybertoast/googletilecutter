# !/bin/bash

# Cuts an image into tiles suitable for use with Google Maps.
#
# Copyright (C) 2006-2007 Ian C. Stevens (http://crazedmonkey.com/)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

usage="Usage: googletilecutter.sh [-1kqh] [-p x,y] [-r tile prefix]
                           -d /dest/path/to/save/tiles/to/
                           -z zoom -o top-left-zoom -t x,y 
                           -f file

This script cuts an image into tiles suitable for use with Google Maps.  The
tiles are produced from the given file for the given zoom and calculated based
on the coordinates of the top-left tile at a possibly higher zoom.  To tile
files for various zoom levels, one only need change the zoom as specified by
-z.

Tiles follow the naming convention of zAxByC.png, where A, B and C are the zoom
level and the x and y coordinates of that tile, respectively.

    -f file     File to cut into tiles
    -z zoom     The map zoom level the given file represents.
    -o zoom     The map zoom level for the top-left tile as given by -t. 
    -t x,y      The x and y coordinates of the top-left tile for
                the zoom level specified by -o.
    -p x,y      The x and y padding from the left and top.  Defaults to 0,0.
    -r prefix   Prefix for each tile.  By default, no prefix is added.
    -1          Specifies that version 1 zoom levels should be used.  That 
                is, the zoom level decreases to 1, the most detailed level.
                By default version 2 zoom levels are used.
    -d destdir  Directory to which to save the output files. Will be created
                if it does not exist. Note that files in this folder will be 
                overwritten without warning!!!
    -k          Keep empty transparent tiles.  By default, empty transparent
                tiles are deleted.
    -q          Quiet mode.  Suppress all output. This also applies to the
                ImageMagick routines, which will be passed -verbose or -quiet
    -h          Display the help message.

This script requires ImageMagick for image manipulation and either advpng or
pngcrush for PNG compression.

Googletilecutter, Copyright (C) 2006-7 Ian C. Stevens (http://crazedmonkey.com)
This software comes with ABSOLUTELY NO WARRANTY. This is free software, and you
are welcome to redistribute it under certain conditions.
"

# Fail on errors
set -e


#------------------------------------------------
# Function prototypes
#------------------------------------------------
debug() {
    if [ $quiet -eq 0 ]; then
        echo $1
    fi
}

sanity_check() {
    # Validate command-line options
    if [ "$zoom" == "" -o "$orgZoom" == "" -o "$topX" == "" -o "$topY" == "" -o "$destdir" == "" -o "$file" == "" ]; then
        echo "Missing options"
        echo -n "$usage"
        exit 1
    fi

    # Test for file existence
    if [ "$file" == "" ]; then
        echo "No file specified"
        echo -n "$usage"
        exit 1
    elif [[ ! -r "$file" ]]; then
        echo "File $file does not exist or cannot be read"
        exit 1
    fi

    # @todo check that zoom levels and coordinates match usage.
    if [ $version -eq 1 -a $zoom -gt $orgZoom ]; then
        echo -e "Version 1 zoom level specified.  Zoom Level specified by -z should be less than\nor equal than that specified by -o."
        exit 1
    elif [ $version -eq 2 -a $zoom -lt $orgZoom ]; then
        echo -e "Version 2 zoom level specified.  Zoom Level specified by -z should be greater\nthan or equal than that specified by -o."
        exit 1
    fi
}

check_png_compressor() {
    # check for existence of advpng or pngcrush for compression
    compress=""
    if [ `which advpng` ]; then
        debug "Using advpng for compression."
        compress="advpng"
    elif [ `which pngcrush` ]; then
        debug "Using pngcrush for compression."
        compress="pngcrush"
    else
        debug "Advpng or pngcrush not found.  Using no PNG compression."
        compress=""
    fi
}

zoom_version() {
    # v2 increases zoom level, v1 decreases.
    if [ $version -eq 2 ]; then
        zoomDiff=$(($zoom - $orgZoom))
    else
        zoomDiff=$(($orgZoom - $zoom))
    fi
    power=`echo | awk "{print 2^$zoomDiff}"`
}

pad_image() {
    # pad image to tile size
    debug "Padding image ..."
    dim=`identify "$file" | sed -e "s/.* \([0-9]*x[0-9]*\) .*/\1/"`

    padX=$(($padX*$power))
    padY=$(($padY*$power))
    width=$((`echo $dim | sed -e "s/x.*//"`+$padX))
    tileWidth=$(($width / 256 + 1))
    height=$((`echo $dim | sed -e "s/.*x//"`+$padY))
    tileHeight=$(($height / 256 + 1))

    tempDir=`mktemp -t map-XXXXXX -d`
    now=$(date -u +%Y%m%d%H%M%S)
    tempFile="$tempDir/$now"
    extraWidth=$((tileWidth*256 - $width))
    extraHeight=$((tileHeight*256 - $height))
    convert "$file" $QUIET -bordercolor none -border ${padX}x${padY} -crop ${width}x${height}+0+0 +repage -bordercolor none -border ${extraWidth}x${extraHeight} -crop +$extraWidth+$extraHeight +repage $tempFile
}

generate_tiles() {
    # tile
    debug "Generating tiles ..."

    # pad image to tile size
    tempPrefix="$tempFile-tile"

    convert $tempFile -crop 256x256 $QUIET +repage png32:$tempPrefix

    debug "Removing temporary location $tempFile"

    rm $tempFile
}

renumber_and_compress() {
    # renumber
    debug "Renumbering and compressing tiles ..."

    x=$(($topX * $power))
    y=$(($topY * $power))

    #adjust
    topX=$x

    files=`ls ${tempDir}/*tile* | wc -l`

    for ((i=0; i<files; i++)) do
        tile=$tempPrefix-$i
        if [ ! -d $destdir ];then
            mkdir -p $destdir
        fi
        newTile="${destdir}/${prefix}_${zoom}-${x}-${y}.png"

        # delete if empty
        if [ $keepEmpty -eq 0 ]; then
            identity=`identify -verbose $tile`
            colors=`echo -e "$identity" | sed -ne "s/.*Colors: //p"`
            alpha=`echo -e "$identity" | sed -ne "s/.*Alpha: \((.*)\).*/\1/p" `
            numAlpha=`echo -e "$identity" | sed -ne "s/ *\([0-9][0-9]*\):.*$alpha.*/\1/p"`
            if [ "$alpha" != "" -a "$colors" == "1" -a "$numAlpha" != "0" ]; then 
                debug "Discarding empty tile: $newTile"
                rm $tile
            fi
        fi

        # compress and renumber
        if [ -a $tile ]; then
            debug -n "Compressing $newTile ... "

            if [ "$compress" == "advpng" ]; then
                reduction=`advpng -4 -z $tile | sed -ne "s/.* \([0-9]*\)% .*/\1/p"`
                reduction=$((100-$reduction))
            elif [ $compress == "pngcrush" ]; then
                crushout=`mktemp -t map-XXX`
                reduction=`pngcrush -q -brute $tile $crushout | sed -ne "s/.*(\([0-9\.]*\)%.*/\1/p"`
                if [ -f $crushout ]; then
                    echo "Moving file from $crushout to $tile"
                    mv $crushout $tile
                else
                    echo "Removing file $crushout" 
                    rm $crushout
                fi
            fi

            if [ $quiet -eq 0 ]; then
                if [ "$reduction" == "" ]; then
                    reduction=0
                fi
                echo "$reduction%"
            fi

            debug "Moved tile to $newTile"
            mv $tile "$newTile"
        fi

        if [[ $(($(($i+1)) % $tileWidth)) -eq 0 ]]; then
            x=$topX
            y=$(($y+1))
        else
            x=$(($x+1)) 
        fi

    done    
}

#------------------------------------------------
# MAIN PROGRAM
#------------------------------------------------
# Initialize variables
zoom=""
orgZoom=""
topX=""
topY=""
file=""
version=2
destdir=""
file=""
padX=0
padY=0
prefix=""
keepEmpty=0
quiet=0
QUIET='-verbose'

while getopts ":z:o:t:f:p:r:d:1kqh" options; do
  case $options in
    z ) zoom=$OPTARG;;
    o ) orgZoom=$OPTARG;;
    t ) topX=`expr "$OPTARG" : '\(.*\),'`
        topY=`expr "$OPTARG" : '.*,\(.*\)'`;;
    p ) padX=`expr "$OPTARG" : '\(.*\),'`
        padY=`expr "$OPTARG" : '.*,\(.*\)'`;;
    r ) prefix="$OPTARG";;
    d ) destdir="$OPTARG";;
    f ) file="$OPTARG";;
    1 ) version=1;;
    k ) keepEmpty=1;;
    q ) 
        quiet=1;
        QUIET='-quiet';
        ;;
    h ) echo -e "$usage"
        exit 1;;
    * ) echo -e "$usage"
        exit 1;;
  esac
done


sanity_check
check_png_compressor
zoom_version
pad_image
generate_tiles
renumber_and_compress


