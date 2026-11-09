"""Verify all generated publication formats agree and have no placeholders."""
import json
import re
from pathlib import Path
from docx import Document
from generate_documents import DOCS

root = Path(__file__).resolve().parent
library = json.loads((root.parent.parent / 'assets/legal/publication_library.json').read_text())
assert len(library) == len(DOCS) == 23
assert len({doc['id'] for doc in library}) == 23
for (filename, spec), entry in zip(DOCS, library):
    assert entry['id'] == spec['id']
    assert entry['sections'] == [{'title': heading, 'body': body} for heading, body in spec['sections']]
    word = Document(root / filename)
    text = '\n'.join(p.text for p in word.paragraphs)
    markdown = (root / 'readable' / (entry['id'] + '.md')).read_text()
    for heading, body in spec['sections']:
        assert body in text, (filename, heading)
        assert body in markdown, (filename, heading)
    assert not re.search(r'\[[A-Z_]+\]|Policy draft|Pending publication approval', text)
    assert entry['status'] != 'Policy draft'
print('23 Word documents, Markdown files and app entries verified; no publication placeholders.')
