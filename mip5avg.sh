#!/usr/bin/env bash


# run on titan, rhea nco no ncap2
#bash version 4

module load esmf


modeldir=/lustre/atlas1/cli106/proj-shared/mxu/ILAMB_CBGCv1/MODEL/


cd modeldir
declare -A cmipvars
cmipmods=()
for modnm in *; do
    if [[ -d $modnm ]]; then

       if [[ $modnm == *E3SM* ]]; then

           echo $modnm
           echo "skip"
       else
           cmipmods+=($modnm)

           ncfiles=(`find $modnm -name '*.nc'`)

           for ncf in "${ncfiles[@]}"; do

               file=`basename $ncf`

               vnam=`echo $file | cut -d_ -f1`

               real=`echo $file | cut -d_ -f2`

               modl=`echo $file | cut -d_ -f3`

               #echo $vnam, $real, $modl

               if [[ $vnam == *sftlf*  || $vnam == *areacella* ]]; then
                   continue
               fi

               if [[ ! ${cmipvars[$vnam]} ]]; then
                   cmipvars[$vnam]=$real
               fi
               
               #echo $file, $vnam

           done
       fi
       #echo $ncfiles
    fi
done



# remapping ...

for md in "${cmipmods[@]}"; do
    echo "processing ... $md"

    landf=`ls $modeldir/$md/sftlf_*.nc`
    areaf=`ls $modeldir/$md/areacella_*.nc`

    if [ -z $landf || -z $areaf ]; then

       echo "error"
       exit

    fi

    # % to fraction
    ncap2 -s 'sftlf=sftlf*0.01' $landf temp/fracf.nc

    for vr in "${!cmipvars[@]}"; do
        echo $vr
        mfile=`ls $md/${vr}_*.nc`

        files=($mfile)
        #echo ${#files[@]}


        if [[ ${#files[@]} == 1 ]]; then
           cp -r $files temp/${vr}_$md.nc
        elif [[ ${#files[@]} == 0 ]]; then
           continue
        else
           ncrcat $mfile -o temp/${vr}_$md.nc 
        fi

        # combine
        ncks -A temp/fracf.nc temp/${vr}_$md.nc     #attn: it is 100
        ncks -A $areaf temp/${vr}_$md.nc     #attn: it is 100
        ncrename -v sftlf,landfrac -v areacella,area temp/${vr}_$md.nc

        if [[ "${cmipvars[$vr]}" == "Amon" ]]; then
           if [ -e temp/Amon_map.nc ]; then
              ncremap -m temp/Amon_map.nc -i temp/${vr}_$md.nc -o temp/${vr}_${md}_historical_r1i1p1_.nc
           else
              ncremap -a conserve -i temp/${vr}_$md.nc -g ../180x360_SCRIP.20150901.nc -m temp/Amon_map.nc \
                      -o temp/${vr}_${md}_historical_r1i1p1_.nc
           fi


           if [[ $vr == 'rsds' ]]; then   # hardcode

              #specially processing areacella and sftlf.
              /bin/cp $landf ./temp/
              /bin/cp $areaf ./temp/
              bland=`basename $landf`
              barea=`basename $areaf`

              ncks -O -v landfrac temp/${vr}_${md}_historical_r1i1p1_.nc temp/$bland
              ncks -O -v area     temp/${vr}_${md}_historical_r1i1p1_.nc temp/$barea

              ncks -v sftlf -A $landf temp/$bland
              ncap2 -s 'sftlf=landfrac*100' temp/$bland temp/tmp.nc
              ncks -O -v sftlf temp/tmp.nc temp/$bland
              /bin/rm -f temp/tmp.nc 

              ncks -v areacella -A $areaf temp/$barea
              ncap2 -v -s 'tsum=areacella.sum()' $areaf temp/tmp.nc
              ncks -v tsum -A temp/tmp.nc temp/$barea
              ncap2 -O -s 'areacella=area*tsum' temp/$barea temp/tmp.nc
              ncks -O -v areacella temp/tmp.nc temp/$barea 
              /bin/rm -f temp/tmp.nc 
           fi

        else
           if [ -e temp/Lmon_map.nc ]; then
              ncremap -m temp/Lmon_map.nc -i temp/${vr}_$md.nc -o temp/${vr}_${md}_historical_r1i1p1_.nc
           else
              ncremap -P sgs -a conserve -i temp/${vr}_$md.nc -g ../180x360_SCRIP.20150901.nc -m temp/Lmon_map.nc -o temp/${vr}_${md}_historical_r1i1p1_.nc
           fi
        fi

        #timecutting
        ncks -d time,'1900-01-01','2005-12-31' temp/${vr}_${md}_historical_r1i1p1_.nc temp/tmp.nc
        /bin/mv -f temp/tmp.nc MeanCMIP_conv/${vr}_${md}_historical_r1i1p1_190001-200512.nc
         
    done

    /bin/rm -f temp/fracf.nc
    /bin/rm -f temp/Amon_map.nc
    /bin/rm -f temp/Lmon_map.nc
done


for vr in "${!cmipvars[@]}"; do
    echo $vr
    mfile=`ls MeanCMIP_conv/${vr}_*.nc`

    files=($mfile)
    echo $vr --- ${#files[@]}
    echo $mfile

done
