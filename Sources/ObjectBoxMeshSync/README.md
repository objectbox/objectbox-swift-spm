# ObjectBoxMeshSync sources (generated copy, do not edit)

These files are a copy of `ObjectBoxMeshSync/Sources/ObjectBoxMeshSync` in the objectbox-swift repository,
placed here by its release tooling.
They back the `ObjectBoxMeshSync` product of this package, which is only available with the package's
`MeshSync` trait enabled.

Do not change anything here: changes belong in objectbox-swift and arrive with the next release. There are no
tests in this repository either; the add-on is tested in objectbox-swift.

Why sources live here at all: SwiftPM requires a package's source targets to be part of the package's own
repository, and this add-on is compiled from source because it depends on the rather large NearbyConnections package.
The preference is to keep this repository free of sources (manifest and binary targets only); this is a
(temporary?) exception. See `docs/mesh-sync.md` in objectbox-swift for the options that were considered.
