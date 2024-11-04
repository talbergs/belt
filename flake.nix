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

      php_env_debugger = pkgs.php.buildEnv {
        extensions = (
          { enabled, all }:
          enabled
          ++ (with all; [
            xdebug
            spx
          ])
        );
        extraConfig = ''
          ;;
          ;; add &XDEBUG_SESSION_START=1 query parameter
          ;;
          xdebug.start_with_request = trigger
          xdebug.client_host = localhost
          xdebug.mode = develop,debug
          xdebug.discover_client_host = 1

          ;;
          ;; http://localhost:8081/any.php?SPX_KEY=dev&SPX_UI_URI=/
          ;;
          spx.http_enabled=1
          spx.http_key="dev"
          spx.http_ip_whitelist="127.0.0.1"
        '';
      };

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

      php_runner_dbg = pkgs.writeShellApplication {
        name = "_";
        runtimeInputs = [
          php_env_debugger
        ];
        text = ''
          ${php_env_debugger}/bin/php -S 0.0.0.0:$1 \
            -d memory_limit=4G \
            -d error_reporting=E_ALL \
            -d log_errors=On \
            -d auto_prepend_file=${var_dumper}/debug.php \
            -d error_log=/tmp/php.error.log
        '';
      };

      php_runner = pkgs.writeShellApplication {
        name = "_";
        runtimeInputs = [
          php_env
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

      translation_check = pkgs.writeShellApplication {
        name = "_";
        runtimeInputs = with pkgs; [
          git
          gettext
        ];
        text = ''
          set +o nounset
          [[ $1 == -h ]] && grep '^#|' "$0" | sed 's/^#//' && exit 0
          [[ $# -ne 2 ]] && grep '^#|' "$0" | sed 's/^#//' && exit 1

          git rev-parse "$@" 1> /dev/null || exit 2

          then_ref="$1"
          now_ref="$2"

          rm -rf /tmp/_chstr
          mkdir /tmp/_chstr

          mk_pot() {
              git archive "$1" > /tmp/_chstr/"$1".tar
              tar -xf /tmp/_chstr/"$1".tar --one-top-level=/tmp/_chstr/"$1"
              cd /tmp/_chstr/"$1"
              find /tmp/_chstr/"$1" -type f -name "*.php" > /tmp/_chstr/"$1"/_phpfiles
              xgettext \
                  --files-from=_phpfiles \
                  --output=- \
                  --keyword=_n:1,2 \
                  --keyword=_s \
                  --keyword=_x:1,2c \
                  --keyword=_xs:1,2c \
                  --keyword=_xn:1,2,4c \
                  --from-code=UTF-8 \
                  --language=php \
                  --no-wrap \
                  --sort-output \
                  --no-location \
                  --omit-header
          }

          jira_fmt() {
              exec 8<>/tmp/_chstr/"$then_ref-$now_ref-removed"
              exec 9<>/tmp/_chstr/"$then_ref-$now_ref-added"

              echo "Strings added:" >&9;
              echo "Strings deleted:" >&8;

              while IFS= read -r line; do
                  fd=8 && [[ $line =~ ^\< ]] || fd=9

                  echo "$line" |
                  sed -r '/[<>] msgctxt/ {:a;N;s/[<>] msgctxt "(.+)"\n[<>] msgid "(.+)"/- _\2_ *context:* _\1_/g}' | \
                  sed -r 's/^(<|>) msgid(_plural){0,1} "/- _/g' | \
                  sed -r 's/"$/_/g' | \
                  sed -r 's/\\"/"/g' \
                      >&$fd
              done

              diff --changed-group-format="%>" --unchanged-group-format="" /dev/fd/8 /dev/fd/9
              echo
              diff --changed-group-format="%>" --unchanged-group-format="" /dev/fd/9 /dev/fd/8

              exec 9>&-
              exec 8>&-
          }

          diff <(mk_pot "$then_ref") <(mk_pot "$now_ref") | \
              grep -E '[<>] (msgid|msgctxt)' | jira_fmt
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
      packages.x86_64-linux.run_php_dbg = php_runner_dbg;
      packages.x86_64-linux.run_php_dump = php_dumper;
      packages.x86_64-linux.translation_check = translation_check;

    };
}
