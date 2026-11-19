# Quality checks

The `NEXUS Quality` workflow runs only on pull requests targeting `main`. It uses Flutter 3.44.4, the version validated for this change, and runs:

```sh
flutter pub get
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
flutter build web --no-pub --release --base-href /nexus/
```

The workflow substitutes the repository name for `nexus` in the build base path. Run dependency resolution before using `--no-pub`; it does not install missing packages. Windows plugin setup may require Developer Mode for symbolic links.

This is a validation-only workflow. It has read-only repository permissions and does not upload a Pages artifact or deploy. Its concurrency group is separate from the existing deployment workflow. The existing `deploy-web.yml` is unchanged and still deploys on pushes to `main`.

Repository maintainers can require the `NEXUS Quality / quality` check in branch protection after confirming its first successful GitHub run. Adding this file alone does not enable branch protection or make deployment depend on the check.

The intentionally skipped tutorial screenshot capture test remains skipped. The standard suite covers the new reorder callback's final indices and the case where a study editor's calling widget is disposed before deletion is requested.
