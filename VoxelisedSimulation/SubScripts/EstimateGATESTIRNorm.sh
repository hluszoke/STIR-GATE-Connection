## #! /bin/sh
## AUTHOR: Robert Twyman
## AUTHOR: Kris Thielemans
## Copyright (C) 2020 University College London
## Licensed under the Apache License, Version 2.0

## Script is used to compute the normalisation factors for GATE data reconstruction.
## The current standard to do this is to forward project, in STIR and GATE (run simulations), a cylindrical activity, the size of the scanner FOV, without attenuation.
## The MeasuredData (sinogram) is obtained by unlisting the GATE output with the exclusion of randoms and scatter.

## Span: This should be an positive integer that saves an additional sinogram with the indicated span. 
## If no span changes is wanted, please input 1.

## This script forward projects the same activity cylinder in SITR to obtain model_data. 
## The script will estimate the norm factors (norm_sino.hs) using STIR functionality. 
## See find_ML_normfactors3D and apply_normfactors3D for more information

## PARAMETERS

if [ $# != 4 ]; then
	echo "Usage: EstimateGATESTIRNorm.sh OutputFilename MeasuredData FOVCylindricalActivityVolumeFilename Span"
	exit 1
fi 

set -e # exit on error
trap "echo ERROR in $0" ERR

OutputFilename=$1
MeasuredData=$2
FOVCylindricalActivityVolumeFilename=$3
span=$4


## ML Normfactors loop numbers (Hardcoded for now)
outer_iters=5
eff_iters=6

## factors are the norm_filename_prefix generated by find_ML_normfactors3D and input for apply_normfactors3D
factors=norm_factors
eff_factors="eff_factors.hs"

## Create the STIR (model) forward projection of the object.
model_data=STIR_forward.hs

## Forward project using SITR to get model data
forward_project $model_data $FOVCylindricalActivityVolumeFilename $MeasuredData


## find ML normfactors
echo "find_ML_normfactors3D"
find_ML_normfactors3D $factors $MeasuredData $model_data $outer_iters $eff_iters


## create ones sino
echo "stir_math"
stir_math -s --including-first --times-scalar 0 --add-scalar 1 ones.hs $model_data


## mutiply ones with the norm factors to get a sino
echo "apply_normfactors3D"
apply_normfactors3D $eff_factors $factors ones.hs 1 $outer_iters $eff_iters

## Creates the span-1 normalisation sinogram
echo "inverting the eff_factors to get norm"
stir_math -s --including-first --power -1 $OutputFilename $eff_factors

## Creates the span-n normalisation sinogram if $span > 1
if [ span != 1]; then
	SSRB span${span}_${eff_factors} ${eff_factors} $span 1 0
	stir_math -s --including-first --power -1 span${span}_$OutputFilename span${span}_$eff_factors
fi

rm ones.hs
rm ones.s

echo "Norm factors are saved as $OutputFilename"

exit 0
