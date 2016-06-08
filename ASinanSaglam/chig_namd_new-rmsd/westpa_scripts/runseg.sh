#!/bin/bash

if [ -n "$SEG_DEBUG" ] ; then
    set -x
    env | sort
fi

cd $WEST_SIM_ROOT

mkdir -pv $WEST_CURRENT_SEG_DATA_REF || exit 1
cd $WEST_CURRENT_SEG_DATA_REF || exit 1
ln -sv $WEST_SIM_ROOT/namd_config/par_all22_prot_na.prm .
ln -sv $WEST_SIM_ROOT/namd_config/chig.psf              .
#ln -sv $WEST_SIM_ROOT/namd_config/md-continue.conf      .
#substitute the ":seed;" marker in the original md-continue.conf with an actual seed
#need to make sure it is not over 2^31-1, otherwise it gets interpreted as a negative number
seed=`echo $WEST_RAND32 | awk '{x=$1; if (x>2^31-1) x-=2^31; print x}'`
sed -e "s/:seed;/$seed/g" $WEST_SIM_ROOT/namd_config/md-continue.conf > md-continue.conf
# Set up the run

 case $WEST_CURRENT_SEG_INITPOINT_TYPE in
     SEG_INITPOINT_CONTINUES)
         # A continuation from a prior segment
         ln -sv $WEST_PARENT_DATA_REF/seg.coor  ./parent.pdb
         ln -sv $WEST_PARENT_DATA_REF/seg.vel   ./parent.vel
     ;;
 
     SEG_INITPOINT_NEWTRAJ)
         # Initiation of a new trajectory; $WEST_PARENT_DATA_REF contains the reference to the
         ln -sv $WEST_SIM_ROOT/namd_config/seg_initial.pdb  ./parent.pdb 
         ln -sv $WEST_SIM_ROOT/namd_config/seg_initial.vel     ./parent.vel 
         ls -l
     ;;
 
     *)
         echo "unknown init point type $WEST_CURRENT_SEG_INITPOINT_TYPE"
         exit 2
     ;;
 esac

#Do the run
namd2 md-continue.conf > seg.out

#Use VMD to do the analysis to find the progress coordinate.  
ln -sv $WEST_SIM_ROOT/namd_config/reference.pdb .
vmd -e $WEST_SIM_ROOT/namd_config/measure-rmsd.tcl >& vmd.out
wait
#Put the value of the progress coordinate for the parent and for the end of the segment in $WEST_PCOORD_RETURN
head -n1 rmsd.out | gawk '{print $2}' > $WEST_PCOORD_RETURN
tail -n1 rmsd.out | gawk '{print $2}' >> $WEST_PCOORD_RETURN
cat $WEST_PCOORD_RETURN



if [ -n "$SEG_DEBUG" ] ; then
    head -v $WEST_PCOORD_RETURN
fi

# Clean up
#rm -f *.conf *.py  seg_restart.* *.prm *.temp *.pdb  *.psf