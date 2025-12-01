"""Sphinx extension: define runbook semantics once, render per target.

This slice implements the minimum that exercises the pattern: one semantic
node (``runbook_image``), one directive (``runbook-image``), source
validation, and the whole-document transform.
"""

import os

from sphinx_runbook.directive import RunbookImageDirective
from sphinx_runbook.nodes import (
    confluence_depart_runbook_image,
    confluence_visit_runbook_image,
    html_depart_runbook_image,
    html_visit_runbook_image,
    runbook_image,
)
from sphinx_runbook.transform import RunbookDocumentTransform
from sphinx_runbook.validate import (
    RunbookValidationError,
    validate_attachments,
    validate_source,
)

__version__ = "0.1.0"

DEFAULT_CROSS_FORMAT_LINKS = {
    "confluence": "",
    "html": "",
    "pdf": "",
    "source": "",
}


def _validate_source(app, env, docnames):
    source_path = app.config.runbook_source_path
    if not source_path:
        raise RunbookValidationError(
            "runbook_source_path is not configured; set it to the runbook source file"
        )
    if not os.path.isfile(source_path):
        raise RunbookValidationError(f"runbook source not found: {source_path}")
    env.runbook_metadata = {app.config.root_doc: validate_source(source_path)}


def _validate_attachments(app, doctree, docname):
    source_path = app.config.runbook_source_path
    attachment_root = app.config.runbook_attachment_root
    if not attachment_root and source_path:
        attachment_root = os.path.dirname(source_path)
    if attachment_root:
        validate_attachments(doctree, source_path, attachment_root)


def setup(app):
    app.add_config_value("runbook_source_path", None, "env", types=[str, type(None)])
    app.add_config_value(
        "runbook_attachment_root", None, "env", types=[str, type(None)]
    )
    app.add_config_value("runbook_title_prefix", "Runbook: ", "env", types=[str])
    app.add_config_value(
        "runbook_cross_format_links", DEFAULT_CROSS_FORMAT_LINKS, "env", types=[dict]
    )

    app.add_node(
        runbook_image,
        html=(html_visit_runbook_image, html_depart_runbook_image),
        confluence=(confluence_visit_runbook_image, confluence_depart_runbook_image),
    )
    app.add_directive("runbook-image", RunbookImageDirective)
    app.add_transform(RunbookDocumentTransform)

    app.connect("env-before-read-docs", _validate_source)
    app.connect("doctree-resolved", _validate_attachments)

    return {
        "version": __version__,
        "parallel_read_safe": True,
        "parallel_write_safe": True,
    }
