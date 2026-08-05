Name:           mariadb-ctrlc
Version:        10.11.16
Release:        2%{?dist}
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
# INSTALL_MYSQLSHAREDIR becomes the compiled-in default character-sets-dir
# (SHAREDIR/charsets). The RPM-layout default is /usr/share/mysql, which on
# Fedora is owned by Oracle MySQL's mysql-common, whose Index.xml still names
# charset ids 33/83 "utf8"; a >=10.6 MariaDB client then warns twice at every
# start about its compiled-in utf8mb3 collations. Point the client at charsets
# bundled from this same tarball so it never depends on host mysql/mariadb
# packaging.
%cmake -DWITHOUT_SERVER:BOOL=ON -DWITH_SSL=system -DCMAKE_SKIP_RPATH:BOOL=ON \
       -DINSTALL_LAYOUT=RPM \
       -DINSTALL_SYSCONFDIR=%{_sysconfdir} \
       -DINSTALL_SYSCONF2DIR=%{_sysconfdir}/my.cnf.d \
       -DINSTALL_MYSQLSHAREDIR=/usr/local/share/%{name}
%cmake_build --target mariadb

%install
install -D -m 0755 %{__cmake_builddir}/client/mariadb %{buildroot}/usr/local/bin/mysql
mkdir -p %{buildroot}/usr/local/share/%{name}
cp -a sql/share/charsets %{buildroot}/usr/local/share/%{name}/

%files
/usr/local/bin/mysql
/usr/local/share/%{name}/

%changelog
* Wed Aug 05 2026 DigitalCyberSoft <claude@dcs.io> - 10.11.16-2
- Bundle the tarball's charset definitions at /usr/local/share/mariadb-ctrlc/
  charsets and compile that path in as the default character-sets-dir.
  The upstream RPM-layout default, /usr/share/mysql/charsets, belongs to
  Oracle MySQL's mysql-common on Fedora; when that package was present the
  client parsed MySQL 8.0's Index.xml, which still names charset ids 33 and
  83 "utf8", and emitted two utf8mb3 collation warnings at every start.

* Fri Jul 10 2026 DigitalCyberSoft <claude@dcs.io> - 10.11.16-1
- Initial package: client-only build (-DWITHOUT_SERVER) with MDEV-14448
  reverted, installed as a /usr/local/bin/mysql PATH shadow
- Based on the 10.11 client: 11.4+ clients require TLS by default
  (ERROR 2026 against non-TLS servers), which defeats the purpose here
