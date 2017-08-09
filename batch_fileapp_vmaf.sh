#!/usr/bin/env bash
# Batch version of fileapp_vmaf.sh script
trap 'exit 130' INT

if [ "$#" -ne 7 ]; then
  echo "Usage: "$0" <input_file.ts> <start_kbps> <intvals> <end_kbps> <format> <width> <height>

    *note: VMAF must be in this or its children directories; ffmpeg & fileapp (igolgi,inc.) must be installed;
	   fileapp_vmaf.sh must be in this directory as it is called repeatedly here

	<input_file.ts>		video stream file to be VMAF-ed in specified br range
	<start,int,end>		range of bitrate to transcode input, start to end by incremental ints
	<format>		one of yuv420p, yuv422p, yuv444p, yuv420p10le, yuv422p10le, yuv444p10le
	<width, height>		dimensions of input file as args for vmaf"
  exit 0
fi

# retrieve sudo pwd
read -p "[sudo] password for $USER: " -s SUDOPWD
sudo -K
echo "$SUDOPWD" | sudo -S true 2>/dev/null
if [ $? -ne 0 ]; then
	echo -e "\nSorry, that's the wrong answer."
	exit 1
else
	echo
	export SUDOPWD
fi

FILENAME="${1##*/}"
FILENAME="${FILENAME%.*}"
export BATCH_SCRIPT=true
export BATCH_FPATH="output/vmaf_$FILENAME.bat"
export PSNR_PATH=$(find $PWD -name run_psnr)
export VMAF_PATH="${PSNR_PATH%_*}_vmaf_in_batch"
mkdir -pv results_vmaf/ results_psnr/
> "$BATCH_FPATH"

for bitr in `seq $2 $3 $4`
do
	./fileapp_vmaf.sh "$1" $bitr $5 $6 $7
done

unset SUDOPWD

# run batch vmaf on source and outputs
"$VMAF_PATH" "$PWD/$BATCH_FPATH" --out-fmt xml --parallelize > "$PWD/results_vmaf/${FILENAME}_batch.xml"
