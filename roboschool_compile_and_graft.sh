#!/bin/bash
set -e

function osx_graft_lib {
    libfile=$1
    libdir=$(dirname $libfile)
    cwd=$(pwd)
    deps=$(otool -L $libfile | awk 'FNR>2 {print $1}')
    
#    patterns=${@:3}
    graft_dir=$2
    # extra_path=$(dirname $libfile)
    mkdir -p $graft_dir

#    echo "processing $libfile"
#     echo "Dependency list:"
#     for dep in $deps; do
#         echo "$dep"
#     done
# 
#     echo "Pattern list:"
#     for deppattern in $patterns; do
#         echo "$deppattern"
#     done;

    for dep in $deps; do
        echo $dep
        patterns=${@:3}
        for deppattern in $patterns; do
            if [[ "$dep" =~ $deppattern ]]; then
                new_depname=${dep##*/}
                new_deppath="$graft_dir/$new_depname"
                rel_path=$(realpath --relative-to="$libdir" $new_deppath) 
                new_dep="@loader_path/$rel_path"
                echo "$libfile depends on $dep, relinking to $new_deppath ($new_dep)"
                install_name_tool -change $dep $new_dep $libfile
                if [ ! -f $new_deppath ]; then
                    echo "$new_deppath not found, copying and calling self" 
                    cp $dep $new_deppath
                    chmod 777 $new_deppath
                    osx_graft_lib $new_deppath $graft_dir $patterns
                    echo "Finished recursive call"
                else
                    echo "grafted library $new_deppath already exists"
                fi
            fi
        done    
    done
}

cd $(dirname "$0")

cd roboschool/cpp-household
make clean
make -j4
cd ..

if [ $(uname) == 'Darwin' ]; then
    osx_graft_lib cpp_household.so .libs ^/.+/Python
    osx_graft_lib cpp_household.so .libs ^/.+/libboost_python.*\.dylib
    osx_graft_lib cpp_household.so .libs ^/.+/QtCore ^/.+/QtGui ^/.+/QtWidgets ^/.+/QtOpenGL
    # HACK - bash had problems with returning from recursion properly
    osx_graft_lib cpp_household.so .libs ^/.+/QtCore ^/.+/QtGui ^/.+/QtWidgets ^/.+/QtOpenGL
    osx_graft_lib cpp_household.so .libs ^/.+/libassimp.*\.dylib
fi
