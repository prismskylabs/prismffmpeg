#!/bin/bash
FILES=install/osx/lib/*.dylib
for f in $FILES
do
	f_full=$(grealpath $f)
	f_base=$(basename $f_full)
	echo "Updating install names and paths on $f_base..."
	install_name_tool -id "@loader_path/$f_base" $f
	for f2 in $FILES
	do
		f2_full=$(pwd $f2)/$f2
		f2_base=$(basename $f2_full)
		echo "Replace $f2_full with @loader_path/$f2_base in file $f"
		install_name_tool -change $f2_full @loader_path/$f2_base $f
	done
done
