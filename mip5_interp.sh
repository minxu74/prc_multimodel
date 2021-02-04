#!/usr/bin/env bash


# run on titan, rhea nco no ncap2
# titan is gone, and summit and rhea nco no ncap2
# run it under conda environment
#bash version 4

module load esmf


#modeldir=/lustre/atlas1/cli106/proj-shared/mxu/ILAMB_CBGCv1/MODEL/
modeldir=/gpfs/alpine/cli137/proj-shared/mxu/ILAMB_CBGCv1/MODEL/


StartDate='1900-01-01'
EndDate='2005-12-31'
VertInterp=0    # 0 no tsl vertical interpolation, 1 has tsl vertical interoplation

DateString=${StartDate//-/}-${EndDate//-/}




#define functions
function ncdmnsz { ncks --trd -m -M ${2} | grep -E -i ": ${1}, size =" | cut -f 7 -d ' ' | uniq ; }

cd $modeldir
declare -A cmipvars
cmipmods=()
for modnm in *; do
    if [[ -d $modnm ]]; then

       if [[ $modnm == *E3SM* || $modnm == *MeanCMIP* || $modnm == *temp* ]]; then

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

    if [[ -z $landf ]]; then

       echo "error, there is no sftlf in the $md directory"
       exit

    fi



   
    if [[ -z $areaf ]]; then
       echo "error, there is no areacella in the $md directory"
       echo "assume the Earth surface area to be 4piR**2, R=6371km"
       Earea=510064471.90978825 
       UseConstantEarea=1
    else
       UseConstantEarea=0
    fi


    # % to fraction
    ncap2 -s 'sftlf=sftlf*0.01' $landf temp/fracf.nc

    for vr in "${!cmipvars[@]}"; do
        echo $vr
        mfile=`ls $md/${vr}_*.nc`

        files=($mfile)
        #echo ${#files[@]}


        if [[ ${#files[@]} == 1 ]]; then
           cp -r $files temp/${vr}_${md}.nc
        elif [[ ${#files[@]} == 0 ]]; then
           continue
        else # multiple files, concentate them first
           ncrcat $mfile -o temp/${vr}_${md}.nc 
        fi

        # combine
        ncks -A temp/fracf.nc temp/${vr}_${md}.nc     #attn: it is 100

        if [[ "$UseConstantEarea" == "0" ]]; then
           ncrename -v sftlf,landfrac temp/${vr}_${md}.nc
        else
           ncks -A $areaf temp/${vr}_${md}.nc     #
           ncrename -v sftlf,landfrac -v areacella,area temp/${vr}_${md}.nc
        fi

        if [[ "${cmipvars[$vr]}" == "Amon" ]]; then
           if [ -e temp/Amon_map.nc ]; then
              ncremap -m temp/Amon_map.nc -i temp/${vr}_${md}.nc -o temp/${vr}_${md}_historical_r1i1p1_.nc
           else
              ncremap -a conserve -i temp/${vr}_${md}.nc -g ../180x360_SCRIP.20150901.nc -m temp/Amon_map.nc \
                      -o temp/${vr}_${md}_historical_r1i1p1_.nc
           fi


           # get the remapped sftlf and area
           if [[ $vr == 'rsds' ]]; then   # hardcode to get the areacella and landfrac from rsds

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

              if [[ "$UseConstantEarea" == "0" ]]; then
                 ncap2 -O -s 'areacella=area*510064471.90978825' temp/$barea temp/tmp.nc  # shall it be divided by 4pi
                 ncks -O -v areacella temp/tmp.nc temp/$barea 
                 /bin/rm -f temp/tmp.nc 

              else
                 ncks -v areacella -A $areaf temp/$barea
                 ncap2 -v -s 'tsum=areacella.sum()' $areaf temp/tmp.nc
                 ncks -v tsum -A temp/tmp.nc temp/$barea
                 ncap2 -O -s 'areacella=area*tsum' temp/$barea temp/tmp.nc  # shall it be divided by 4pi
                 ncks -O -v areacella temp/tmp.nc temp/$barea 
                 /bin/rm -f temp/tmp.nc 
              fi
           fi

        else  # land model

           if [[ $vr == 'tsl' ]]; then
              #divide 10 parts
              ntim=`ncdmnsz time temp/${vr}_$md.nc`
              nseq=$((ntim/10))

              dotsl=0 
              if [ $nseq -gt 0 ]; then
                 dotsl=1
                 continue
              fi
           fi

           if [ -e temp/Lmon_map.nc ]; then
              ncremap -m temp/Lmon_map.nc -i temp/${vr}_${md}.nc -o temp/${vr}_${md}_historical_r1i1p1_.nc
           else

              #potential bug that are seen from ne30 to 1by1
              ncremap -P sgs -a conserve -i temp/${vr}_${md}.nc -g ../180x360_SCRIP.20150901.nc -m temp/Lmon_map.nc \
                      -o temp/${vr}_${md}_historical_r1i1p1_.nc
           fi
        fi

        #timecutting
        ncks -d time,$StartDate,$EndData temp/${vr}_${md}_historical_r1i1p1_.nc temp/tmp.nc
        /bin/mv -f temp/tmp.nc MeanCMIP5conv/${vr}_${md}_historical_r1i1p1_${DateString}.nc
         
    done # model loop
 
    if [[ $dotsl == 1 ]]; then
        for is in `seq 0 9`; do
            ibgn=$((is*nseq))
            iend=$((ibgn+nseq-1))

            if [ $iend -gt $((ntim-1)) ]; then
                iend=$((ntim-1))
            fi
            echo $ibgn, $iend
            ncks -d time,$ibgn,$iend temp/tsl_${md}.nc -o temp/tsl_${md}_tmp${is}.nc
            ncremap -m temp/Lmon_map.nc -i temp/tsl_${md}_tmp${is}.nc -o temp/tsl_${md}_tmp${is}_remap.nc
        done

        ncrcat temp/tsl_${md}_tmp?_remap.nc -o temp/tsl_${md}_historical_r1i1p1_.nc

        /bin/rm -f temp/tsl_${md}_tmp?_remap.nc
        /bin/rm -f temp/tsl_${md}_tmp?.nc

        ncks -d time,$StartDate,$EndDate temp/tsl_${md}_historical_r1i1p1_.nc temp/tmp.nc
        /bin/mv -f temp/tmp.nc MeanCMIP5conv/tsl_${md}_historical_r1i1p1_${DateString}.nc
    fi


    #cleanup
    /bin/rm -f temp/fracf.nc
    /bin/rm -f temp/Amon_map.nc
    /bin/rm -f temp/Lmon_map.nc
done


for vr in "${!cmipvars[@]}"; do
    echo $vr
    mfile=`ls MeanCMIP5conv/${vr}_*.nc`

    files=($mfile)
    echo $vr --- ${#files[@]}
    echo $mfile
done

# vertical interpolations

if [[ $VertInterp == 1 ]]; then
   cd MeanCMIP5conv
   source vinterp.sh
fi
