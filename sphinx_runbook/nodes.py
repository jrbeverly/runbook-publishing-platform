"""Semantic nodes for runbook documents, rendered per target by visitors."""

from html import escape

from docutils import nodes


class runbook_image(nodes.General, nodes.Element):
    """An image attachment referenced by a runbook.

    Holds structured data (``path``, ``alt``, ``caption``), not target markup.
    """

    tagname = "runbook_image"


def html_visit_runbook_image(self, node):
    # Stub: attachment staging and URL rewriting arrive with the isolated
    # Sphinx project generator; render the reference path as-is.
    self.body.append('<figure class="runbook-image">')
    self.body.append(
        f'<img src="{escape(node["path"])}" alt="{escape(node["alt"])}" />'
    )
    if node["caption"]:
        self.body.append(f"<figcaption>{escape(node['caption'])}</figcaption>")
    self.body.append("</figure>")
    raise nodes.SkipNode


def html_depart_runbook_image(self, node):
    pass


def confluence_visit_runbook_image(self, node):
    # Stub: native attachment-backed macros are deferred until the target
    # Confluence macro set is confirmed; emit a placeholder naming the file.
    self.body.append(
        '<ac:structured-macro ac:name="info">'
        "<ac:rich-text-body>"
        f"<p>Image attachment: {escape(node['path'])}</p>"
        "</ac:rich-text-body>"
        "</ac:structured-macro>"
    )
    raise nodes.SkipNode


def confluence_depart_runbook_image(self, node):
    pass
