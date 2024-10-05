{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
      sass = pkgs.callPackage ./sass/default.nix { };
      var_dumper = ./php-decoration;

      php_env = pkgs.php;

      php_dumper = pkgs.writeShellApplication {
        name = "_";
        runtimeInputs = with pkgs; [
          php_env
          grc
        ];
        text = ''
          ${var_dumper}/vendor/bin/var-dump-server
        '';
      };

      php_runner = pkgs.writeShellApplication {
        name = "_";
        runtimeInputs = with pkgs; [
          php_env
          grc
        ];
        text = ''
          ${php_env}/bin/php -S 0.0.0.0:8080 \
            -d memory_limit=4G \
            -d error_reporting=E_ALL \
            -d log_errors=On \
            -d auto_prepend_file=${var_dumper}/debug.php \
            -d error_log=/tmp/php.error.log
        '';
      };

      server_builder = pkgs.writeShellApplication {
        name = "_";
        runtimeInputs = with pkgs; [
          git
          perl
          automake
          autoconf
          busybox
          gcc
          gnumake
          postgresql
          pkg-config
        ];
        text = ''
          if [ ! -e "$PWD/bootstrap.sh" ];then
              echo " expected $PWD/bootstrap.sh"
              echo " run this from within Zabbix source dir"
              exit 1
          fi

            tmp=/tmp/builder-$(basename "$0")

            if [[ -d "$tmp" ]];then
                rm -rf "$tmp"
            fi
            mkdir -p "$tmp"

            src=$PWD
            cp -r "$src/src" "$tmp/src"
            cp -r "$src/database" "$tmp/database"
            cp -r "$src/include" "$tmp"
            cp -r "$src/man" "$tmp"
            cp -r "$src/misc" "$tmp"
            cp -r "$src/m4" "$tmp"
            cp -r "$src/create" "$tmp"
            cp -r "$src/conf" "$tmp"
            cp -r "$src/templates" "$tmp"

            cp "$src/configure.ac" "$tmp"
            cp "$src/AUTHORS" "$tmp"
            cp "$src/Makefile.am" "$tmp"
            cp "$src/ChangeLog" "$tmp"
            cp "$src/NEWS" "$tmp"
            cp "$src/README" "$tmp"
            cp "$src/bootstrap.sh" "$tmp"

            cd "$tmp"

            find . -type f -name "*.m4" | xargs -0 -I{} \
              substituteInPlace {} \
                --replace "test -x $PKG_CONFIG" "type -P $PKG_CONFIG >/dev/null"

            aclocal -I m4
            autoconf
            autoheader
            automake -a
            automake

            ./configure \
              --prefix="$PWD"/_srv \
              --with-postgresql \
              --enable-ipv6 \
              --enable-server \
              --with-iconv \
              --with-libcurl \
              --with-libevent \
              --with-libpcre \
              --with-libxml2 \
              --with-openssl=${pkgs.openssl.dev} \
              --with-zlib=${pkgs.zlib}

            make

            cd -
        '';
      };
      scheme_builder = pkgs.writeShellApplication {
        name = "_";
        runtimeInputs = with pkgs; [
          git
          perl
          automake
          autoconf
          busybox
          gcc
          gnumake
        ];
        text = ''
          if [ ! -e "$PWD/bootstrap.sh" ];then
              echo " expected $PWD/bootstrap.sh"
              echo " run this from within Zabbix source dir"
              exit 1
          fi

            tmp=/tmp/builder-$(basename "$0")

            if [[ -d "$tmp" ]];then
                rm -rf "$tmp"
            fi
            mkdir -p "$tmp"

            src=$PWD
            cp -r "$src/src" "$tmp/src"
            cp -r "$src/database" "$tmp/database"
            cp -r "$src/include" "$tmp"
            cp -r "$src/man" "$tmp"
            cp -r "$src/misc" "$tmp"
            cp -r "$src/m4" "$tmp"
            cp -r "$src/create" "$tmp"
            cp -r "$src/conf" "$tmp"
            cp -r "$src/templates" "$tmp"

            cp "$src/configure.ac" "$tmp"
            cp "$src/AUTHORS" "$tmp"
            cp "$src/Makefile.am" "$tmp"
            cp "$src/ChangeLog" "$tmp"
            cp "$src/NEWS" "$tmp"
            cp "$src/README" "$tmp"
            cp "$src/bootstrap.sh" "$tmp"

            cd "$tmp"
            aclocal -I m4
            autoconf
            autoheader
            automake -a
            automake

            ./configure --with-mysql --with-postgresql

            make dbschema

            cd -

            dst=$PWD/_db
            if [[ -d "$dst" ]];then
                rm -rf "$dst"
            fi
            mkdir -p "$dst"

            cat \
                "$tmp/database/postgresql/schema.sql" \
                "$tmp/database/postgresql/images.sql" \
                "$tmp/database/postgresql/data.sql" \
            > "$dst/postgresql.sql"

            cat \
                "$tmp/database/mysql/schema.sql" \
                "$tmp/database/mysql/images.sql" \
                "$tmp/database/mysql/data.sql" \
            > "$dst/mysql.sql"
        '';
      };
      sass_builder = pkgs.writeShellScriptBin "_" ''
        if [ ! -e "$PWD/bootstrap.sh" ];then
            echo " expected $PWD/bootstrap.sh"
            echo " run this from within Zabbix source dir"
            exit 1
        fi

        ${sass}/bin/sass --version

        ${sass}/bin/sass --no-cache --sourcemap=none sass/stylesheets/sass/screen.scss ui/assets/styles/blue-theme.css
        ${sass}/bin/sass --no-cache --sourcemap=none sass/stylesheets/sass/dark-theme.scss ui/assets/styles/dark-theme.css
        ${sass}/bin/sass --no-cache --sourcemap=none sass/stylesheets/sass/hc-light.scss ui/assets/styles/hc-light.css
        ${sass}/bin/sass --no-cache --sourcemap=none sass/stylesheets/sass/hc-dark.scss ui/assets/styles/hc-dark.css

        cp sass/img/browser-sprite.png ui/assets/img/
        cp sass/apple-touch-icon-120x120-precomposed.png ui/assets/img/
        cp sass/apple-touch-icon-152x152-precomposed.png ui/assets/img/
        cp sass/apple-touch-icon-180x180-precomposed.png ui/assets/img/
        cp sass/apple-touch-icon-76x76-precomposed.png ui/assets/img/
        cp sass/ms-tile-144x144.png ui/assets/img/
        cp sass/touch-icon-192x192.png ui/assets/img/
        cp sass/favicon.ico ui/
      '';
    in
    {

      packages.x86_64-linux.make_css = sass_builder;
      packages.x86_64-linux.make_scheme = scheme_builder;
      packages.x86_64-linux.make_server = server_builder;
      packages.x86_64-linux.run_php = php_runner;
      packages.x86_64-linux.run_php_dump = php_dumper;

    };
}
