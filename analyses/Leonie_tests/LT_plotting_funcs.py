
# load packages
import pandas as pd
import seaborn as sns
from scipy import stats
import seaborn as sns
import matplotlib.pyplot as plt
from statannotations.Annotator import Annotator
   
# plot with two cats
def plot_2_cats(data, x, y, hue, ylabel, xlabel,cats,palette,title):
    
    cats_0 = data[data[x]==cats[0]]
    cats_1 = data[data[x]==cats[1]]

    pairs = [(cats[0], cats[1])]

    ###  get p values for paired t test between two conditions

    pvalues = [
        stats.ttest_rel( cats_0[y], cats_1[y]).pvalue
        #stats.ranksums(cat_0[dv], cat_1[dv]).pvalue
    ]
    
    # Transform each p-value to "p=" in scientific notation
    formatted_pvalues = [f'p={pvalue:.2e}' for pvalue in pvalues]

    with sns.plotting_context('paper', font_scale = 1.8):

        ### Create new plot
        fig, ax = plt.subplots(1, 1, figsize=(3,5))
        fig.patch.set_alpha(1)

        

        sns.despine() #bottom=True, left=True
        # show boxplots
        ax = sns.boxplot(data = data,x = x, y = y,  palette= [palette[0]*len(pairs)])
        for patch in ax.patches: # adapt alpha
            r, g, b, a = patch.get_facecolor()
            patch.set_facecolor((r, g, b, .6))

        #  show lines connecting pid means observations    
        sns.lineplot(data = data, x = x, y = y, 
                    legend = False, linewidth = 0.5, linestyle = '-',ci =None,color = palette[2], alpha=0.8)
        2

        #Show mean observation with a scatterplot
        sns.stripplot(data = data,x = x, y = y, hue = None,size=8,
                    label=None, marker="s",s = 6, color = palette[2], alpha=0.8)

    
        # show line connecting means
        sns.pointplot(
            data = data,x = x, y = y,
            markers="s", size = 6, ci =None,color = palette[0])


        # Add annotations
        annotator = Annotator(ax, pairs = [(cats[0], cats[1])], data = data,x = x, y = y)
        annotator.configure(text_format="simple")
        annotator.set_pvalues(pvalues)
        annotator.annotate()

        # Label and show
        # label_plot_for_subcats(ax)
        ax.set_title(title)
        ax.set_ylabel(ylabel)
        ax.set_xlabel(xlabel)

        plt.show()

        fig.savefig('results/'+ title + '_' + ylabel + '_' + xlabel + '.png', format='png', transparent=False, bbox_inches='tight', dpi=300)
        fig.savefig('results/'+ title + '_' + ylabel + '_' + xlabel + '.eps', format='eps', transparent=True, bbox_inches='tight', dpi=300)

# plot with three condition (including pID - mean lines)
def plot_3_cats_pID(data, x, y, hue, ylabel, xlabel,cats,palette,data_means,title):


    
    cats_0 = data[data[x]==cats[0]]
    cats_1 = data[data[x]==cats[1]]
    cats_2 = data[data[x]==cats[2]]

    pairs = [(cats[0], cats[1],cats[1])]

    

    with sns.plotting_context('paper', font_scale = 1.8):

        ### Create new plot
        fig, ax = plt.subplots(1, 1, figsize=(3,5))
        fig.patch.set_alpha(1)

        sns.despine() #bottom=True, left=True
         # show boxplots
        ax = sns.boxplot(data = data,x = x, y = y,  palette= [palette[0]*len(pairs)])
        for patch in ax.patches: # adapt alpha
             r, g, b, a = patch.get_facecolor()
             patch.set_facecolor((r, g, b, .6))

        #  show lines connecting pid means observations    
        sns.lineplot(data = data_means, x = x, y = y, hue = hue,
                      legend = False, linewidth = 0.5, linestyle = '-',ci =None,color = palette[2], alpha=0.8)
        2

            
        # show line connecting means
        sns.pointplot(
            data = data,x = x, y = y,
            markers="s", size = 6, ci =None,color = palette[0],legend = True)


        
        # Label and show
        # label_plot_for_subcats(ax)
        ax.set_title(title)
        ax.set_ylabel(ylabel)
        ax.set_xlabel(xlabel)

        plt.show()

        fig.savefig('results/'+ title + '_' + ylabel + '_' + xlabel + '.png', format='png', transparent=False, bbox_inches='tight', dpi=300)
        fig.savefig('results/'+title + '_' + ylabel + '_' + xlabel + '.eps', format='eps', transparent=True, bbox_inches='tight', dpi=300)

def plot_3_cats(data, x, y, ylabel, xlabel,cats,palette,title):


    
    cats_0 = data[data[x]==cats[0]]
    cats_1 = data[data[x]==cats[1]]
    cats_2 = data[data[x]==cats[2]]

    pairs = [(cats[0], cats[1],cats[1])]

    

    with sns.plotting_context('paper', font_scale = 1.8):

        ### Create new plot
        fig, ax = plt.subplots(1, 1, figsize=(3,5))
        fig.patch.set_alpha(1)

        sns.despine() #bottom=True, left=True
         # show boxplots
        ax = sns.boxplot(data = data,x = x, y = y,  palette= [palette[0]*len(pairs)])
        for patch in ax.patches: # adapt alpha
             r, g, b, a = patch.get_facecolor()
             patch.set_facecolor((r, g, b, .6))

                   
        # show line connecting means
        sns.pointplot(
            data = data,x = x, y = y,
            markers="s", size = 6, ci =None,color = palette[0],legend = True)


        
        # Label and show
        # label_plot_for_subcats(ax)
        ax.set_title(title)
        ax.set_ylabel(ylabel)
        ax.set_xlabel(xlabel)

        plt.show()

        fig.savefig('results/'+ title + '_' + ylabel + '_' + xlabel + '.png', format='png', transparent=False, bbox_inches='tight', dpi=300)
        fig.savefig('results/'+title + '_' + ylabel + '_' + xlabel + '.eps', format='eps', transparent=True, bbox_inches='tight', dpi=300)


