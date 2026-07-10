# mariadb-ctrlc-copr

Source for the [reversejames/mariadb-ctrlc-exit](https://copr.fedorainfracloud.org/coprs/reversejames/mariadb-ctrlc-exit/) COPR: a MariaDB command-line client with the pre-10.11.7 Ctrl-C behavior restored, delivered as a PATH shadow instead of a distro-package replacement.

## What it does

MariaDB 10.11.7 ([MDEV-14448](https://jira.mariadb.org/browse/MDEV-14448)) made the client stop exiting on Ctrl-C. `mariadb-restore-ctrlc-exit.patch` reverts `handle_sigint` in `client/mysql.cc`:

- Ctrl-C at an idle prompt exits the client.
- Ctrl-C during a query kills the query (`KILL QUERY`, then `KILL CONNECTION`).
- Repeated Ctrl-C exits.

## How it wins over the distro client

`mariadb-ctrlc.spec` builds only the client (`-DWITHOUT_SERVER=ON`) from the upstream tarball and installs the single binary as **`/usr/local/bin/mysql`**. `/usr/local/bin` precedes `/usr/bin` in the default PATH, so every interactive shell and PATH-resolving script gets the patched client, while:

- no distribution-owned file is touched (`rpm -V` stays clean for all mariadb packages),
- distro updates can never overwrite it (packages do not install into `/usr/local`),
- the `mariadb` command and anything hardcoding `/usr/bin/mysql` intentionally keep stock behavior,
- no epoch games, no `includepkgs`, no version tracking against Fedora's mariadb.

The client version is pinned in the spec and is independent of the server packages on the host; MySQL/MariaDB clients routinely talk to servers of other versions. Bump `Version:` in the spec and push to rebuild against a newer upstream.

## Install

```sh
dnf copr enable reversejames/mariadb-ctrlc-exit
dnf install mariadb-ctrlc
hash -r   # existing shells may have hashed /usr/bin/mysql
```

Caveat to check once per host: `sudo mysql` follows sudoers `secure_path`, which must include `/usr/local/bin` for the shadow to apply under sudo.

## Automation

The workflow builds the srpm (downloading the upstream tarball via `spectool`) and submits it to the COPR chroots on every push that touches the spec, the patch, or the workflow, plus manual dispatch. It requires the `COPR_CONFIG` repository secret (a copr-cli config file; token from <https://copr.fedorainfracloud.org/api/>).

## History

The first iteration of this repo rebuilt Fedora's full `mariadb10.11`/`mariadb11.8` source packages with the patch, an Epoch bump to outrank distro updates, and daily version-tracking CI. It worked but rebuilt the entire server per Fedora release forever; the PATH-shadow design replaced it. See git history.
