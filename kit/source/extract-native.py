#!/usr/bin/env python3
"""Extract native masked product figures from the authoritative 30-page PDF.
No source images are recolored or approved by this step.
Usage: python extract-native.py source.pdf output-directory
"""
import fitz, sys, json, hashlib
from pathlib import Path
pdf, out = Path(sys.argv[1]), Path(sys.argv[2])
doc = fitz.open(pdf)
assert len(doc)==30, "Wrong PDF page count"
out.mkdir(parents=True, exist_ok=True)
manifest = {"pdf_sha256":hashlib.sha256(pdf.read_bytes()).hexdigest(),"pages":30,"products":[]}
for page_num in range(9,29):
    page=doc[page_num-1]
    code=f"{page_num-6:02d}"
    folder=out/code
    folder.mkdir(exist_ok=True)
    figures=[]
    for x in page.get_images():
        ref,mask,w,h=x[:4]
        if not mask or w<150 or h<200: continue
        rects=page.get_image_rects(ref)
        if not rects: continue
        rgb=fitz.Pixmap(doc,ref)
        alpha=fitz.Pixmap(doc,mask)
        target=folder/f"{ref}.png"
        fitz.Pixmap(rgb,alpha).save(str(target))
        figures.append(dict(xref=ref,mask=mask,width=w,height=h,rects=[list(r) for r in rects],path=str(target.relative_to(out)),sha256=hashlib.sha256(target.read_bytes()).hexdigest()))
    figures.sort(key=lambda f:max((r[2]-r[0])*(r[3]-r[1]) for r in f["rects"]),reverse=True)
    manifest["products"].append(dict(code=code,pdf_page=page_num,figures=figures,qa="pending",release=False))
(out/"native-index.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding="utf-8")
print(len(manifest["products"]),sum(len(p["figures"]) for p in manifest["products"]))