# plot with three condition 
def plot_3_cats_hue(data, x, y, hue, ylabel, xlabel,cats,palette,data_means,hue2,title):
    
    cats_0 = data[data[x]==cats[0]]
    cats_1 = data[data[x]==cats[1]]
    cats_2 = data[data[x]==cats[2]]

    pairs = [(cats[0], cats[1],cats[1])]

   
    with sns.plotting_context('paper', font_scale = 1.8):

        ### Create new plot
        fig, ax = plt.subplots(1, 1, figsize=(6,5))
        fig.patch.set_alpha(1)

        sns.despine() #bottom=True, left=True

         # show boxplots
        ax = sns.boxplot(data = data,x = x, y = y, hue = hue2,  palette= palette[3:6])
        for patch in ax.patches: # adapt alpha
             r, g, b, a = patch.get_facecolor()
             patch.set_facecolor((r, g, b, .6))
    
         # show line connecting menas
        ax = sns.pointplot(
            data = data,x = x, y = y, dodge=.8 - .8 / 3,
            markers=['s','o','^'],linestyles = ['solid','dotted','dashed'],hue = hue2, size = 6, ci =None,palette= palette[3:6], labels = True)
        

        handles, labels = ax.get_legend_handles_labels()  
       
        plt.legend(handles[3:6],labels[3:6],frameon=True,loc = 'upper left',labelspacing =0.3)
        
        # label_plot_for_subcats(ax)
        ax.set_title(title)
        ax.set_ylabel(ylabel)
        ax.set_xlabel(xlabel)
        
        plt.show()

        fig.savefig('results/'+ title + '_' + ylabel + '_' + xlabel + '.png', format='png', transparent=False, bbox_inches='tight', dpi=300)
        fig.savefig('results/'+title + '_' + ylabel + '_' + xlabel + '.eps', format='eps', transparent=True, bbox_inches='tight', dpi=300)

# plot eeg data with in timeline with 3 conditions using means of all trials

def plot_erp_timeline(data,id_vars, delete_vars, sample_rate,window_start,hue,palette,title):

     with sns.plotting_context('paper', font_scale = 1.8):

        ### Create new plot
        fig, ax = plt.subplots(1, 1, figsize=(9,5))
        fig.patch.set_alpha(1)

        sns.despine() #bottom=True, left=True 
        # prep data
        # remove unnesseary columns 
        data = data.loc[:,data.columns!= delete_vars]
       
         # to long format

        data_long = pd.melt(data, id_vars= id_vars, var_name='timepoint', value_name='µV', col_level=None, ignore_index=True)
        
        # adjust time axis
        data_long['timepoint'] = (((1/sample_rate) * (data_long["timepoint"].str.replace("c_erp","").astype(int)))*1000) +window_start
        

        # plot mean (delete ci = None for shaded confidence interval)

        ax = sns.lineplot(data = data_long, x = 'timepoint', y = 'µV',hue =hue,palette = palette[3:6],style = hue)
 
        
        ax.axhline(0,color = 'black' )

        # Label and show

        ax.set_title(title)


        plt.show()

        fig.savefig('results/'+ title + '.png', format='png', transparent=False, bbox_inches='tight', dpi=300)
        fig.savefig('results/'+title + '.eps', format='eps', transparent=True, bbox_inches='tight', dpi=300)

# plot eeg data with in timeline with 3 conditions using means of all trials

def plot_erp_timeline_2(data_2, id_vars_2,sample_rate,window_start,hue,palette,title):

     with sns.plotting_context('paper', font_scale = 1.8):

        ### Create new plot
        fig, ax = plt.subplots(1, 1, figsize=(9,5))
        fig.patch.set_alpha(1)

        sns.despine() #bottom=True, left=True 
      
       # data_long = pd.melt(data, id_vars= id_vars, var_name='timepoint', value_name='µV', col_level=None, ignore_index=True)
        data_2_long = pd.melt(data_2, id_vars= id_vars_2, var_name='timepoint', value_name='µV', col_level=None, ignore_index=True)
        
        # adjust time axis
       
        data_2_long['timepoint'] = (((1/sample_rate) * (data_2_long["timepoint"].str.replace("c_erp","").astype(int)))*1000) + window_start

      
        ax = sns.lineplot(data = data_2_long, x = 'timepoint', y = 'µV',hue =hue,palette = palette[3:6],style = hue)
 
        
        ax.axhline(0,color = 'black' )

        # Label and show

        ax.set_title(title)


        plt.show()

        fig.savefig('results/'+ title + '.png', format='png', transparent=False, bbox_inches='tight', dpi=300)
        fig.savefig('results/'+title + '.eps', format='eps', transparent=True, bbox_inches='tight', dpi=300)