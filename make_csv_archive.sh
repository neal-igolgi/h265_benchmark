#!/usr/bin/env bash
# See show_help() below for description

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
		if [[ $OUTFILE =~ -.* ]]; then
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
#which mediainfo > /dev/null
#if [ $? -eq 1 ]; then sudo apt install -y mediainfo; fi
mkdir -pv "$SAVEIMGDIR"

# truncate csv file if append is not set
if ! $APPEND; then 
	echo 'Clip Name,Resolution,Frame Rate,Interlaced,Clip Length,CPU Load,Codec Preset,Video Bitrate,Transcode Speed,VMAF Avg,VMAF Min,VMAF Max,VMAF Std. Deviation,Link to VMAF per Frame Plot' > "$OUTFILE"
fi

# get column result for each transcoded video in FILEIDIR folder
for tsfp in $FILEIDIR/*.ts
do
	tsfn="${tsfp##*/}"
	tsfn="${tsfn%.*}"

	# extract info on transcoded .ts to derive column values
	IFS=',' read -a COLS <<< $(mediainfo --inform="Video;%Width%x%Height%,%FrameRate%,%ScanType%,%Duration/String3%,%BitRate/String%" "$tsfp")
	RES=$COLS
	FRAMERATE=${COLS[1]}
	if [[ ${COLS[2]} == "Interlaced" ]]; then
		INTERLACED='yes'
	else
		INTERLACED='no'
	fi
	CLIPLEN=${COLS[3]}
	VBITRATE=${COLS[4]}

	# some column values are stored in log created by time util on fileapp	
	IFS=',' read -a COLS <<< $(tac "$PREV_TIMELOG" | awk -v RS= -v fn="$tsfn" '$0~fn{sub(/%/,"",$2); printf "%.2f,%.2f", $2/100, $4+$6; exit}')
	CPULOAD=$COLS
	TRANSCSPD="${COLS[1]} s"

	CODECPRE=${tsfn##*-}

	# search for single vmaf result by .ts filename first, then resort to batch results
	xmlpath="results_vmaf/${BASENAME}_$tsfn.xml"
	if [[ -f $xmlpath ]]; then
		IFS=',' read -a COLS <<< $(./plot_vmaf_vs_frame.py -s "$SAVEIMGDIR/$tsfn.png" "$xmlpath")
	else
		xmlpath="results_vmaf/${BASENAME}_batch.xml"
		IFS=',' read -a COLS <<< $(./plot_vmaf_vs_frame.py -f "$tsfn" -s "$SAVEIMGDIR/$tsfn.png" "$xmlpath")
	fi
	# some column values come from feeding the .py script with the xml results
	AVG=${COLS#*=}
	STDEV=${COLS[1]#*=}
	MIN=${COLS[2]#*=}
	MAX=${COLS[3]#*=}
	PLOTLINK="file://$PWD/$SAVEIMGDIR/$tsfn.png"

	echo "${tsfn%%-*},$RES,$FRAMERATE,$INTERLACED,$CLIPLEN,$CPULOAD,$CODECPRE,$VBITRATE,$TRANSCSPD,$AVG,$MIN,$MAX,$STDEV,$PLOTLINK" >> "$OUTFILE"
done
