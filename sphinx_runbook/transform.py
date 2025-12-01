"""Whole-document transform: wrap the body in the standard runbook structure."""

from docutils import nodes
from docutils.transforms import Transform

CROSS_FORMAT_LABELS = {
    "confluence": "Confluence",
    "html": "HTML",
    "pdf": "PDF",
    "source": "Source",
}


class RunbookDocumentTransform(Transform):
    """Build the standard page structure from validated front matter."""

    default_priority = 840

    def apply(self):
        env = self.document.settings.env
        metadata = env.runbook_metadata.get(env.docname)
        if metadata is None:
            return

        document = self.document

        # The structure below is built exclusively from validated front
        # matter; drop any title/docinfo the parser produced itself.
        for child in list(document.children):
            if isinstance(child, (nodes.title, nodes.docinfo)):
                document.remove(child)

        prefix = env.config.runbook_title_prefix
        children = [
            nodes.title("", "", nodes.Text(f"{prefix}{metadata['title']}")),
            self._metadata(metadata),
            self._cross_format_links(env.config.runbook_cross_format_links),
        ]
        document[:] = children + list(document.children)

    @staticmethod
    def _metadata(metadata):
        container = nodes.container(classes=["runbook-metadata"])
        fields = nodes.definition_list()
        for name in ("id", "type", "service", "owner", "severity"):
            value = metadata.get(name)
            if value is None:
                continue
            item = nodes.definition_list_item()
            item += nodes.term("", "", nodes.Text(name))
            item += nodes.definition("", nodes.paragraph("", "", nodes.Text(str(value))))
            fields += item
        container += fields
        return container

    @staticmethod
    def _cross_format_links(links):
        container = nodes.container(classes=["runbook-cross-format-links"])
        paragraph = nodes.paragraph()
        for name, label in CROSS_FORMAT_LABELS.items():
            target = links.get(name)
            if target is None:
                continue
            if len(paragraph.children):
                paragraph += nodes.Text(" · ")
            paragraph += nodes.reference("", label, refuri=target)
        container += paragraph
        return container
