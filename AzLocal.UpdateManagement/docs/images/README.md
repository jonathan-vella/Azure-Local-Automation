# Screenshots

This folder holds the screenshots referenced from the module documentation.

## Convention

- Filenames are **kebab-case**, descriptive of the surface they capture (workflow + view), e.g.:
  - `apply-updates-summary.png` - the **Summary** tab of an `Step.6_apply-updates.yml` GitHub Actions run
  - `auth-smoke-test-validate-oidc.png` - the **Validate OIDC + RBAC** job page of an `Step.0_authentication-test.yml` run
- **Prefer PNG**. Keep each file under ~250 KB; run through `pngquant` / `oxipng` before committing.
- **No secrets**. Subscription IDs, tenant IDs, principal IDs, cluster GUIDs and cluster names must be masked or redacted in the captured frame before the screenshot lands here. The screenshots in this folder are taken from the public-safe `Azure/AzLocal.UpdateManagement` sandbox repo where those values are already replaced with `***`.
- **Capture from the default GitHub dark theme** so the visual style stays consistent across the docs.
- Cap the total set at ~6-8 images. GitHub UI redesigns invalidate screenshots faster than text - keeping the set small reduces refresh effort.

## Referenced by

| File | Section | Image |
|---|---|---|
| [`../../README.md`](../../README.md) | What's New in v0.7.60 | `apply-updates-summary.png` |
| [`../../Automation-Pipeline-Examples/README.md`](../../Automation-Pipeline-Examples/README.md) | 5.1 GitHub Actions - auth smoke test | `auth-smoke-test-validate-oidc.png` |
| [`../../Automation-Pipeline-Examples/README.md`](../../Automation-Pipeline-Examples/README.md) | 6.1 Inventory the estate | `inventory-clusters-run-output.png` |

When adding or removing an image, update this table and the consuming markdown link in the same commit.
