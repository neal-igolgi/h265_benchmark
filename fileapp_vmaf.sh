#!/usr/bin/env bash
# See usage below for description
trap 'exit 130' INT

if [ "$#" -ne 5 ]; then
  echo "Usage: "$0" <input_file.ts> <kbps_br> <pix_fmt> <width> <height>

    *note: VMAF must be in this or its children directories; ffmpeg & fileapp (igolgi,inc.) must be installed

	<input_file.ts>		video stream file to be VMAF-ed in specified br
	<kbps_br>		bitrate to transcode input at via fileapp
	<pix_fmt>		one of { yuv420p, yuv422p, yuv444p, yuv420p10le, 
					yuv422p10le, yuv444p10le } as allowed by vmaf
	<width, height>		dimensions of input file as args for vmaf"
  exit 0
fi

# retrieve sudo pwd (if not already) at start to use for fileapp during script runtime
if [ -z ${SUDOPWD+x} ];
then
	read -p "[sudo] password for $USER: " -s SUDOPWD
	sudo -K
	echo "$SUDOPWD" | sudo -S true 2>/dev/null
	if [ $? -ne 0 ]; then
		echo -e "\nSorry, that's the wrong answer."
		exit 1
	else
		echo
	fi
fi

FILEPATH="$1"
MUX_KBPS=$2
FILE_FMT=$3
FILENAME="${FILEPATH##*/}"
BASENAME="${FILENAME%.*}"
LOGPATH="intermediate/$BASENAME/transcode_speed.txt"

# Used for obtaining original bitrate of input
#which mediainfo
#if [ $? -eq 1 ]; then
#  apt install -y mediainfo
#fi
#MUX_KBPS=$(( (`mediainfo --inform="General;%OverallBitRate%" $FILEPATH`+999)/1000 ))

# create stage directories and source raw if DNE
mkdir -pv source/
mkdir -pv intermediate/$BASENAME/
mkdir -pv output/$BASENAME/
if [ ! -f "source/$BASENAME.yuv" ]; then
	ffmpeg -i "$FILEPATH" -y -c:v rawvideo -pix_fmt $FILE_FMT "source/$BASENAME.yuv"
fi

PRESET=0
> 'tmp.log'
while [ $PRESET -lt 10 ]; do
	FILENAME="${MUX_KBPS}kbps-$PRESET"
	#TIME_FMT="Fileapp time for $FILENAME...\nreal %e\nuser %U\nsys  %S\n%%cpu %P\n"
	#/usr/bin/time -o "$LOGPATH" -a -f "$TIME_FMT" 

	# transcode input file and log cpu usage simultaneously
	( echo "$SUDOPWD" | sudo -S fileapp -o SAME -m $MUX_KBPS --enable-hevc --quality $((PRESET+1)) "$FILEPATH" "intermediate/$BASENAME/$FILENAME.ts" ) &
	sleep 2	#wait briefly to ensure fileapp starts first
	while fa_pid=$(pgrep fileapp)
	do
		# 100.0% is a good threshold to filter out encoding period
		top -b -n 1 -p $fa_pid | awk -v fa=$fa_pid '$1 == fa {if ($9 > 100.0) {print $9}}' >> 'tmp.log'
		sleep 0.1
	done
	wait

	# parse log to record encode speed and cpu load
	echo -e "Fileapp encode time for $FILENAME..." >> "$LOGPATH"
	awk '{s+=$1}END{printf "real %.1f\n%%cpu %.1f\n\n",NR*0.1,s/NR}' 'tmp.log' >> "$LOGPATH"
	rm 'tmp.log'

	# decode trancoded file
	ffmpeg -i "intermediate/$BASENAME/$FILENAME.ts" -y -c:v rawvideo -pix_fmt $FILE_FMT "output/$BASENAME/$FILENAME.yuv"

	# run vmaf on source and output raw vids if script is called by itself (vs by batch)
	if [ -z ${BATCH_FPATH+x} ]
	then
		BATCH_SCRIPT=false
		BATCH_FPATH="output/vmaf_$BASENAME-${FILENAME%-*}.bat"
		PSNR_PATH=$(find $PWD -name run_psnr)
		VMAF_PATH="${PSNR_PATH%_*}_vmaf_in_batch"
		mkdir -pv results_vmaf/ results_psnr/

		echo "$FILE_FMT $4 $5 $PWD/source/$BASENAME.yuv $PWD/output/$BASENAME/$FILENAME.yuv" > "$BATCH_FPATH"
	else
		echo "$FILE_FMT $4 $5 $PWD/source/$BASENAME.yuv $PWD/output/$BASENAME/$FILENAME.yuv" >> "$BATCH_FPATH"
	fi

	# run psnr likewise regardless whether ran alone or by batch (either case, PSNR_PATH should be set)
	"$PSNR_PATH" $FILE_FMT $4 $5 "$PWD/source/$BASENAME.yuv" "$PWD/output/$BASENAME/$FILENAME.yuv" --out-fmt xml > "$PWD/results_psnr/${BASENAME}_$FILENAME.xml"

	let PRESET+=1
done

# run vmaf on single bitrate, all presets batch; if called by batch, batch will handle this
if ! $BATCH_SCRIPT
then
	unset SUDOPWD

	"$VMAF_PATH" "$PWD/$BATCH_FPATH" --out-fmt xml --parallelize > "$PWD/results_vmaf/$BASENAME_${FILENAME%-*}_batch.xml"
fi
