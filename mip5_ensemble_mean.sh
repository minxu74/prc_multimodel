#!/usr/bin/env bash

declare -A cmipvars 

for ncf in *.nc; do

    file=`basename $ncf`
    vnam=`echo $file | cut -d_ -f1`
    real=`echo $file | cut -d_ -f2`
    modl=`echo $file | cut -d_ -f3`

    if [[ ! ${cmipvars[$vnam]} ]]; then
        cmipvars[$vnam]=$real
    fi

done

for vr in "${!cmipvars[@]}"; do
    mfile=`ls ${vr}_*.nc`
    files=($mfile)
    echo $vr  ${#files[@]}

    bunits='null'
    for mf in "${files[@]}"; do

        file=`basename $mf`
        vnam=`echo $file | cut -d_ -f1`
        real=`echo $file | cut -d_ -f2`
        modl=`echo $file | cut -d_ -f2`

        vunits=`ncdump -h $mf | grep -i ${vr}:units` 

        if [[ $bunits == 'null' ]]; then
           bunits=$vunits 
        fi

        if [[ $bunits != $vunits ]]; then
           echo "error $bunits -- $vunits -- $vr -- $modl"
        fi
    done
done

# do ensemble
for vr in "${!cmipvars[@]}"; do
    mfile=`ls ${vr}_*.nc`
    nces -v $vr $mfile -o data/${vr}_MeanCMIP5_historical_r1i1p1_190001-200512.nc
done
