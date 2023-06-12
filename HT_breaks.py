import numpy as np
import pandas as pd

def HT_breaks(x, k):
    if k > 1:
        x0 = [x]
        xm0 = []
        for i in range(k-1):
            xm0.append(np.mean(x0[i]))
            x0.append(x0[i][x0[i] > xm0[i]])
            if len(x0[i+1]) <= 2:
                break
        xbid = [np.min(x)] + xm0 + [np.max(x)]
        xmem = pd.cut(x, bins=xbid, labels=list(range(1, k+1)), include_lowest=True).astype(int)
        xsize = xmem.value_counts().to_numpy()
        return {'bin': xbid, 'size': xsize, 'member': xmem}
    else:
        return None
