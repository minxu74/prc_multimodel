#!/usr/bin/env bash


# for tsl the landmask is not always concide with the tsl data. such as galacier

for ftsl in ./temp/tsl_*NorESM*.nc; do

    if [[ $ftsl == *"historical"* ]]; then
        continue
    else
        echo $ftsl
        ncap2 -s '*temp=tsl(0,0,:,:); temp.delete_miss(); where(temp>tsl.get_miss()/2.) landfrac=0;' $ftsl ./temp/tmp.nc
        ncremap -P sgs -a conserve -i ./temp/tmp.nc -o temp/${ftsl/.nc/_historical_r1i1p1_.nc} -g ../180x360_SCRIP.20190601.nc

        #echo ${ftsl/.nc/_historical_r1i1p1_.nc}
        /bin/rm -f temp/tmp.nc
    fi


done
