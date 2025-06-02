import numpy as np
from PIL import Image
import random

CI = 3
CO = 16 
KX = KY = 3
I_F_BW = 8
W_BW = 8
B_BW = 8

img = Image.open("../../dataset/img1.jpg").convert("L").resize((6, 6))
img_array = np.array(img)

if img_array.max() > 127:
    img_array = (img_array / 255 * 127).astype(np.int8)

H, W = img_array.shape

with open("../inout/in_fmap.txt", "w") as f:
    for i in range(H - KY + 1):
        for j in range(W - KX + 1):

            patch = img_array[i:i+KY, j:j+KX].flatten()
            fmap_values = np.tile(patch, CI)
            f.write(" ".join(map(str, fmap_values)) + "\n")

with open("../inout/in_weight.txt", "w") as f:
    for _ in range(CO):
        weights = [str(random.randint(-128, 127)) for _ in range(CI * KX * KY)]
        f.write(" ".join(weights) + "\n")

with open("../inout/in_bias.txt", "w") as f:
    for _ in range(CO):
        f.write(str(random.randint(-128, 127)) + "\n")
