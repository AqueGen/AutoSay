"""AutoSay project icon: the wave you type on joining, in a chat bubble.

400x400 PNG. A gold speech bubble carrying a blue o/ - the thing players
actually type when they land in a group, which is the addon's whole job. The
blue and the gold are the addon's own, taken from the TOC title.

What it replaces is a painted fantasy piece: rune-carved medallion, "AS"
lettering, fire spiral, scrolls, quills. Handsome at full size and mud at 48px,
where the icon is actually seen. That painting still earns its space as the
project page banner.

Two shapes were tried and dropped:
  - a rune ring around the bubble. At 64px the broken ring reads as a loading
    spinner, and a radial ring is Cooldown Manager Profiles' vocabulary, not
    this addon's.
  - three "typing" dots inside the bubble. Legible, but it is the iMessage
    indicator - nothing in it says World of Warcraft.

400 exactly, because CurseForge's logo cropper opens on a fixed 400x400
selection pinned to the top left: a larger image comes out cropped unless the
author drags the handles.
"""
from PIL import Image, ImageDraw, ImageFilter

S = 512      # drawn large, downsampled at the end so the curves stay smooth
OUT_SIZE = 400
BG = (24, 27, 34)
BG_EDGE = (44, 49, 60)
BLUE = (0, 153, 255)
GOLD = (255, 215, 0)
GOLD_DEEP = (232, 160, 12)

# Bubble body and tail. The body fills 72% of the tile: the tile's own edge all
# but disappears against a dark list background, so whatever is inside has to
# carry the icon alone.
BOX = [72, 108, 440, 340]
TAIL = [(150, 332), (150, 412), (227, 336)]

img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

# Rounded slate tile with a hairline edge, so the icon has a shape of its own
# against both light and dark list backgrounds.
d.rounded_rectangle([0, 0, S - 1, S - 1], radius=96, fill=BG, outline=BG_EDGE, width=4)


def bubble(dd, fill):
    dd.rounded_rectangle(BOX, radius=54, fill=fill)
    dd.polygon(TAIL, fill=fill)


def gold_ramp(shape):
    """Gold falling into amber top to bottom, cut to the given shape.

    A flat fill reads as cheap beside the painted logo this replaces; two stops
    give the bubble some body without turning it back into an illustration.
    """
    ramp = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    px = ramp.load()
    for y in range(S):
        t = y / (S - 1)
        row = tuple(int(a + (b - a) * t) for a, b in zip(GOLD, GOLD_DEEP)) + (255,)
        for x in range(S):
            px[x, y] = row
    mask = Image.new("L", (S, S), 0)
    shape(ImageDraw.Draw(mask), 255)
    ramp.putalpha(mask)
    return ramp


# Glow under the bubble, on its own layer so the blur cannot eat the tile edge.
glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
bubble(ImageDraw.Draw(glow), GOLD + (95,))
img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(22)))

img.alpha_composite(gold_ramp(bubble))

# o/ drawn as geometry rather than type: a ring and a leaning bar survive being
# 48 pixels wide, letters do not. The ring is stroked heavier than it looks like
# it needs, because a thin ring is the first thing to turn to mush - but still
# lighter than the slash, the way a typeface weights the pair.
w = ImageDraw.Draw(img)
R_OUT, R_IN = 58, 29
OX, OY = 184, 224
w.ellipse([OX - R_OUT, OY - R_OUT, OX + R_OUT, OY + R_OUT], fill=BLUE)
w.line([(312, 288), (385, 156)], fill=BLUE, width=34)

# The hole keeps the bubble's own gold at that height, so it reads as a hole.
# Filling it with flat gold turns the glyph into an eye.
img.alpha_composite(gold_ramp(lambda dd, f: dd.ellipse(
    [OX - R_IN, OY - R_IN, OX + R_IN, OY + R_IN], fill=f)))

out = "icon.png"
# Flattened onto the same slate as the tile: the upload widget refuses
# transparent corners, and black corners would read as a hard square on a light
# list row.
small = img.resize((OUT_SIZE, OUT_SIZE), Image.LANCZOS)
ground = Image.new("RGB", (OUT_SIZE, OUT_SIZE), BG)
ground.paste(small, (0, 0), small)
ground.save(out)
print(out)
