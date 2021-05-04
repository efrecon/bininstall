# Binary Installers for Dockerfile Automation

This repository contains utilities to simplify installing (released) binaries
into Docker images. These utilities can be used for other installation
purposese, but they are meant to replace common code blocks that will fetch
binaries/tar files from released github (or gitlab) projects and install them
directly into an target image.

## Binary Installer

The following command would install v1.21.0 of the `kubectl` kubernetes CLI
client to `/usr/local/bin`, printing some progress that will be relayed during
Docker image building.

```shell
./bininstall.sh \
  -v \
  https://storage.googleapis.com/kubernetes-release/release/v1.21.0/bin/linux/amd64/kubectl
```

`bininstall.sh` takes a single argument, the URL to a (released) binary. Its
options are:

* `-d`, or `--dest` or `--destination` is the destination directory for binary
  installation. It defaults to `/usr/local/bin`, which is used by most
  distributions for local installations and is almost always present in the
  `PATH` by default.
* `-b`, or `--bin` or `--binary` is the name of the binary to be placed in the
  destination directory. When empty, the default, it will be the basename of the
  specified URL, e.g. `kubectl` in the example above.
* `-v`, or `--verbose` will increase verbosity.

You can, also it is pedantic since URLs cannot start with a dash, separate the
options from the argument using a double dash, i.e. `--`.

## Tar Installer

The following command would extract the binary named `krew-linux_amd64` from the
extract tar of the latest release of `krew`, and install it as `kubectl-krew` in
`/usr/local/bin`. In that example, `krew-linux_amd64` is a path relative to the
tar extraction directory.

```shell
./tarinstall.sh \
  -v \
  -x krew-linux_amd64 \
  -b kubectl-krew \
  https://github.com/kubernetes-sigs/krew/releases/latest/download/krew.tar.gz
```

`tarinstall.sh` takes a single argument, the URL to a (released) tarfile. Its
options are:

* `-d`, or `--dest` or `--destination` is the destination directory for binary
  installation. It defaults to `/usr/local/bin`, which is used by most
  distributions for local installations and is almost always present in the
  `PATH` by default.
* `-x`, or `--extract` is the path, relative the extraction directory, at which
  to find the binary to install. When empty, the default, this will be the
  basename of the tar URL, without any trailing extension.
* `-b`, or `--bin` or `--binary` is the name of the binary to be placed in the
  destination directory. When empty, the default, it will be the basename of the
  extraction path from the `--extract` option.
* `-v`, or `--verbose` will increase verbosity.
