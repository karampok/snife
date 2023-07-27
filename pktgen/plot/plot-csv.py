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
                    TS, TX, RX, totalTX, totalRX,n = line.split(',')
                    data['values'].append([int(TS), int(TX), int(RX)])
    return data

def plot_txrx(data,subplot):
    ts = [d[0] for d in data['values']]
    tx = [d[1] for d in data['values']]
    rx = [d[2] for d in data['values']]

    plt.subplot(*subplot)
    s = data['title']
    for m in data['meta']:
        print(*[f"{key}: {value}" for key, value in m.items()])
        plt.axhline(y=int(m["mpps"]),  linestyle='--',alpha=0.5)
        x=max(ts)
        plt.text(max(ts)+0.2, int(m["mpps"])+1, 'mpps '+m["size"],  ha='center', va='top')


    plt.title(data['title'])
    plt.plot(ts, tx, label='TX ')
    plt.plot(ts, rx, label='RX ')
    plt.legend()
    plt.xlabel('unix timestamp (sec)')
    plt.ylabel('packets per second (pps)')
    plt.xticks(rotation=75)  # Rotate x-axis labels by 90 degrees
    plt.grid(axis='y')
    plt.ylim(ymin=0, ymax=40e6)

    plt.gca().yaxis.set_major_formatter(ticker.FuncFormatter(millions_formatter))
    plt.locator_params(axis='x', nbins=50)

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
