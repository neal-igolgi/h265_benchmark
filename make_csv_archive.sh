#!/usr/bin/env bash
# See show_help() below for description

CLOUD_ADDR='96.87.115.134:5118'

show_help() {
cat << EOF
Usage: $0 [-o OUTFILE] [-a] <input_file.ts>

    Creates or appends to a CSV file that holds information about each transcoded version
    of the input source. This script uses plot_vmaf_vs_frame.py and should be ran right 
    after (batch_)fileapp_transcode_vmaf.sh with the same input_file.ts.

    -o OUTFILE      write csv output to OUTFILE instead of default out path
    -a              append to output file instead of overwriting it

    input_file.ts   video stream file previously ran through fileapp_transcode_vmaf.sh
EOF
exit 1
}

APPEND=false

# process options in cmdline
OPTIND=1
while getopts ":o:a" opt; do
	case $opt in
	o)
		OUTFILE="$OPTARG"
		if [[ $OUTFILE =~ ^-.* ]]; then
			echo 'Option -o requires an argument.'
			show_help
		elif [[ ! -d ${OUTFILE%/*} ]]; then
			echo 'Directory in output filepath does not exist.'
			exit 1
		fi
		;;
	a)
		APPEND=true
		;;
	\?)
		echo "Option -$OPTARG is invalid."
		show_help
		;;
	:)
		echo "Option -$OPTARG requires an argument."
		show_help
		;;
	esac
done
shift $((OPTIND-1))

if [[ $# -eq 0 ]]; then 
	echo "No input file specified."; show_help
elif [[ $# -gt 1 ]]; then
	echo "Too many input files specified."; show_help
fi

FILENAME="${1##*/}"
BASENAME="${FILENAME%.*}"
FILEIDIR="intermediate/$BASENAME"
PREV_TIMELOG="$FILEIDIR/transcode_speed.txt"
SAVEIMGDIR="archive/${BASENAME}_plots"
OUTFILE="${OUTFILE:-archive/${BASENAME}_x265_tests.csv}"

# check that mediainfo is installed and saveimg dir exists
which mediainfo > /dev/null
if [ $? -eq 1 ]; then sudo apt install -y mediainfo; fi
mkdir -pv "$SAVEIMGDIR"

# truncate csv file if append is not set
if ! $APPEND; then
	IFS=$'\n:' cpinfo=( `lscpu | egrep '^CPU\(|^Core|^Model ' | sed -e 's/  \+//'` )
	echo "${cpinfo[5]} | CPUs: ${cpinfo[1]} | Cores: ${cpinfo[3]}" > "$OUTFILE"
	echo 'Clip Name,Resolution,Codec Preset,Interlaced,Clip Length,Normalized CPU,Video Bitrate,Transcode Time,Conversion Rate,VMAF Avg,VMAF Min,VMAF Max,VMAF Std.dev.,PSNR Avg,PSNR Min,PSNR Max,PSNR Std.dev.,VMAF & PSNR per Frame' >> "$OUTFILE"
fi

# get column result for each transcoded video in FILEIDIR folder
for tsfp in $FILEIDIR/*.ts
do
	tsfn="${tsfp##*/}"
	tsfn="${tsfn%.*}"
	FILENAME="$BASENAME-${tsfn%-*}"
	CODECPRE=${tsfn##*-}

	# extract info on transcoded .ts to derive column values
	IFS=',' read -a COLS <<< $(mediainfo --inform="Video;%Width%x%Height%,%FrameRate%,%ScanType%,%Duration/String3%,%BitRate/String%,%Duration%" "$tsfp")
	RES=$COLS
	CONVRATE=`echo "scale=3; ${COLS[1]}*${COLS[5]}/1000" | bc`
	if [[ ${COLS[2]} == "Interlaced" ]]; then
		INTERLACED='yes'
	else
		INTERLACED='no'
	fi
	CLIPLEN=${COLS[3]}
	VBITRATE=${COLS[4]}

	# some column values are stored in log created by time util on fileapp	
	IFS=',' read -a COLS <<< $(tac "$PREV_TIMELOG" | awk -v RS= -v fn="$tsfn" '$0~fn{printf "%f,%s", $2, $4; exit}')
	NORMCPULD="`echo "scale=2; $COLS/${cpinfo[1]}" | bc` %"
	TRANSTM="${COLS[1]} s"
	CONVRATE="`echo "scale=3; $CONVRATE/${COLS[1]}" | bc` fps"

	# search for single vmaf result by .ts filename first, then resort to batch results
	vmafxml="results_vmaf/${BASENAME}_$tsfn.xml"
	psnrxml="results_psnr/${BASENAME}_$tsfn.xml"
	if [[ -f $vmafxml ]]; then
		IFS=$'\n,' read -a COLS -d '' <<< "$(./plot_vmaf_vs_frame.py -s "$SAVEIMGDIR/$tsfn.png" "$vmafxml" "$psnrxml")"
	else
		vmafxml="results_vmaf/${BASENAME}_batch.xml"
		IFS=$'\n,' read -a COLS -d '' <<< "$(./plot_vmaf_vs_frame.py -f "$tsfn" -s "$SAVEIMGDIR/$tsfn.png" "$vmafxml" "$psnrxml")"
	fi
	# some column values come from feeding the .py script with the xml results
	VMAFAVG=${COLS#*=}
	VMAFSTD=${COLS[1]#*=}
	VMAFMIN=${COLS[2]#*=}
	VMAFMAX=${COLS[3]#*=}
	PSNRAVG=${COLS[4]#*=}
	PSNRSTD=${COLS[5]#*=}
	PSNRMIN=${COLS[6]#*=}
	PSNRMAX=${COLS[7]#*=}
	PLOTLINK="http://$CLOUD_ADDR/${BASENAME}_plots/$tsfn.png"

	echo "$FILENAME,$RES,$CODECPRE,$INTERLACED,$CLIPLEN,$NORMCPULD,$VBITRATE,$TRANSTM,$CONVRATE,$VMAFAVG,$VMAFMIN,$VMAFMAX,$VMAFSTD,$PSNRAVG,$PSNRMIN,$PSNRMAX,$PSNRSTD,$PLOTLINK" >> "$OUTFILE"
done

# upload all plots & output videos to cloud server
rsync -urvh --progress --delete --chmod=D755 --exclude '*.txt' "$SAVEIMGDIR" "$FILEIDIR" igolgi@10.1.10.115:/var/www/h265_media

