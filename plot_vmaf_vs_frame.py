#!/usr/bin/env python
"""Generate plots of at least one .xml file from run_vmaf/_etc output for VMAF(/ETC)_Score vs Frame."""
__credits__ = ["Ben Li", "Stephen Martucci", "Kishore Ramachandran"]
__maintainer__ = "Ben Li"
__contact__ = "ben.li@igolgi.com"
__date__ = "July 07, 2017"
__status__ = "Production Beta"

import argparse, os.path, re
import xml.etree.ElementTree as et
import matplotlib.pyplot as plt
import matplotlib.cm as cm

fig_hdl = {}		#tracks figures from the same sources ('title':[figure1, figure2,...])
plt_data = {}		#each figure info ('figure':[ds_count, was_drawn_on, frame[min1, max1,...], score_types[]]
stats_output = []
max_ods = 10		#max number of overlapping dataset on a plot
iu_clr = u'#daa520'			#cursor interaction display color
cmap = cm.get_cmap('tab10')			#plot color scheme

def init_newplot( figr ):
	"""Initializes an AxesSubplot instance on a figure obj with its labels and interactives."""
	nosuftitle = title.rsplit('_', 1)[0]
	ax = figr.add_subplot(111)
	ax.set_title(nosuftitle, y=1.05, fontweight='bold')
	if not args.fps:
		ax.set_xlabel('Frame', labelpad=5, weight='bold')
		ax.set_xlim((0, num_fr))
	else:
		ax.set_xlabel('Time (s)', labelpad=5, weight='bold')
		ax.set_xlim((0, num_fr/args.fps))
	ax.set_ylabel(score_t+' Score', labelpad=10, weight='bold')
	if not args.auto:
		ax.set_ylim((0,100))
	ax.minorticks_on()
	ax.grid(b=True, which='major', axis='y', linestyle=':', linewidth=1)
	ax.annotate('Resolution:\n'+resol, xy=(.06,.03), xycoords='figure fraction', va='center', ha='center')
	ax.annotate('# frames:\n%u'%num_fr, xy=(.945,.03), xycoords='figure fraction', va='center', ha='center')

	plt_data[figr] = [0.0, False, [100.0, 0.0]*num_fr, [score_t]]
	cid1 = figr.canvas.mpl_connect('button_press_event', on_click)
	return ax
def on_click( event ):
	"""Manager for info display on mouse-click from interactive user."""
	ax = event.inaxes
	try:
		fig = ax.get_figure()
		fdref = plt_data[fig]
		if args.fps:
			x_ds = int(round(event.xdata*args.fps))
			x_pos = x_ds/args.fps
		else:
			x_ds = x_pos = int(round(event.xdata))
		fmin = fdref[2][2*x_ds]; fmax = fdref[2][2*x_ds+1]

		if fdref[1]:
			# so as not to delete a dataset in 'line' plots when no click line was (re)drawn
			del ax.lines[-1]
			del ax.texts[-1]
		ax.axvline(x_pos, color=iu_clr, linewidth=1)
		if fdref[0] == 1:
			ax.text(.5, 1.01, 'frame = %u, score = %.4f'%(x_ds, fmin), color=iu_clr, ha='center', va='bottom', style='italic', transform=ax.transAxes)
		else:
			ax.text(.5, 1.01, 'frame = %u, min = %.2f, max = %.2f, range = %.2f'%(x_ds, fmin, fmax, fmax-fmin), color=iu_clr, ha='center', va='bottom', style='italic', transform=ax.transAxes)

		event.canvas.draw()
		fdref[1] = True
	# when clicking outside of plot area, ignore error
	except AttributeError, TypeError:
		try:
			fdref[1] = False
		except UnboundLocalError:
			pass
		pass

# MAIN CODE STARTS HERE
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('-a', '--auto-scale', action='store_true', dest='auto', help='autoscale y-axis scores instead of 0-100 set range')
parser.add_argument('-l', '--line', action='store_true', help='create line plots instead of default scatterplots')
parser.add_argument('-o', '--overlay', action='store_true', help='plot data from different sources on the same figure')
parser.add_argument('-v', '--verbosity', default=0, type=int, choices=[1,2], dest='statverb', help='1 - show mean & std.dev.; 2 - plus show min & max')
parser.add_argument('-s', '--savefig', metavar='OUTPATH', dest='savepath', help='image of plot will be saved to outpath and not shown, if single figure, and print stats if single dataset')
parser.add_argument('-t', '--time', type=float, metavar='FRAMERATE', dest='fps', help='plot vmaf vs time instead; making x-axis with respect to time or length of video')
parser.add_argument('-f', '--find', nargs='+', metavar='FILENAME', dest='datalabels', help=argparse.SUPPRESS) #DEV USE: isolate single/certain dataset(s) from batch results via filename pattern(s)
parser.add_argument('infiles', nargs='+', metavar='result.xml', help='vmaf\'s XML output files')
args = parser.parse_args()

