# Runbook Publishing Platform — Vision and Design

**Status:** Proposed  
**Document:** `vision.md`  
**Primary source of truth:** Git-hosted Markdown runbooks  
**Primary publishing engine:** Sphinx with `sphinxcontrib-confluencebuilder`  
**Execution model:** Pre-built Docker-based GitHub Action, processing each runbook independently

---

## 1. Executive summary

This project will provide a low-code, reproducible publishing platform for operational runbooks.

Authors will maintain each runbook as Markdown in Git. A runbook may contain:

- YAML front matter for metadata and publishing controls;
- normal Markdown content;
- images, screenshots, diagrams, downloadable files, and other attachments;
- custom runbook directives or roles that describe domain-specific concepts;
- references to shared JSON or YAML data sources;
- predictable identifiers used to derive stable publication paths.

A pre-built Docker image will contain Sphinx, the Confluence builder, the custom runbook extension, the HTML theme, Playwright, validation logic, and the entrypoint scripts. A reusable GitHub Action will run that image against a repository.

The action will discover all files matching the runbook naming convention, such as:

```text
**/*.runbook.md
```

Each runbook will be processed independently. For every valid runbook, the system will:

1. validate its filename, front matter, metadata, directives, and attachments;
2. create an isolated temporary Sphinx project;
3. build and publish a native Confluence page;
4. build a customized HTML representation;
5. render the HTML to PDF using Playwright;
6. optionally create normalized Markdown or other downstream representations;
7. publish or stage the resulting artifacts for external distribution;
8. produce a machine-readable manifest describing every generated location.

The expected outputs for each runbook are therefore:

- the original Markdown source in Git;
- a native Confluence page;
- a static HTML page;
- a PDF artifact;
- optionally, a normalized Markdown variant for MkDocs, Backstage, or another documentation system;
- a manifest containing stable identifiers, versions, hashes, and URLs for all representations.

Confluence is a publication target, not the canonical source. Git remains authoritative.

---

## 2. Vision

The platform should make an operational runbook available wherever an operator may need it without requiring authors to maintain multiple copies.

A runbook should be:

- easy to author;
- easy to review through normal Git workflows;
- richly rendered in Confluence;
- available as static HTML when Confluence is unavailable;
- available as a portable PDF;
- suitable for future ingestion into Backstage, MkDocs, search indexes, archives, or other systems;
- linked predictably across all representations;
- published consistently using organization-defined conventions;
- independently buildable and publishable;
- reproducible from a pinned container image.

The system should maximize redundancy without creating multiple sources of truth.

---

## 3. Guiding principles

### 3.1 Git is authoritative

All editable content, metadata, attachment sources, custom extension code, templates, styles, and configuration will be version controlled.

Generated Confluence content, HTML, and PDFs are derived outputs.

Edits made directly in Confluence are not authoritative and may be overwritten by the next publication.

### 3.2 Use Sphinx as the document compiler

Sphinx will provide the common document model, extension mechanism, build lifecycle, dependency handling, and builder abstraction.

The project will not assemble complete Confluence Storage Format XML with shell scripts or a second general-purpose templating engine.

### 3.3 Delegate Confluence lifecycle management

`sphinxcontrib-confluencebuilder` will own the Confluence-specific publication concerns it already supports, including page publication and asset handling.

The custom project will concentrate on runbook semantics, policy, rendering conventions, and orchestration rather than recreating a Confluence client.

