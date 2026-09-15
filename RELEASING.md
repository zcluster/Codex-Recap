# Releasing

## Automated GitHub release

1. Update `CHANGELOG.md` if needed.
2. Create and push a version tag:

   ```sh
   git tag v1.0.0
   git push origin main v1.0.0
   ```

The release workflow builds the Apple Silicon app, verifies its architecture,
creates the ZIP and checksum, and attaches both files to a GitHub release.

## Local package

```sh
./package_release.sh
shasum -a 256 -c release/SHA256SUMS.txt
```

The current package is unsigned. Distributing a signed and notarized build
requires an Apple Developer ID Application certificate and notarization
credentials; those secrets should be stored in GitHub Actions secrets rather
than committed to the repository.
