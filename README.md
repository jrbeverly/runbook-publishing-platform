# Runbook Publishing Platform

> [!WARNING]
> **AI-authored:** This change was autonomously planned and implemented by an AI software factory from a human-authored specification, with possible subsequent human review or modification.

Pinned Docker image carrying Sphinx, Playwright, and Chromium; `make run` discovers `*.runbook.md` files and, from one source, produces Confluence storage format, HTML, PDF, and a manifest. `action.yml` wraps the same pinned image and entrypoint as a Docker-based GitHub Action (`docker://runbook-publisher:0.1.0`).

## Notes

- Supporting a lightweight approach for publishing runbook details
- Goal: Publish text in repository, then into predefined page template
