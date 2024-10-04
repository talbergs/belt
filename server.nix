# error: builder for '/nix/store/06d3ygcysfc73v5l5zz03ilx8phmy6ar-zabbix-server-7.0.drv' failed with exit code 2;
# last 10 log lines:
# > make[3]: Entering directory '/build/70/src/libs/zbxdbschema'
# > ../../../create/bin/gen_schema.pl c > dbschema.c
# > /nix/store/vpvy79k1qq02p1vyqjk6nb89gwhxqvyb-bash-5.2p32/bin/bash: line 1: ../../../create/bin/gen_schema.pl: cannot execute: required file not found
# > make[3]: *** [Makefile:679: dbschema.c] Error 127
# > make[3]: Leaving directory '/build/70/src/libs/zbxdbschema'
# > make[2]: *** [Makefile:638: all-recursive] Error 1
# > make[2]: Leaving directory '/build/70/src/libs'
# > make[1]: *** [Makefile:503: all-recursive] Error 1
# > make[1]: Leaving directory '/build/70/src'
# > make: *** [Makefile:555: all-recursive] Error 1
# For full logs, run 'nix log /nix/store/06d3ygcysfc73v5l5zz03ilx8phmy6ar-zabbix-server-7.0.drv'.

let
  nixpkgs = "github:nixos/nixpkgs?ref=nixos-unstable";
  system = "x86_64-linux";
  pkgs = import <nixpkgs> { inherit system; };
in
pkgs.stdenv.mkDerivation {
  pname = "zabbix-server";
  version = "7.0";
  src = ./.;
  nativeBuildInputs = with pkgs; [
    autoreconfHook
    pkg-config
  ];

  buildInputs = with pkgs; [
    curl
    libevent
    libiconv
    libxml2
    openssl
    pcre
    zlib

    # unixODBC
    # iksemel
    # openldap
    # net-snmp
    # libssh2
    # libmysqlclient
    postgresql
    # openipmi

  ];

  configureFlags = [
    "--enable-ipv6"
    "--enable-server"
    "--with-iconv"
    "--with-libcurl"
    "--with-libevent"
    "--with-libpcre"
    "--with-libxml2"
    "--with-openssl=${pkgs.openssl.dev}"
    "--with-zlib=${pkgs.zlib}"
    # Optional
    # "--with-unixodbc"
    # "--with-jabber"
    # "--with-ldap=${pkgs.openldap.dev}"
    # "--with-net-snmp"
    # "--with-ssh2=${pkgs.libssh2.dev}"
    # "--with-mysql"
    "--with-postgresql"
    # "--with-openipmi=${pkgs.openipmi.dev}"
  ];

  prePatch = ''
    find database -name data.sql -exec sed -i 's|/usr/bin/||g' {} +
  '';

  preAutoreconf = ''
    for i in $(find . -type f -name "*.m4"); do
      substituteInPlace $i \
        --replace 'test -x "$PKG_CONFIG"' 'type -P "$PKG_CONFIG" >/dev/null'
        done
  '';
}
