# Binary Installers for Dockerfile Automation and GitHub Actions

This repository contains [utilities](#utilities) to simplify installing
(released) binaries into Docker images, together with a GitHub
[action](#github-action) that can achieve the same thing. When used as a GitHub
action, the installed binaries are made available under the `PATH` for being
used in future steps.

These utilities can be used for other installation purposes, but they are
meant to replace common code blocks that will fetch binaries/tar files from
released github (or gitlab) projects and install them directly into a target
image.

## Utilities

### Binary Installer

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

### Tar Installer

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
* `-p` or `--package` is the path to a directory where to store the entire
  content of the tar file upon installation. The directory will be created if
  necessary. When the value of this input is not an empty string, a symbolic
  link to the binary will be created from the 'destination' directory (with the
  name 'binary') towards the (relative) path 'extract' under 'package'.
* `-v`, or `--verbose` will increase verbosity.

## GitHub Action

The action will relay the [binary](#binary-installer) installer (when the value
of the `installer` input is exactly `bin`) or the [tar](#tar-installer)
installer (when the value of the `installer` input is exactly `tar`). For other
inputs, see [action.yml](./action.yml). The action will modify the `PATH` so
that the installed binary will be made available in future steps of your job.

For usage examples, look at the [test](.github/workflows/test.yml) workflow. The
workflow installs binaries from two GitHub projects:

* `jq` makes available its binaries directly when [releasing][jq].
* `act` makes available tar files when [releasing][act]

  [jq]: https://github.com/stedolan/jq/releases
  [act]: https://github.com/nektos/act/releases

If you want to make use of the `package` input in an optimal way, you should
pertain the content of tar files over time through giving it the following
value (see note on [caching](#caching) below).

```yaml
with:
  package: ${{ runner.tool_cache }}/${{ github.repository }}/opt
```

### Caching

By default, the action will download binaries into the tool cache, per
repository and runner. This is to give a chance to binaries to pertain over
time. If you want to keep binaries per workspace, you can provide use the
following snippet instead. This will ensure that binaries are removed prior
starting a workflow, thus bypassing most of the caching mechanisms.

```yaml
with:
  destination: ${{ github.workspace }}/bin
```
