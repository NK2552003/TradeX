"""Generate the alphajournal publication pack with python-docx.

Run with the bundled Codex Python runtime. This file is the editable source for
the twenty-three Word documents in this directory.
"""

from pathlib import Path
import json
import re
from publication_expansion import extend_documents
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn

OUT = Path(__file__).resolve().parent
ENTITY = "Alphajournal"
EMAIL = "h82292245@gmail.com"
PRIVACY_EMAIL = "h82292245@gmail.com"
DOMAIN = "alphajournal.in"
DATE = "9 November 2026"


def P(title, intro, sections, audience="alphajournal users", kind="Public policy"):
    return dict(title=title, intro=intro, sections=sections, audience=audience, kind=kind)


from publication_policies import POLICIES, apply_public_policies

FILENAMES = ['01_Privacy_Policy.docx', '02_Terms_of_Service.docx', '03_Cookie_and_Similar_Technologies_Policy.docx', '04_Cookie_Consent_Notice_and_Deployment_Spec.docx', '05_Subscription_Cancellation_and_Refund_Policy.docx', '06_Trading_and_AI_Risk_Disclaimer.docx', '07_End_User_License_Agreement.docx', '08_Acceptable_Use_Policy.docx', '09_Community_Guidelines_and_Content_Policy.docx', '10_Affiliate_Program_Agreement.docx', '11_Affiliate_Marketing_and_Brand_Guidelines.docx', '12_Affiliate_Commission_Payout_and_Tax_Policy.docx', '13_Account_Deletion_and_Data_Retention_Policy.docx', '14_Security_and_Incident_Communication_Policy.docx', '15_Product_Operations_and_Publication_Guide.docx']
DOCS = []
for filename in FILENAMES:
    title, intro, sections = POLICIES[int(filename[:2])]
    DOCS.append((filename, P('Alphajournal ' + title, intro, sections)))
DOCS = extend_documents(DOCS, P)
DOCS = apply_public_policies(DOCS)
for filename, spec in DOCS:
    if int(filename[:2]) in (4, 15):
        spec['status'] = 'Release resource'
    elif spec['status'] == 'Policy':
        spec['effective'] = '2026-11-09'


def set_cell_shading(cell, fill):
    tcPr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:fill"), fill)
    tcPr.append(shd)


def add_page_number(para):
    run = para.add_run()
    fld = OxmlElement("w:fldSimple")
    fld.set(qn("w:instr"), "PAGE")
    run._r.addnext(fld)


def build(filename, spec):
    doc = Document()
    compact = True
    ultra = False
    sec = doc.sections[0]
    sec.top_margin = Inches(0.63 if ultra else 0.70)
    sec.bottom_margin = Inches(0.56 if ultra else 0.62)
    sec.left_margin = Inches(0.88)
    sec.right_margin = Inches(0.88)
    sec.header_distance = Inches(0.34)
    sec.footer_distance = Inches(0.34)

    styles = doc.styles
    normal = styles["Normal"]
    normal.font.name = "Arial"
    normal.font.size = Pt(9.5 if ultra else 10)
    normal.font.color.rgb = RGBColor(25, 25, 25)
    normal.paragraph_format.space_after = Pt(4.5 if ultra else 5.5)
    normal.paragraph_format.line_spacing = 1.08 if ultra else 1.10
    for name, size, before, after in [("Title", 18.5 if ultra else 19, 0, 10), ("Heading 1", 11.5 if ultra else 12, 8 if ultra else 10, 3 if ultra else 4)]:
        s = styles[name]
        s.font.name = "Arial"
        s.font.size = Pt(size)
        s.font.bold = True
        s.font.color.rgb = RGBColor(0, 0, 0)
        s.paragraph_format.space_before = Pt(before)
        s.paragraph_format.space_after = Pt(after)
        s.paragraph_format.keep_with_next = True
        if name == "Title":
            ppr = s._element.get_or_add_pPr()
            for border in ppr.findall(qn("w:pBdr")):
                ppr.remove(border)

    t = doc.add_paragraph(style="Title")
    t.add_run(re.sub(r"[^\w\s]", " ", spec["title"]))
    meta = doc.add_paragraph()
    meta.paragraph_format.space_after = Pt(9 if compact else 13)
    r = meta.add_run(f"ALPHAJOURNAL  |  {spec['status'].upper()}  |  Updated {spec['updated']}")
    r.bold = True
    r.font.size = Pt(8.5)
    r.font.color.rgb = RGBColor(85, 85, 85)
    doc.add_paragraph(spec["intro"])
    scope = doc.add_paragraph("Applies to Alphajournal. Contact: h82292245@gmail.com.")
    scope.paragraph_format.space_after = Pt(7 if compact else 10)
    scope.runs[0].italic = True
    number = int(filename[:2])
    weights = [len(body.split()) + 25 for _, body in spec["sections"]]
    cover_weight = len(spec["intro"].split()) + 100
    page_count = max(1, (sum(weights) + cover_weight + 749) // 750)
    target = (sum(weights) + cover_weight) / page_count
    running_words = cover_weight
    next_page = 1
    for heading, body in spec["sections"]:
        weight = len(body.split()) + 25
        if next_page < page_count and running_words + weight / 2 > target * next_page:
            doc.add_page_break()
            next_page += 1
        doc.add_heading(re.sub(r"[^\w\s]", " ", heading), level=1)
        paragraph = doc.add_paragraph(body)
        paragraph.paragraph_format.widow_control = True
        running_words += weight

    footer = sec.footer.paragraphs[0]
    footer.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    fr = footer.add_run("alphajournal  |  ")
    fr.font.size = Pt(8)
    fr.font.color.rgb = RGBColor(95, 95, 95)
    add_page_number(footer)
    doc.core_properties.title = spec["title"]
    doc.core_properties.subject = "alphajournal publication pack"
    doc.core_properties.author = "alphajournal"
    doc.save(OUT / filename)


def export_readers():
    readable = OUT / "readable"
    readable.mkdir(exist_ok=True)
    entries = []
    for filename, spec in DOCS:
        title = spec["title"].removeprefix("alphajournal ").removeprefix("Alphajournal ")
        body = f"# {title}\n\n{spec['status']} | Updated {spec['updated']}\n\n{spec['intro']}\n"
        for heading, text in spec["sections"]:
            body += f"\n## {heading}\n\n{text}\n"
        (readable / (spec["id"] + ".md")).write_text(body)
        entries.append({**{key: spec[key] for key in ["id", "group", "updated", "status", "intro"]},
                        "title": title, "source": filename,
                        "sections": [{"title": title, "body": body} for title, body in spec["sections"]]})
    target = OUT.parent.parent / "assets/legal/publication_library.json"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(entries, ensure_ascii=False, indent=2) + "\n")


def main():
    export_readers()
    for filename, spec in DOCS:
        build(filename, spec)
    print(f"Created {len(DOCS)} DOCX files in {OUT}")


if __name__ == "__main__":
    main()
