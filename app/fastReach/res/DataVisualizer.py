

import seaborn as sns
import pandas as pd

class DataVisualizer():

    pass



    # %%
    import numpy as np
    import matplotlib.pyplot as plt

    plt.axis([0, 10, 0, 1])

    for i in range(10):
        y = np.random.random()
        plt.scatter(i, y)
        plt.pause(0.05)

    plt.show()

    # %%
    import seaborn as sns
    import pandas as pd
    import numpy as np

    sns.set_theme(style="dark")
    flights = sns.load_dataset("flights")

    for i in range(10):
        y = np.random.random()
        # plt.scatter(i, y)

        data = pd.DataFrame(i,y)

        # Plot each year's time series in its own facet
        g = sns.relplot(
            data=data,
            x="i", y="y",
            kind="line", palette="crest", linewidth=4, zorder=5,
            col_wrap=3, height=2, aspect=1.5, legend=False,
        )

    # %%
