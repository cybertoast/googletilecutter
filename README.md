# googletilecutter

Fork of google-tile-cutter. The following additions have been made:

* OSX improvements for the latest convert
* Add -d option to allow for specifying the destination directory to put tiles to

## Examples

./googletilecutter.sh -z 8 -o 8 -t 0,0 -r east -q -d ~/maps/ ~/Documents/east.tif &

Will create east_Zoom_Col_Row.png images at ~/maps/. Directory will be created if it does not exist.

## TODO:

* Create MBTiles directly

## History

`git svn info` dump:

    URL: http://googletilecutter.googlecode.com/svn/trunk
    Repository Root: http://googletilecutter.googlecode.com/svn
    Last Changed Author: iancstevens
    Last Changed Rev: 4
    Last Changed Date: 2010-04-09 19:07:51 -0400 (Fri, 09 Apr 2010)

