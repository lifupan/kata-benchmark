import numpy as np
import sys 
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

if len(sys.argv) < 3:
    sys.exit("need a csv file and an output file path as parameter")

file_name = sys.argv[1]
out_file = sys.argv[2]

data= pd.read_csv(file_name)
data.head()
width = 0.85       # the width of the bars: can also be len(x) sequence
 
fig, ax = plt.subplots(figsize=(30,12))

ax.bar(data['CPU'], data['%usr'], width, label='%usr')
ax.bar(data['CPU'], data['%sys'], width, bottom=data['%usr'],label='%sys')
ax.bar(data['CPU'], data['%guest'], width, bottom=data['%usr']+data['%sys'],label='%guest')
ax.bar(data['CPU'], data['%idle'], width, bottom=data['%usr']+data['%sys']+data['%guest'],label='%idle')

ax.set_ylabel('CPU usage percent')
ax.set_title('CPU usage compared between usr, sys, guest and idle')
ax.legend()
plt.xticks(rotation=300)
 
plt.savefig(out_file + ".png")
plt.close()
print "produced the image file as: " + out_file + ".png"
