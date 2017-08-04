# h265_benchmark
_Fileapp is a private property of Igolgi, Inc. (Copyright 2012-2016)_  
_VMAF is a public project of Netflix, Inc. (Copyright 2016-2017)_

This repository serves as a work environment for extensive video transcoding testing (Igolgi, Inc.) and is not intended for public or outside use.  
All scripts are written and tested on Ubuntu 16.04.3 LTS (Xenial Xerus).
In addition, testing is done with fileapp slightly modified in quality-to-preset mapping. (See x265-preset-chart.pdf)

---

###### \*There are four interwoven bash scripts, though only two are necessarily ran to procure formatted test output. (Consult flowchart.jpg)

- *Fileapp_transcode_vmaf.sh* takes a video source, first decodes it, then transcodes it through **fileapp** for a specified bitrate for each x265 testing preset 0-9 (mapped to --quality 1 to 10) and decodes the fileapp output. It then uses vmaf, located either in the script directory or its sub-directories, to compare the initial and latest decoded videos, generating VMAF and PSNR scores for each of the 10 preset outputs.  
To run this:  
   ```bash
   ./fileapp_transcode_vmaf.sh <input_file.ts> <kbps_br> <format> <width> <height>
   # kbps_br is passed to fileapp while format, width, and height are vmaf required parameters
   ```

- *Batch_fileapp_transcode_vmaf.sh* is a batch version of the previous, much like **_run_vmaf_in_batch_** is to **_run_vmaf_**. It takes a range of kbitrate and runs *fileapp_transcode_vmaf.sh* for each of them by interval kbr. (So number of output is 10 presets x floor(range/intvals)+1). To run this:  
   ```bash
   ./batch_fileapp_transcode_vmaf.sh <input_file.ts> <start_kbps> <intvals> <end_kbps> <format> <width> <height>
   ```

After running either one of the above on a target file:

- *Make_csv_archive.sh* will extract certain specs from the fileapp outputs via **mediainfo** utility and from the speed log made by *fileapp_transcode_vmaf.sh*, plot the VMAF and PSNR data together from vmaf, and create a .csv file with the information along with images of each plot. To run this:
   ```bash
   ./make_csv_archive.sh [-o OUTFILE] [-a] <input_file.ts>
   # note that the input_file should be simply the same param used for the first script
   ```
   - *plot_vmaf_vs_frame.py* used by the previous can also be used manually to generate specific, interactive plots. These figures support zoom and click-for-frame-stats features. It supports multiple single or batch vmaf XML feed and overlaying data from different source or score types. (It's even possible to click the legend to turn dataset visibility on or off, though this is not yet implemented.)  
   To run this python script:
   ```bash
   ./plot_vmaf_vs_frame.py [-h] [-l] [-o] [-v {1,2}] [-s OUTPATH] result.xml [result.xml ...]
   ```
