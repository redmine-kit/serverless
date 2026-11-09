"""Makes a Graphviz SVG self-contained: the icons, which Graphviz references
by their path in the diagrams package, become data: URIs, so the SVG renders
on GitHub and on the documentation site. The font gets fallbacks for readers
without Noto Sans CJK JP."""

import base64
import re
import sys

FONTS = "'Noto Sans CJK JP', 'Noto Sans JP', 'Hiragino Sans', 'Yu Gothic', sans-serif"


def embed(match):
    path = match.group(2)
    with open(path, "rb") as icon:
        data = base64.b64encode(icon.read()).decode()
    return f'{match.group(1)}="data:image/png;base64,{data}"'


path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    svg = f.read()
svg = re.sub(r'(xlink:href|href)="(/[^"]+\.png)"', embed, svg)
svg = re.sub(r'font-family="[^"]*"', f'font-family="{FONTS}"', svg)
if re.search(r'href="/', svg):
    sys.exit(f"{path}: an image still points to a local file")
with open(path, "w", encoding="utf-8") as f:
    f.write(svg)
