# mariadb-ctrlc-copr

Automation for the [reversejames/mariadb-ctrlc-exit](https://copr.fedorainfracloud.org/coprs/reversejames/mariadb-ctrlc-exit/) COPR project: Fedora MariaDB packages with the pre-10.11.7 Ctrl-C behavior restored in the command-line client.

## What the patch does

MariaDB 10.11.7 ([MDEV-14448](https://jira.mariadb.org/browse/MDEV-14448)) changed the client so Ctrl-C no longer exits at an idle prompt. `mariadb-restore-ctrlc-exit.patch` restores the previous `handle_sigint` behavior in `client/mysql.cc`:

- Ctrl-C at an idle prompt exits the client.
- Ctrl-C during a query kills the query (`KILL QUERY`, then `KILL CONNECTION`).
- Repeated Ctrl-C exits.

## Packaging changes

`make-patched-srpm.sh` rebuilds a Fedora mariadb srpm with:

- the patch above, added as `Patch1000`;
- `Epoch` bumped 3 to 4, so these packages always sort ahead of distro updates;
- `Release` suffixed `.dcs1`;
- the client subpackage's `mariadb-common` requirement loosened to `>= 3:%{version}` so the distro's server, common, and errmsg packages stay installed unmodified.

Only the `mariadb` client package is meant to be installed from the COPR. Use `includepkgs`:

```ini
# in /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:reversejames:mariadb-ctrlc-exit.repo
includepkgs=mariadb
```

## Automation

`.github/workflows/rebuild.yml` runs daily and on dispatch. For each target release (43, 44, rawhide) it queries the release's default mariadb source package, compares against the newest COPR build for that package name, and when the distro is newer, downloads the srpm, applies the packaging changes, and submits builds to the matching chroots. A new upstream stream (for example `mariadb12`) is detected automatically from the source package name.

Requires the repository secret `COPR_CONFIG` containing a copr-cli config file (token from <https://copr.fedorainfracloud.org/api/>).

## Known failure modes

- Fedora branches a new release: add a matrix entry with the new releasever and chroots. COPR's `follow_fedora_branching` copies the last builds into new chroots in the meantime.
- Fedora itself bumps mariadb's `Epoch` to 4: `make-patched-srpm.sh` aborts by design (it verifies the distro epoch is still 3). Bump the script's epoch handling to 5 and rebuild.
- The build epoch means dnf prefers this repo's client even when the distro version is newer; if the automation stops running, the client stays at the last built version until it is fixed or the repo is removed.
