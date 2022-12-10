
# import matplotlib as plt
import more_itertools
import matplotlib.pyplot as plt
import numpy as np

titles = ["Screwtape", "Leibowitz", "Silence", "C&P", "Ender's", "Love-Ruins", "Leopard", "Faces", "Lear", "Iliad", "Confessions", "Violent"]
avgs = [4.4,4.4,3.6,4.2,3.6,3.8,3.833333333,4.5,3,3.8,4,3.833333333]
stds = [0.894427191,0.5477225575,0.5477225575,0.8366600265,1.341640786,0.8366600265,1.169045194,0.8366600265,1.264911064,0.4472135955,0.894427191,1.169045194]
y_pos = np.arange(len(titles))

its = [avgs, titles, stds]
its_sorted = more_itertools.sort_together(its)
avgs, titles, stds = its_sorted

# Build the Scores plot
fig, ax = plt.subplots()
ax.barh(y_pos, avgs, xerr=stds, align="center",
        alpha=0.5, ecolor="black", capsize=10)
ax.set_ylabel("Book")
ax.set_yticks(y_pos)
ax.set_yticklabels(titles)
ax.set_title("Scores and Deviations")
ax.yaxis.grid(True)

# Save the figure and show
plt.tight_layout()
plt.savefig("scores.png")
# plt.show()

its = [stds, titles]
its_sorted = more_itertools.sort_together(its)
stds, titles = its_sorted
print(str(its_sorted))
print(str(stds))

fig, ax = plt.subplots()
ax.barh(y_pos, stds, align="center",
        alpha=0.5, ecolor="black", capsize=10)
ax.set_ylabel("Book")
ax.set_yticks(y_pos)
ax.set_yticklabels(titles)
ax.set_title("Largest Std. Devs")

plt.tight_layout()
plt.savefig("stddevs.png")
# plt.show()
