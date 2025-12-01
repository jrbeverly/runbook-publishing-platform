"""Source validation: front-matter schema and attachment existence."""

import os
import re

import yaml
from sphinx.errors import SphinxError

from sphinx_runbook.nodes import runbook_image

REQUIRED_FIELDS = ("id", "title", "type", "service", "owner")
ID_PATTERN = re.compile(r"^[a-z0-9-]+$")
RESERVED_TITLE_PREFIX = "runbook:"


class RunbookValidationError(SphinxError):
    """A runbook source violates the schema; fail the build."""

    category = "Runbook validation error"


def parse_front_matter(source_path):
    with open(source_path, encoding="utf-8") as handle:
        lines = handle.readlines()

    if not lines or lines[0].strip() != "---":
        raise RunbookValidationError(
            f"{source_path}: front matter is required (file must begin with '---')"
        )

    end = None
    for index in range(1, len(lines)):
        if lines[index].strip() == "---":
            end = index
            break
    if end is None:
        raise RunbookValidationError(
            f"{source_path}: front matter is not terminated (missing closing '---')"
        )

    try:
        metadata = yaml.safe_load("".join(lines[1:end]))
    except yaml.YAMLError as error:
        raise RunbookValidationError(
            f"{source_path}: front matter is not valid YAML: {error}"
        ) from error

    if not isinstance(metadata, dict):
        raise RunbookValidationError(f"{source_path}: front matter must be a YAML mapping")
    return metadata


def validate_front_matter(source_path, metadata):
    problems = []

    for field in REQUIRED_FIELDS:
        if not metadata.get(field):
            problems.append(f"missing required front-matter field '{field}'")

    runbook_id = metadata.get("id")
    if runbook_id and (
        not isinstance(runbook_id, str) or not ID_PATTERN.match(runbook_id)
    ):
        problems.append(f"id {runbook_id!r} must match [a-z0-9-]+")

    title = metadata.get("title")
    if isinstance(title, str) and title.strip().lower().startswith(RESERVED_TITLE_PREFIX):
        problems.append(
            f"title must not supply the reserved '{RESERVED_TITLE_PREFIX}' prefix"
        )

    if problems:
        raise RunbookValidationError(f"{source_path}: " + "; ".join(problems))


def validate_source(source_path):
    metadata = parse_front_matter(source_path)
    validate_front_matter(source_path, metadata)
    return metadata


def validate_attachments(doctree, source_path, attachment_root):
    missing = []
    for node in doctree.findall(runbook_image):
        path = node["path"]
        if not os.path.isfile(os.path.join(attachment_root, path)):
            missing.append(path)
    if missing:
        raise RunbookValidationError(
            f"{source_path}: referenced attachment(s) not found: {', '.join(missing)}"
        )
