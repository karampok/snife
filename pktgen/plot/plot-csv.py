import sys
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.ticker import ScalarFormatter
import matplotlib.ticker as ticker
import time

def millions_formatter(x, pos):
   return '{:.0f}M'.format(x * 1e-6)




def parse(file):
    def is_unix_timestamp(string):
        try:
            timestamp = int(string)
            return timestamp >= 0  # Check if the value is a non-negative integer
        except ValueError:
            return False

    data = {'title': '', 'fields': [], 'values': [], 'meta': []}
    with open(file, 'r') as file:
        for line in file:
            match line:
                case string if string.startswith("#T"):
                    data['title']= string[2:]
                case string if string.startswith("size: "):
                    m = {}
                    for pair in string.split(', '):
                        key, value = pair.split(': ')
                        m[key.strip()] = value.strip()
                    data['meta'].append(m)
                case string if string.startswith("TS"):
                    data['fields'] =string.split(',')
                case string if is_unix_timestamp(string.split(',')[0]):
                    TS, TX, RX, totalTX, totalRX, n = line.split(',')
                    data['values'].append([int(TS), int(TX), int(RX)])
    return data

def plot_txrx(data,subplot):
    ts = [d[0] for d in data['values']]
    tx = [d[1] for d in data['values']]
    ymax=max(tx)
    rx = [d[2] for d in data['values']]

    plt.subplot(*subplot)
    s = data['title']
    for m in data['meta']:
        prev=int(m["ts"])
        print(*[f"{key}: {value}" for key, value in m.items()])
        plt.axhline(y=int(m["mpps"]),linewidth=2,  linestyle='--',alpha=0.5)
        plt.fill_between([prev, prev+100],int(m["mpps"]), int(m["mpps"])-int(m["LossLimit"]), color='red', alpha=0.8)
        if int(m["mpps"]) > ymax:
            ymax=int(m["mpps"])

        # plt.plot([min(ts), min(ts)], [0, max(tx)], color='gray', linewidth=1)  # Draw the gray array
        # plt.text((min(ts)),max(tx), "text", ha='left', fontsize=12)  # Add text annotation above the array


        #plt.text(max(ts)+0.2, int(m["mpps"])+1, 'mpps '+m["size"],  ha='center', va='top')



    plt.title(data['title'])
    plt.plot(ts, tx, label='TX ')
    plt.plot(ts, rx, label='RX ')
    plt.ylim(ymin=0, ymax=ymax*1.01)
    plt.legend()
    plt.xlabel('unix timestamp (sec)')
    plt.ylabel('packets per second (pps)')
    plt.xticks(rotation=75)  # Rotate x-axis labels by 90 degrees
    plt.grid(axis='y')
    plt.xlim(xmin=min(ts), xmax=max(ts))

    plt.gca().yaxis.set_major_formatter(ticker.FuncFormatter(millions_formatter))

    def epoch_formatter(x, pos):
        return '{:.000f}'.format(x- min(ts) )
    plt.gca().xaxis.set_major_formatter(ticker.FuncFormatter(epoch_formatter))



if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: python plotme.py data.csv")
        os._exit(1)
    data_file = sys.argv[1]
    data=parse(data_file)
    plt.figure()
    subplot = (2,1,1)
    plot_txrx(data,subplot)
    plt.tight_layout()
    plt.show()