The builder currently supports publishing assets through Confluence attachments and uses attachment hash metadata to avoid unnecessary re-publication. It also supports global labels and other publication configuration. See the [Sphinx Confluence Builder configuration documentation](https://sphinxcontrib-confluencebuilder.readthedocs.io/en/stable/configuration/).

### 3.4 Define semantics once, render per target

Custom directives will represent concepts such as:

- runbook metadata;
- summary;
- owner;
- service;
- severity;
- escalation information;
- dashboards;
- logs;
- repositories;
- related runbooks;
- dependencies;
- recovery objectives;
- warnings;
- validation commands;
- evidence or screenshots.

A directive will create semantic Sphinx/docutils nodes. Target-specific visitors will render those nodes differently for Confluence and HTML.

This avoids making Confluence macros the internal data model.

### 3.5 Prefer convention over per-runbook configuration

Most behaviour should be supplied by defaults and organizational policy.

Runbook authors should not need to understand Confluence Storage Format, Sphinx internals, HTML templates, Playwright, attachment APIs, or publishing credentials.

### 3.6 Isolate publication per runbook

Each runbook will be built in its own temporary Sphinx project and publication invocation.

This limits the blast radius of malformed content, makes logs easier to interpret, permits targeted retries, and avoids one failing runbook preventing unrelated runbooks from being published.

### 3.7 Build every output from the same source

HTML and PDF must be built directly from the same Markdown, metadata, attachments, and semantic nodes as the Confluence page.

The platform will not normally publish to Confluence and then scrape or export Confluence to generate the other formats.

---

## 4. Goals

The first production version should:

1. discover runbook files recursively;
2. validate a mandatory front matter schema;
3. assign or validate a stable runbook identifier;
4. support local and shared attachments;
5. support custom runbook directives;
6. publish native Confluence pages;
7. apply page naming, labels, hierarchy, and metadata conventions;
8. generate customized static HTML;
9. generate PDF from HTML using Playwright;
10. emit a publication manifest;
11. support selective publication of changed runbooks;
12. run through a reusable Docker-based GitHub Action;
13. use a pre-built and version-pinned container image;
14. make local execution use the same image and entrypoint as CI;
15. retain useful intermediate outputs for diagnostics.

---

## 5. Non-goals

The initial implementation will not:

- make Confluence the source of truth;
- provide bidirectional synchronization between Git and Confluence;
- preserve arbitrary direct edits made in Confluence;
- implement a new Markdown parser;
- implement a new Confluence REST client unless a missing capability cannot reasonably be supplied by the builder;
- reproduce Confluence’s visual presentation exactly in HTML;
- use LaTeX as the primary PDF path;
- create one monolithic Sphinx site and publish all runbooks as a single transaction;
- require authors to write raw Confluence Storage Format XML;
- require authors to manually upload or version attachments;
- guarantee support for every third-party Confluence macro;
- distribute generated HTML and PDFs to every possible destination in the core builder.

Distribution integrations should remain replaceable deployment adapters.

---

## 6. Repository conventions

A recommended repository layout is:

```text
.
├── .github/
│   └── workflows/
│       └── publish-runbooks.yml
├── runbooks/
│   ├── aws/
│   │   ├── s3-upload-error.runbook.md
│   │   └── s3-upload-error.assets/
│   │       ├── architecture.png
│   │       ├── failure-example.png
│   │       └── sample-policy.json
│   └── payments/
│       ├── payment-timeout.runbook.md
│       └── payment-timeout.assets/
│           └── sequence.svg
├── runbook-data/
│   ├── shared-links.yaml
│   ├── teams.yaml
│   └── environments.json
└── runbook-publishing.yaml
```

A colocated directory layout may also be supported:

```text
runbooks/aws/s3-upload-error/
├── index.runbook.md
├── architecture.png
├── failure-example.png
└── sample-policy.json
```

The implementation should select one canonical convention and optionally support the second through configuration.

The default discovery pattern should be:

```text
**/*.runbook.md
```

Files should be processed in deterministic lexical order.

---

## 7. Runbook source format

### 7.1 Example

```markdown
---
id: aws-s3-upload-error
title: S3 upload error
type: operational-runbook
service: object-storage
owner: platform-storage
severity: high
confluence:
  space: OPS
  parent: AWS Runbooks
labels:
  - aws
  - s3
  - upload
links:
  dashboard: s3-upload-dashboard
  repository: storage-gateway
---

# Symptoms

Operators may see repeated upload failures and elevated error rates.

```{runbook-warning}
Do not retry indefinitely when requests return authorization errors.
```

# Diagnosis

1. Confirm the affected account and region.
2. Review the attached error screenshot.
3. Inspect the configured bucket policy.

```{runbook-image} s3-upload-error.assets/failure-example.png
:alt: Example upload failure
:caption: Typical authorization failure shown in the operator console
```

# Recovery

Follow the approved recovery sequence.
```

### 7.2 Front matter

Front matter is mandatory.

The extension or entrypoint may parse it using an existing parser rather than custom shell delimiter handling because the metadata must become structured Sphinx state. The authoring convention remains simple regardless of the parser implementation.

The schema should include:

#### Required fields

```yaml
id: aws-s3-upload-error
title: S3 upload error
type: operational-runbook
service: object-storage
owner: platform-storage
```

#### Optional fields

```yaml
description: Short summary
severity: high
lifecycle: active
review_date: 2026-10-01
labels: []
aliases: []
tags: []
links: {}
confluence: {}
html: {}
pdf: {}
```

### 7.3 Stable identifier

`id` is the canonical identity of the runbook.

Requirements:

- unique within the configured publication namespace;
- immutable after first publication except through an explicit migration;
- lowercase;
- restricted to an agreed character set such as `[a-z0-9-]+`;
- independent of the page title;
- used to derive artifact names, URL paths, cache keys, and manifest records.

A generated identifier may be offered as a bootstrap convenience, but committed runbooks should contain the identifier explicitly. Silent regeneration would undermine stability.

### 7.4 Title convention

The source title should remain human-readable:

```yaml
title: S3 upload error
```

The target title may be derived:

```text
Runbook: S3 upload error
```

The extension or builder configuration should enforce the prefix rather than requiring authors to write it.

Validation should fail when a source tries to supply the reserved prefix itself, unless an explicit override policy permits it.

### 7.5 Labels

Labels should be assembled from:

- global labels;
- runbook type;
- lifecycle;
- service;
- owner;
- source-provided labels;
- optional environment or business-domain metadata.

Example result:

```text
runbook
managed-by-git
operational-runbook
service-object-storage
owner-platform-storage
aws
s3
upload
```

The exact Confluence label character restrictions must be normalized centrally.

---

## 8. Custom Sphinx extension

The core custom component will be a normal installable Sphinx extension, tentatively named:

```text
sphinx_runbook
```

It should be packaged independently of the GitHub Action so it can be tested, versioned, and used locally.

### 8.1 Responsibilities

The extension will:

- load and validate runbook front matter;
- load referenced YAML and JSON data;
- resolve shared links and organizational metadata;
- register custom directives and roles;
- create semantic docutils nodes;
- transform the document into the standard runbook structure;
- enforce title and metadata conventions;
- provide builder-specific rendering;
- inject page-level metadata for Confluence;
- inject template context for HTML;
- collect artifact and publication metadata;
- fail builds on policy violations.

Sphinx supports extensions through a `setup()` function and permits extensions to register directives, nodes, configuration values, transforms, and build event handlers. See the [Sphinx application API](https://www.sphinx-doc.org/en/master/extdev/appapi.html).

### 8.2 Semantic nodes

Suggested custom nodes include:

```text
runbook_page
runbook_summary
runbook_metadata
runbook_link_group
runbook_contact
runbook_status
runbook_warning
runbook_evidence
runbook_cross_format_links
```

These nodes should contain structured data rather than target markup.

For example:

```python
runbook_link_group(
    name="Operational links",
    links=[
        {"label": "Dashboard", "url": "..."},
        {"label": "Repository", "url": "..."},
    ],
)
```

### 8.3 Whole-document transform

A custom document transform should be preferred over requiring a directive to wrap the remainder of the file.

The transform can:

1. read the page metadata;
2. identify the normal body nodes;
3. construct a `runbook_page` root structure;
4. move the original body into the content region;
5. add summary, metadata, standard links, warnings, and cross-format navigation;
6. leave each builder to render that structure.

This more naturally enforces a page-wide layout.

### 8.4 Custom directives

Directives should be reserved for concepts authors need to place at specific positions.

Possible directives:

```text
runbook-warning
runbook-note
runbook-image
runbook-download
runbook-steps
runbook-validation
runbook-evidence
runbook-links
runbook-related
```

Directives should avoid exposing target-specific names such as `confluence-excerpt`.

### 8.5 External data

The extension should support one or more configured data roots:

```python
runbook_data_paths = [
    "runbook-data",
]
```

Data files may provide:

- link definitions;
- dashboard URLs;
- repositories;
- team contacts;
- service ownership;
- escalation targets;
- environment details;
- standardized legal or operational notices;
- navigation destinations;
- alternate output base URLs.

Example:

```yaml
links:
  s3-upload-dashboard:
    label: S3 Upload Dashboard
    url: https://observability.example/runbooks/s3-upload
  storage-gateway:
    label: Storage Gateway Repository
    url: https://git.example/platform/storage-gateway
```

Runbooks should reference keys rather than duplicate long URLs:

```yaml
links:
  dashboard: s3-upload-dashboard
  repository: storage-gateway
```

The validator should reject missing keys.

---

## 9. Confluence rendering and publishing

### 9.1 Builder

The project will use `sphinxcontrib-confluencebuilder`, which provides a Confluence-compatible builder and optional publication to Confluence. The package describes itself as a Sphinx extension that builds Confluence-compatible markup and can publish it to a Confluence instance. See the [project page](https://pypi.org/project/sphinxcontrib-confluencebuilder/).

### 9.2 Native Confluence presentation

The Confluence visitor for custom semantic nodes may emit native Confluence structures such as:

- layouts and columns;
- panels;
- status macros;
- excerpts;
- tables;
- page properties;
- links;
- attachment-backed images;
- attachment-backed downloads;
- navigation or related-content sections.

The exact macro set must be verified against the target Confluence edition and editor.

Raw Confluence Storage Format should remain isolated inside the Confluence visitor implementation. It should not appear in runbook Markdown.

### 9.3 Page-level conventions

The extension and builder configuration should enforce:

- title prefix;
- target space;
- parent page or publication root;
- global labels;
- per-page labels;
- ownership metadata;
- standard page footer;
- generated-source warning;
- source repository link;
- HTML and PDF links;
- stable identity metadata where supported.

The Confluence builder configuration supports global labels and attachment publication. Builder-specific page metadata may also be extracted during document processing; its source includes metadata extraction before writing. See the [builder source](https://github.com/sphinx-contrib/confluencebuilder/blob/master/sphinxcontrib/confluencebuilder/builder.py).

### 9.4 Attachments

Attachments should be referenced naturally from Markdown or custom directives.

The builder will be responsible for publishing images and downloadable assets through Confluence attachments. Its configuration documentation states that assets can be published as attachments and that hash values are used to avoid unnecessary re-publication.

The extension should add validation around this behaviour:

- referenced files must exist;
- filenames must be safe and deterministic;
- duplicate target filenames within one page must be rejected;
- unsupported file types should fail or warn according to policy;
- maximum size limits should be configurable;
- remote assets should normally be downloaded and pinned before publication rather than hot-linked.

### 9.5 Per-runbook publication

Each runbook invocation should generate an isolated Sphinx source tree containing one publishable document.

A conceptual temporary project is:

```text
/tmp/runbook-build/aws-s3-upload-error/
├── conf.py
├── index.md
├── _static/
├── assets/
└── generated/
```

The Confluence builder is then invoked only for that project.

This satisfies the desired isolation but introduces an important design requirement: identity, page hierarchy, and builder state must remain stable across isolated invocations.

### 9.6 Identity test

Before production rollout, a proof of concept must confirm how the Confluence builder resolves an existing page after:

- the page title changes;
- the source path changes;
- the parent page changes;
- the runbook is published in a separate Sphinx invocation;
- the same runbook identifier is published to another space.

If the builder relies only on title and hierarchy, the project must use its supported metadata or configuration mechanisms to preserve stable identity, or add the smallest possible pre-publication mapping layer.

This is a bounded integration risk, not a reason to replace the publisher.

### 9.7 Direct edits in Confluence

Published pages should display a generated-content notice:

```text
This page is generated from Git. Direct edits may be overwritten.
```

The operational policy should define whether direct edits are forbidden, discouraged, or allowed only in designated unmanaged regions.

The first implementation should not attempt content-region merging.

---

## 10. HTML rendering

### 10.1 Builder

Each isolated Sphinx project will also be built with the HTML builder.

Sphinx HTML output is customizable through themes, Jinja templates, static assets, CSS, JavaScript, and extension-provided page context. Single HTML inherits HTML configuration where applicable. See the [Sphinx configuration documentation](https://www.sphinx-doc.org/en/master/usage/configuration.html).

### 10.2 Desired layout

The HTML output should preserve the same information architecture as Confluence without attempting pixel-level equivalence.

Suggested desktop layout:

```text
┌──────────────────────────────────────────────────────────┐
│ Runbook title, summary, status, service                  │
├────────────────────────────────┬─────────────────────────┤
│ Main runbook body              │ Metadata                │
│                                │ Operational links       │
│ Symptoms                       │ Contacts                │
│ Diagnosis                      │ Related runbooks        │
│ Recovery                       │ Alternate formats       │
│ Validation                     │ Source/version          │
├────────────────────────────────┴─────────────────────────┤
│ Generated-content notice and publication metadata       │
└──────────────────────────────────────────────────────────┘
```

The sidebar should collapse below the main content for narrow screens.

### 10.3 Theme

The project should provide a dedicated Sphinx theme or theme override package rather than ad hoc generated HTML.

It should include:

- accessible semantic HTML;
- print styles;
- responsive layout;
- code block styles;
- callouts;
- attachment presentation;
- stable anchors;
- link styling;
- organizational branding where required;
- no dependence on remote JavaScript for core readability.

### 10.4 Data injection

Shared YAML and JSON data should be resolved by the extension into semantic nodes or injected into the HTML template context.

The final HTML builder should not fetch critical metadata dynamically at page load. Static generation makes the output portable and archive-friendly.

### 10.5 Static publication

HTML output should use a predictable path:

```text
/runbooks/<runbook-id>/index.html
```

Static assets should live under predictable content-addressed or versioned paths.

A CloudFront-backed S3 site is a suitable deployment target, but the core builder should only produce the artifact tree and manifest. Upload and invalidation should be separate deployment stages.

---

## 11. PDF generation

### 11.1 Approach

The project will not use LaTeX as its primary PDF path.

The PDF will be rendered from the customized HTML using Playwright and a pinned browser version contained in the Docker image.

Conceptual command:

```bash
node render-pdf.mjs \
  --input "/output/html/aws-s3-upload-error/index.html" \
  --output "/output/pdf/aws-s3-upload-error.pdf"
```

### 11.2 PDF-specific requirements

The HTML theme must include print CSS for:

- page size and margins;
- page breaks;
- repeating or non-repeating headers;
- hiding interactive navigation;
- expanding collapsible sections;
- avoiding split tables and callout boxes where possible;
- printing link destinations when useful;
- preserving code formatting;
- resolving local assets without network access.

### 11.3 Determinism

PDF generation should run in a controlled environment:

- pinned container image;
- pinned Playwright and browser versions;
- fixed locale and timezone;
- no animation;
- network disabled after local assets are prepared, where practical;
- deterministic generated timestamps or explicit build metadata;
- fonts included through permitted package dependencies, not dynamically downloaded.

### 11.4 Output path

```text
/runbooks/<runbook-id>/<runbook-id>.pdf
```

The HTML page should link to the PDF, and the Confluence page should link to the same predictable external URL.

---

## 12. Optional normalized Markdown output

A future builder or post-transform may emit a portable Markdown representation for:

- MkDocs;
- Backstage TechDocs;
- GitHub browsing;
- offline text consumption;
- indexing systems.

This output should be derived from the semantic document model or source plus resolved metadata.

It should not attempt to preserve Confluence-only macros. Instead, it should convert them to portable constructs such as headings, tables, callouts, and links.

Example path:

```text
/runbooks/<runbook-id>/<runbook-id>.md
```

This is an optional capability and should not delay the core Confluence, HTML, and PDF flow.

---

## 13. Cross-format linking

Each output should expose links to the others.

For a runbook with ID `aws-s3-upload-error`, configured bases might be:

```yaml
publication_bases:
  html: https://runbooks.example/runbooks
  pdf: https://runbooks.example/runbooks
  source: https://github.example/platform/runbooks/blob/main
  confluence: https://example.atlassian.net/wiki
```

The generated representations may include:

- View in Confluence
- View as HTML
- Download PDF
- View source
- View normalized Markdown

### 13.1 Manifest

The pipeline should emit a record similar to:

```json
{
  "schemaVersion": 1,
  "id": "aws-s3-upload-error",
  "title": "S3 upload error",
  "source": {
    "path": "runbooks/aws/s3-upload-error.runbook.md",
    "commit": "0123456789abcdef"
  },
  "outputs": {
    "confluence": {
      "space": "OPS",
      "pageId": "123456789",
      "url": "https://example.atlassian.net/wiki/spaces/OPS/pages/123456789"
    },
    "html": {
      "path": "runbooks/aws-s3-upload-error/index.html",
      "url": "https://runbooks.example/runbooks/aws-s3-upload-error/"
    },
    "pdf": {
      "path": "runbooks/aws-s3-upload-error/aws-s3-upload-error.pdf",
      "url": "https://runbooks.example/runbooks/aws-s3-upload-error/aws-s3-upload-error.pdf"
    }
  },
  "hashes": {
    "source": "sha256:...",
    "html": "sha256:...",
    "pdf": "sha256:..."
  }
}
```

A repository-level index should aggregate all records:

```text
output/manifest.json
```

This manifest becomes the stable interface for deployment jobs, dashboards, indexes, link checkers, and future integrations.

---

## 14. Container and GitHub Action design

### 14.1 Pre-built image

The action will use a versioned pre-built image from a trusted registry.

Example:

```text
ghcr.io/example/runbook-publisher:1.0.0
```

The image should contain:

- Python;
- pinned Sphinx;
- pinned MyST parser if Markdown is authored through MyST;
- pinned `sphinxcontrib-confluencebuilder`;
- the custom `sphinx_runbook` extension;
- the custom HTML theme;
- Node.js;
- Playwright;
- a pinned Chromium build;
- YAML and JSON validation tooling;
- shell entrypoint;
- optional AWS and Azure upload CLIs only when kept in a separate deployment image or clearly justified.

GitHub documents Docker container actions as packaged actions with an action metadata file, Dockerfile/image, and entrypoint. See [Creating a Docker container action](https://docs.github.com/actions/sharing-automations/creating-actions/creating-a-docker-container-action).

### 14.2 Reproducibility

The image should:

- pin all direct dependencies;
- record transitive dependency locks;
- use a digest-pinned base image;
- publish an SBOM;
- be scanned before release;
- be signed where the registry supports it;
- expose its version in generated manifests;
- avoid installing packages at action runtime.

### 14.3 Action metadata

Conceptual `action.yml`:

```yaml
name: Publish operational runbooks
description: Build and publish runbooks to Confluence, HTML, and PDF
runs:
  using: docker
  image: docker://ghcr.io/example/runbook-publisher:1.0.0
inputs:
  root:
    description: Repository path to scan
    default: .
  pattern:
    description: Runbook glob
    default: "**/*.runbook.md"
  config:
    description: Publishing configuration path
    default: runbook-publishing.yaml
  changed-only:
    description: Build only changed runbooks
    default: "false"
```

Secrets should be supplied through environment variables or action inputs mapped to environment variables, not committed configuration.

### 14.4 Entrypoint

Conceptual flow:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

load_config
validate_environment
discover_runbooks

for runbook in "${runbooks[@]}"; do
    process_runbook "$runbook"
done

write_aggregate_manifest
write_github_summary
```

`process_runbook` should:

```text
validate source
prepare isolated Sphinx project
build Confluence representation
publish Confluence page and attachments
build HTML
render PDF
build optional portable Markdown
write per-runbook manifest
stage deployment artifacts
```

### 14.5 Failure policy

Supported policies should include:

- `fail-fast`: stop at the first failed runbook;
- `continue`: process all runbooks and fail at the end if any failed;
- `report-only`: useful for validation or migration.

The default should likely be `continue`, with a non-zero final exit status, so independent runbooks still produce results while CI remains honest.

### 14.6 Logs

Every log line should include the runbook ID:

```text
[aws-s3-upload-error] validating metadata
[aws-s3-upload-error] publishing Confluence page
[aws-s3-upload-error] building HTML
[aws-s3-upload-error] rendering PDF
```

A structured JSON log mode should be available for large-scale use.

---

## 15. Isolated Sphinx project generation

The system will not require every runbook directory to be a hand-authored Sphinx project.

The entrypoint will synthesize a minimal project for each runbook.

### 15.1 Generated `conf.py`

The generated configuration should import a shared, versioned configuration module:

```python
from runbook_publisher.defaults import *

runbook_source_path = "/workspace/runbooks/aws/s3-upload-error.runbook.md"
runbook_data_paths = ["/workspace/runbook-data"]
runbook_publication_config = "/workspace/runbook-publishing.yaml"
```

Credentials should be provided through environment variables and read by the builder configuration without being written to build artifacts.

### 15.2 Generated source

The original Markdown may be copied, symlinked, or transformed into `index.md`.

A preprocessing stage may:

- preserve line-number mappings;
- normalize front matter;
- insert generated metadata nodes;
- rewrite relative attachment paths into the isolated tree;
- create an index wrapper when needed.

### 15.3 Clean environments

Use a distinct:

- source directory;
- doctree directory;
- output directory;
- attachment staging directory;
- log file;
- manifest file

for each runbook.

This avoids state collisions between isolated builds.

---

## 16. Validation and policy enforcement

Validation should happen before publication.

### 16.1 Source validation

Check:

- filename matches the configured pattern;
- front matter exists;
- YAML is valid;
- required fields exist;
- identifier syntax is valid;
- identifier is unique;
- title follows policy;
- runbook type is permitted;
- referenced data keys exist;
- local links resolve;
- attachment files exist;
- directive syntax is valid;
- unsupported raw HTML or raw Confluence XML is rejected unless explicitly permitted.

### 16.2 Organizational validation

Check:

- owner exists in the organization data source;
- service is recognized;
- required links are present for the runbook type;
- review date is valid;
- lifecycle and severity values come from controlled vocabularies;
- required sections exist;
- restricted labels are not supplied by authors.

### 16.3 Output validation

Before publishing:

- build the Sphinx doctree;
- treat warnings as errors in strict mode;
- validate generated links;
- inspect generated Confluence markup where possible;
- confirm HTML output exists;
- run a local HTTP load test or browser smoke test;
- confirm PDF is generated and non-empty;
- generate hashes.

### 16.4 Publication validation

After publishing:

- capture the Confluence page ID and URL;
- confirm expected attachments were accepted;
- verify the page is reachable through the builder response or a lightweight follow-up;
- write the result to the manifest.

---

## 17. Incremental and selective builds

Although runbooks are processed independently, the action should avoid rebuilding everything unnecessarily.

### 17.1 Changed-runbook detection

A runbook is affected when any of these change:

- the Markdown file;
- a referenced attachment;
- a referenced shared data record;
- the custom extension version;
- the HTML theme version;
- the publication configuration;
- the container image version.

The first implementation may conservatively rebuild all runbooks when shared code or shared data changes.

### 17.2 Content hashing

Calculate a build input hash from:

```text
runbook source
resolved front matter
referenced attachments
resolved shared data
extension version
theme version
builder versions
publication configuration
```

Store the value in the manifest or CI cache.

### 17.3 Explicit selection

The entrypoint should support:

```bash
runbook-publish --id aws-s3-upload-error
runbook-publish --path runbooks/aws/s3-upload-error.runbook.md
runbook-publish --changed-since <git-ref>
```

This assists development, retries, and emergency publication.

---

## 18. Deployment adapters

The core action should distinguish building from distributing.

### 18.1 Core outputs

The core builder produces:

```text
output/
├── html/
├── pdf/
├── markdown/
├── manifests/
└── manifest.json
```

Confluence publication occurs during the build because it is handled by the builder and is not simply a file copy.

### 18.2 Static HTML and PDF distribution

Separate workflow steps or reusable adapters may:

- sync HTML and PDFs to S3;
- invalidate CloudFront paths;
- upload PDFs to SharePoint;
- archive artifacts in GitHub Actions;
- publish a release bundle;
- copy artifacts to Azure Blob Storage;
- register runbooks in Backstage.

These destinations should consume the manifest rather than rediscover outputs.

### 18.3 Idempotence

Deployment adapters should use hashes, ETags, or object metadata to avoid unnecessary uploads.

---

## 19. Security

### 19.1 Credentials

Confluence, AWS, Azure, and other credentials must be injected at runtime through GitHub Actions secrets or workload identity.

Prefer short-lived identity mechanisms where supported.

### 19.2 Untrusted content

Markdown is executable only in a broad sense, but documentation builds can still expose risk through:

- raw HTML;
- template injection;
- shell directives;
- extension loading;
- remote includes;
- malicious SVG;
- browser access during PDF rendering.

The platform should:

- disable arbitrary extension loading from runbook repositories;
- disable or restrict raw directives;
- disallow arbitrary Jinja templates supplied by runbooks;
- sanitize or reject unsafe SVG according to policy;
- prevent arbitrary file reads outside configured roots;
- disable external network access during rendering where practical;
- run as a non-root container user;
- use a read-only source mount where practical;
- write only to designated output and temporary paths.

### 19.3 Generated links

External URLs loaded from shared data should be validated against permitted schemes.

Secrets must never be embedded in generated pages, HTML, manifests, or PDFs.

---

## 20. Observability

The action should produce:

- per-runbook status;
- per-target status;
- elapsed build time;
- attachment count;
- output sizes;
- warning count;
- publication URL;
- source commit;
- image/toolchain version;
- failure classification.

A GitHub Actions job summary should show:

| Runbook | Confluence | HTML | PDF | Status |
|---|---|---|---|---|
| S3 upload error | Published | Built | Built | Success |
| Payment timeout | Failed | Built | Built | Failed |

Machine-readable results should be retained even when the overall job fails.

---

## 21. Approaches considered and ruled out

### 21.1 Direct Markdown-to-Confluence CLI as the full solution

Tools that convert and publish Markdown are useful, but the desired page structure includes organization-specific metadata, layouts, macros, labels, shared data, and multiple output formats.

Using such a tool as the complete platform would make the source syntax or publisher dictate the design.

**Decision:** Use Sphinx and a custom semantic extension instead.

### 21.2 Markdown to Storage XML, then `gomplate`

This flow was initially attractive:

```text
front matter + Markdown
→ Markdown-to-Confluence converter
→ Storage XML fragment
→ gomplate page shell
→ publisher
```

It is low-code and composable, but it creates two rendering layers and leaves publishing, attachment synchronization, page lifecycle, and identity management as separate concerns.

**Decision:** Do not use as the primary architecture. It remains a fallback if the Sphinx builder cannot express a required native structure.

### 21.3 Authoring Atlassian Document Format directly

ADF is a verbose JSON document tree and is not an ergonomic templating or authoring layer for this use case.

**Decision:** Ruled out.

### 21.4 Custom `curl` publisher

A basic create-or-update flow is possible through the Confluence REST API, but long-term requirements include attachments, attachment versions, hashing, retries, labels, hierarchy, and page synchronization.

**Decision:** Avoid recreating this layer while the Sphinx Confluence builder can own it.

### 21.5 Generic Confluence CLI as publisher

A mature CLI can create pages and upload attachments, but the project would still need to coordinate conversion, identity, page structure, and attachment references.

**Decision:** Keep as a contingency or administrative tool, not the primary pipeline.

### 21.6 Publish an interim page and overwrite its body

Having another tool publish a temporary or “bad” page and then replacing its body would add ordering problems, unnecessary versions, and ownership ambiguity. A dry run does not generally create an interceptable draft.

**Decision:** Ruled out.

### 21.7 Export HTML or PDF from Confluence

Confluence export may be useful for audit or disaster-recovery exercises, but it makes secondary artifacts dependent on Confluence availability and macro export behaviour.

**Decision:** Build HTML and PDF independently from Git through Sphinx.

### 21.8 LaTeX PDF

LaTeX offers strong document publishing but introduces a second visual design system and will not naturally match the customized HTML.

**Decision:** Use Playwright HTML-to-PDF.

### 21.9 One Sphinx build for all runbooks

A unified build would offer natural cross-document indexing, but it increases coupling and blast radius.

**Decision:** Publish one runbook per isolated Sphinx invocation. Generate aggregate indexes from manifests rather than from one monolithic Sphinx build.

---

## 22. Risks and mitigations

### Risk: Sphinx Confluence identity is title- or hierarchy-dependent

**Mitigation:** Build a focused proof of concept. Use supported page metadata, GUID, page ID mapping, or deterministic hierarchy where available. Add only a small identity adapter if required.

### Risk: A custom whole-page Confluence layout requires builder internals

**Mitigation:** First use public extension points: nodes, visitors, transforms, and builder events. Keep builder-specific markup in one module. Avoid forking unless no supported path exists.

### Risk: Per-runbook builds repeatedly initialize Sphinx

**Mitigation:** Accept the overhead initially for isolation. Parallelize with a configurable worker limit after correctness is established.

### Risk: Shared data changes affect many runbooks

**Mitigation:** Track data-key dependencies in manifests. Start with conservative rebuild-all behaviour for shared data, then optimize.

### Risk: HTML and Confluence drift visually

**Mitigation:** Define shared semantics and target-specific acceptance criteria rather than demanding visual identity.

### Risk: Playwright PDF differs across versions

**Mitigation:** Pin the browser and toolchain in the container. Add snapshot or structural tests for representative PDFs.

### Risk: Direct Confluence edits are overwritten

**Mitigation:** Display a generated-content warning, define ownership policy, and provide a clear source link.

### Risk: Builder upgrades alter generated markup or publication behaviour

**Mitigation:** Pin versions, maintain integration tests against a non-production Confluence space, and release container images through controlled versioning.

---

## 23. Testing strategy

### 23.1 Unit tests

Test:

- front matter schema;
- identifier normalization;
- label derivation;
- shared-data resolution;
- directive parsing;
- semantic node generation;
- URL derivation;
- manifest generation.

### 23.2 Golden rendering tests

Maintain representative runbooks and compare:

- Confluence markup;
- HTML fragments;
- full HTML pages;
- normalized Markdown;
- publication metadata.

### 23.3 Browser tests

Use Playwright to confirm:

- page loads;
- sidebar layout;
- image rendering;
- links;
- print media styles;
- PDF generation;
- responsive behaviour.

### 23.4 Confluence integration tests

Use a dedicated test space to verify:

- create;
- update;
- rename;
- attachment upload;
- changed attachment;
- unchanged attachment;
- label update;
- parent change;
- isolated re-publication;
- duplicate ID handling;
- deletion or archival policy.

### 23.5 Container action tests

Test the released image against a sample repository using the same GitHub Action interface consumers will use.

---

## 24. Delivery phases

### Phase 0 — Capability proof

Demonstrate one runbook with:

- mandatory front matter;
- one custom semantic node;
- one image attachment;
- native Confluence publication;
- custom HTML;
- Playwright PDF;
- manifest output;
- repeated publication updating the same Confluence page.

This phase must settle identity behaviour.

### Phase 1 — Minimum viable platform

Implement:

- recursive discovery;
- isolated builds;
- schema validation;
- standard page layout;
- labels and title conventions;
- attachment support;
- HTML theme;
- PDF generation;
- GitHub Action;
- aggregate reporting.

### Phase 2 — Operational hardening

Add:

- changed-only builds;
- dependency hashing;
- retries;
- structured logs;
- security hardening;
- container signing and SBOM;
- integration test space;
- deployment adapters.

### Phase 3 — Ecosystem outputs

Add as justified:

- normalized Markdown;
- Backstage integration;
- MkDocs integration;
- search index;
- automated runbook catalogue;
- additional object stores;
- optional Confluence export verification.

---

## 25. Acceptance criteria

The platform is ready for initial production use when:

1. A repository containing multiple `*.runbook.md` files can invoke one versioned GitHub Action.
2. Each runbook is validated and processed independently.
3. One failed runbook does not prevent unrelated runbooks from completing under the configured failure policy.
4. Re-publishing an existing runbook updates the correct Confluence page.
5. Renaming a page or source title does not accidentally create a duplicate, or the limitation is explicitly constrained and controlled.
6. Images and files are published as working Confluence attachments.
7. Unchanged attachments are not needlessly republished when supported by the builder.
8. Each runbook produces customized HTML.
9. Each runbook produces a readable PDF from that HTML.
10. Every output has a predictable path or captured URL.
11. Each representation links to the other representations.
12. A machine-readable manifest records source and output identities.
13. The complete process runs from a pinned, pre-built container image.
14. The same image can be executed locally for troubleshooting.
15. No author must write Confluence XML, HTML templates, or publishing API calls.

---

## 26. Recommended implementation boundary

The custom code should be limited to:

```text
sphinx_runbook extension
├── front matter and data loading
├── validation and policy
├── semantic nodes
├── whole-document transform
├── Confluence visitors
├── HTML visitors and template context
├── manifest generation
└── tests

runbook publisher entrypoint
├── discovery
├── isolated project generation
├── builder invocation
├── Playwright invocation
├── result aggregation
└── deployment handoff
```

The project should not own:

```text
Markdown parsing
Confluence REST publication
attachment versioning
HTML browser rendering engine
GitHub Actions container runtime
object-storage synchronization protocols
```

unless a proven gap requires a narrowly scoped adapter.

---

## 27. Final target architecture

```text
Git repository
│
├── *.runbook.md
├── attachments
├── shared YAML/JSON data
└── publication configuration
        │
        ▼
Pre-built Docker GitHub Action
        │
        ▼
Discover and validate runbooks
        │
        ▼
For each runbook, in isolation
        │
        ├── Generate temporary Sphinx project
        │
        ├── Load front matter and shared data
        │
        ├── Build semantic runbook document
        │
        │
        ├── Sphinx Confluence Builder
        │   ├── Native macros and layouts
        │   ├── Labels and conventions
        │   ├── Page create/update
        │   └── Attachment synchronization
        │
        ├── Sphinx HTML Builder
        │   ├── Custom theme
        │   ├── Metadata/sidebar
        │   ├── Static assets
        │   └── Cross-format links
        │
        ├── Playwright
        │   └── HTML → PDF
        │
        ├── Optional portable formatter
        │   └── Markdown/MkDocs/Backstage output
        │
        └── Per-runbook manifest
                │
                ▼
Aggregate manifest and deployment stages
        │
        ├── Confluence
        ├── S3 + CloudFront
        ├── PDF stores
        ├── SharePoint/Azure adapters
        ├── GitHub artifacts
        └── Future documentation systems
```

The result is a runbook publishing platform rather than a Confluence conversion script. It preserves a simple Markdown authoring experience, delegates publication complexity to established tools, enforces organizational standards through a normal Sphinx extension, and produces redundant, predictable representations from one version-controlled source.

---

## 28. Reference documentation

- [Sphinx Confluence Builder project](https://pypi.org/project/sphinxcontrib-confluencebuilder/)
- [Sphinx Confluence Builder configuration](https://sphinxcontrib-confluencebuilder.readthedocs.io/en/stable/configuration/)
- [Sphinx application and extension API](https://www.sphinx-doc.org/en/master/extdev/appapi.html)
- [Sphinx directives](https://www.sphinx-doc.org/en/master/usage/restructuredtext/directives.html)
- [Sphinx configuration and HTML options](https://www.sphinx-doc.org/en/master/usage/configuration.html)
- [GitHub: Creating a Docker container action](https://docs.github.com/actions/sharing-automations/creating-actions/creating-a-docker-container-action)
