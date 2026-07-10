Name:           mariadb-ctrlc
Version:        10.11.16
Release:        1%{?dist}
Summary:        MariaDB client with pre-10.11.7 Ctrl-C behavior, shadowing mysql via /usr/local/bin

# Covers the client program built here (client/mysql.cc and linked in-tree code)
License:        GPL-2.0-only
URL:            https://github.com/DigitalCyberSoft/mariadb-ctrlc-copr
Source0:        https://downloads.mariadb.org/interstitial/mariadb-%{version}/source/mariadb-%{version}.tar.gz
Patch0:         mariadb-restore-ctrlc-exit.patch

BuildRequires:  cmake
BuildRequires:  make
BuildRequires:  gcc-c++
BuildRequires:  openssl-devel
BuildRequires:  zlib-devel
BuildRequires:  libedit-devel
BuildRequires:  ncurses-devel

%description
The MariaDB command-line client built from upstream source with MDEV-14448
reverted: Ctrl-C at an idle prompt exits the client, Ctrl-C during a running
query kills the query, and repeated Ctrl-C exits.

The binary installs as /usr/local/bin/mysql, which precedes /usr/bin in the
default PATH, so it shadows the distribution client for interactive shells
and PATH-resolving scripts without touching any distribution-owned file.
The distribution mariadb packages stay stock, and the `mariadb` command is
not shadowed, only `mysql`.

%prep
%autosetup -p1 -n mariadb-%{version}

%build
%cmake -DWITHOUT_SERVER:BOOL=ON -DWITH_SSL=system -DCMAKE_SKIP_RPATH:BOOL=ON \
       -DINSTALL_LAYOUT=RPM \
       -DINSTALL_SYSCONFDIR=%{_sysconfdir} \
       -DINSTALL_SYSCONF2DIR=%{_sysconfdir}/my.cnf.d
%cmake_build --target mariadb

%install
install -D -m 0755 %{__cmake_builddir}/client/mariadb %{buildroot}/usr/local/bin/mysql

%files
/usr/local/bin/mysql

%changelog
* Fri Jul 10 2026 DigitalCyberSoft <claude@dcs.io> - 10.11.16-1
- Initial package: client-only build (-DWITHOUT_SERVER) with MDEV-14448
  reverted, installed as a /usr/local/bin/mysql PATH shadow
- Based on the 10.11 client: 11.4+ clients require TLS by default
  (ERROR 2026 against non-TLS servers), which defeats the purpose here
