---
id: aws-s3-upload-error
title: S3 upload error
type: operational-runbook
service: object-storage
owner: platform-storage
---

# Symptoms

Operators may see repeated upload failures and elevated error rates.

**Warning:** Do not retry indefinitely when requests return authorization errors.

# Diagnosis

1. Confirm the affected account and region.
2. Review the attached error screenshot.

```{runbook-image} s3-upload-error.assets/failure-example.png
:alt: Example upload failure
:caption: Typical authorization failure shown in the operator console
```

# Recovery

Follow the approved recovery sequence.
