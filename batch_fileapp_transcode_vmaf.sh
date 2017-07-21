#!/usr/bin/env bash
# Batch version of fileapp_transcode_vmaf.sh script
trap 'exit 130' INT

if [ "$#" -ne 6 ]; then
  echo "Usage: "$0" <input_file.ts> <start_kbps> <end_kbps> <format> <width> <height>

    Decodes input_file into its YUV format ('source'), then transcodes it in various bitrates via fileapp and 
    decodes that into another YUV ('output'). Compares 'source' and 'output' via VMAF, and generates XML result.
    *note: VMAF must be in this or its children directories; ffmpeg & fileapp (igolgi,inc.) must be installed;
	   fileapp_transcode_vmaf.sh must be in this directory as it is called repeatedly here

	<input_file.ts>		video stream file to be VMAF-ed in specified br range
	<start,end_kbps>	range of bitrate to transcode input at via fileapp
	<format>		one of yuv420p, yuv422p, yuv444p, yuv420p10le, yuv422p10le, yuv444p10le
	<width, height>		dimensions of input file as args for vmaf"
  exit 0
fi

# retrieve sudo pwd
read -p "[sudo] password for $USER: " -s SUDOPWD
printf "%s\n" "$SUDOPWD" | sudo -S true 2>/dev/null
if [ $? -ne 0 ]; then
	echo -e "\nSorry, that's the wrong answer."
	exit 1
else
	echo
	export SUDOPWD
fi

FILENAME="${1##*/}"
FILENAME="${FILENAME%.*}"
FILE_FMT=$4
W=$5
H=$6
export BATCH_FPATH="output/vmaf_$FILENAME.bat"
> "$BATCH_FPATH"

# Suppose this could be executed in parallel if desired...
for brate in `seq $2 1000 $3`
do
	./fileapp_transcode_vmaf.sh "$1" $brate $FILE_FMT $W $H
	for prst in `seq 0 9`; do
		echo "$FILE_FMT $W $H $PWD/source/$FILENAME.yuv $PWD/output/$FILENAME/${brate}kbps-$prst.yuv" >> "$BATCH_FPATH"
	done
done

# for security
unset $SUDOPWD

# run batch vmaf on source and outputs
VMAF_PATH=$(find $PWD -name run_vmaf_in_batch)
mkdir -pv results_vmaf/
"$VMAF_PATH" "$PWD/$BATCH_FPATH" --out-fmt xml --parallelize > "$PWD/results_vmaf/${FILENAME}_batch.xml"