for xmlpath in args.infiles:
	if not os.path.isfile(xmlpath):
		print 'Error: \'%s\' is not a valid file path. Skipping.' % xmlpath
		continue

	# for dealing with VMAF batch result or multi-XML-in-one files
	with open(xmlpath, 'r') as xmlfile:
		xmlstr = xmlfile.read()
	xmlstr_list = xmlstr.split('\n\n')

	for idx in range(len(xmlstr_list)-1):
		# parse for identification labels and tree info
		try:
			root = et.fromstring(xmlstr_list[idx].split('\n', 1)[1])
		except:
			print 'Error: \'%s\' is not a proper XML file. Skipping.' % xmlpath
			break
		file_id = root.find('asset').get('identifier')
		matches = re.match("[a-z]+_[\d_]+_([^:\?*+%]+)_vs_([^:\?*+%]+)_[\da-z]+_q_([\dx]+)", file_id)
		title = matches.group(1)
		datalabel = matches.group(2)
		resol = matches.group(3)
		score_t = root.get('executorId').split('_', 1)[0]
		frames = root.find('frames').findall('frame')
		num_fr = len(frames)

		# only plot desired data from, esp. batch, vmaf results if find opt is used
		if args.datalabels and not any(pattern in datalabel for pattern in args.datalabels):
			continue

		# change title key here to match the one key in fig_hdl if overlay override is enabled
		if args.overlay and len(fig_hdl.keys()) > 0:
			[title] = [onlykey for onlykey in fig_hdl.keys()]

		# make new or retrieve existing figure handle with title name (& # frames)
		if title not in fig_hdl:
			fig_hdl[title] = [plt.figure()]
			fig = fig_hdl[title][0]
			axe = init_newplot(fig)
		else:
			fig = fig_hdl[title][-1]
			if plt_data[fig][0] >= max_ods:
				# link a new figure and get newest fig & axes
				fig_hdl[title].append(plt.figure())
				fig = fig_hdl[title][-1]
				axe = init_newplot(fig)
			else:
				axe = fig.gca()

		# extract (frame|time, score) data and find global [min,max]/frame & [min,max, std.dev.]/dataset
		x_var = []
		dataset = []
		ds_avg = float(root.find('aggregate').get(score_t+'_score'))
		ds_min = 100.0; ds_max = 0.0
		ds_stdev = 0.0
		ds_count = plt_data[fig][0]
		for fr_idx in range(num_fr):
			if args.fps:
				x_var.append(fr_idx/args.fps)
			else:
				x_var.append(fr_idx)

			score = float(frames[fr_idx].get(score_t+'_score'))
			dataset.append(score)
			ds_stdev += (score - ds_avg)**2
			if ds_min > score:
				ds_min = score
			elif ds_max < score:
				ds_max = score
			frmm_list = plt_data[fig][2]
			if ds_count != 0:
				if frmm_list[2*fr_idx] > score:
					frmm_list[2*fr_idx] = score
				elif frmm_list[2*fr_idx+1] < score:
					frmm_list[2*fr_idx+1] = score
			else:
				frmm_list[2*fr_idx] = frmm_list[2*fr_idx+1] = score
		ds_stdev /= num_fr; ds_stdev **= 0.5

		# legend text manipulation for multi-score-types plots
		score_types = plt_data[fig][3]
		if score_t not in score_types:
			if len(score_types) == 1:
				hdls, lbls = axe.get_legend_handles_labels()
				[hdls[i].set_label(lbls[i]+' (%s)' % score_types[0]) for i in range(len(hdls))]
			score_types.append(score_t)
			axe.set_ylabel(' & '.join(score_types)+' Score', weight='bold')
			datalabel += ' (%s)' % score_t
		elif len(score_types) >= 2:
			datalabel += ' (%s)' % score_t

		# add dataset & info labels to subplot, readjust legend, and increment ds count for this figure
		c = cmap(plt_data[fig][0] / max_ods)
		if args.line:
			axe.plot(x_var, dataset, label=datalabel, color=c, linewidth=1)
		else:
			axe.scatter(x_var, dataset, label=datalabel, s=10, color=c, alpha=.5)
		if args.statverb >= 1:
			axe.annotate('mean=%.2f, dev=%.2f'%(ds_avg,ds_stdev), xy=(.903, ds_avg), xycoords=('figure fraction', 'data'), size=8, color=c, va='center', weight='bold')
		if args.statverb >= 2:
			if ds_min != 0:
				axe.annotate('<--min=%.3f'%ds_min, xy=(.903, ds_min), xycoords=('figure fraction', 'data'), size=7, color=c, va='center', weight='semibold')
			if ds_max != 100:
				axe.annotate('<--max=%.3f'%ds_max, xy=(.903, ds_max), xycoords=('figure fraction', 'data'), size=7, color=c, va='center', weight='semibold')
		plt_data[fig][0] += 1
		axe.legend(loc=0)
		if len(score_types) == plt_data[fig][0]:
			stats_output.append('%s: mean=%.3f,stdev=%.3f,min=%.2f,max=%.2f' % (score_t, ds_avg, ds_stdev, ds_min, ds_max))

# show figures or, if savefig set and there's only one fig, save it, and if only one ds, print stats
if args.savepath:
	if len(plt_data.keys()) == 1:
		if plt_data[fig][0] == len(score_types):
			for stats_str in stats_output: print stats_str
		fig.set_size_inches(16, 9, forward=True)
		plt.savefig(args.savepath, dpi=fig.dpi, orientation='landscape')
		raise SystemExit
	else:
		print 'Error: Cannot save to specified path as more than one figure exist; displaying instead.'
plt.show()
