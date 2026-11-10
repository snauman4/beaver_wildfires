# Inline data/poudre_animation.json and data/poudre_panel.json into the HTML template
# -> index.html at the repo root (single self-contained file; GitHub Pages serves it)
#    and a copy at outputs/poudre_animation.html.
import json, sys
t = open('scripts/poudre_animation_template.html').read()
d = open('data/poudre_animation.json').read()
p = open('data/poudre_panel.json').read()
cv = open('data/poudre_stream_cov.json').read()
assert '/*DATA*/null' in t and '/*PANEL*/null' in t and '/*COV*/null' in t
out = t.replace('/*DATA*/null', d).replace('/*PANEL*/null', p).replace('/*COV*/null', cv)
import os
os.makedirs('outputs', exist_ok=True)
for path in ('index.html', 'outputs/poudre_animation.html'):
    open(path, 'w').write(out)
print('wrote index.html and outputs/poudre_animation.html', round(len(out) / 1e6, 2), 'MB')
