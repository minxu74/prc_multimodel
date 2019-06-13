#!/usr/bin/env bash


for fsl in tsl_*.nc; do
    ncap2 -S soilvertinterp.nco $fsl tmp.nc  
    ncks -v xtsl tmp.nc ${fsl/tsl/xtsl}
    /bin/rm -f tmp.nc


    #change var
    ncatted -a _FillValue,xtsl,c,f,1.0e20 ${fsl/tsl/xtsl}
    ncrename -v xtsl,tsl ${fsl/tsl/xtsl}
    ncrename -d xdepth,depth ${fsl/tsl/xtsl}

done

