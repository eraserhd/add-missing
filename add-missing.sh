#!@bash@/bin/bash

set -e

export PATH="@git@/bin:$PATH"

SLUG="TODO: fill me in"

usage() {
    printf 'Syntax: add-missing [-s|--slug SLUG]\n' >&2
    exit 1
}

parseArgs() {
    while (( $# > 0 )); do
        case "$1" in
            -s|--slug) shift; SLUG="$1";;
            -s*)       SLUG="${1#-s}";;
            --slug=*)  SLUG="${1#--slug=}";;
            *)         usage;;
        esac
        shift
    done
}

main() {
    parseArgs "$@"

    local packageName=$(basename "$(pwd)")

    # Files we no longer want
    rm -f default.nix nixpkgs.nix overlay.nix

    if [[ ! -f derivation.nix ]]; then
      (
        printf '{ stdenv, lib, ... }:\n'
        printf '\n'
        printf 'stdenv.mkDerivation rec {\n'
        printf '  pname = "%s";\n' "$packageName"
        printf '  version = "0.1.0";\n'
        printf '\n'
        printf '  src = ./.;\n'
        printf '\n'
        printf '  meta = with lib; {\n'
        printf '    description = "%s";\n' "$SLUG"
        printf '    homepage = "https://github.com/eraserhd/%s";\n' "$packageName"
        printf '    license = licenses.publicDomain;\n'
        printf '    platforms = platforms.all;\n'
        printf '    maintainers = [ maintainers.eraserhd ];\n'
        printf '  };\n'
        printf '}\n'
      ) >derivation.nix
    fi

    if [[ ! -f flake.nix ]]; then
      (
        printf '{\n'
        printf '  description = "%s";\n' "$SLUG"
        printf '  inputs = {\n'
        printf '    nixpkgs.url = "github:NixOS/nixpkgs";\n'
        printf '    flake-utils.url = "github:numtide/flake-utils";\n'
        printf '  };\n'
        printf '  outputs = { self, nixpkgs, flake-utils }:\n'
        printf '    (flake-utils.lib.eachDefaultSystem (system:\n'
        printf '      let\n'
        printf '        pkgs = nixpkgs.legacyPackages.${system};\n'
        printf '        %s = pkgs.callPackage ./derivation.nix {};\n' "$packageName"
        printf '      in {\n'
        printf '        packages = {\n'
        printf '          default = %s;\n' "$packageName"
        printf '          inherit %s;\n' "$packageName"
        printf '        };\n'
        printf '        checks = {\n'
        printf '          test = pkgs.runCommandNoCC "%s-test" {} %s\n' "$packageName" "''"
        printf '            mkdir -p $out\n'
        printf '            : ${%s}\n' "$packageName"
        printf '          %s;\n' "''"
        printf '        };\n'
        printf '    })) // {\n'
        printf '      overlays.default = final: prev: {\n'
        printf '        %s = prev.callPackage ./derivation.nix {};\n' "$packageName"
        printf '      };\n'
        printf '    };\n'
        printf '}\n'
      ) >flake.nix
    fi

    if [[ ! -f .github/workflows/test.yml ]]; then
      mkdir -p .github/workflows
      (
        printf 'name: "Test"\n'
        printf 'on:\n'
        printf '  pull_request:\n'
        printf '  push:\n'
        printf 'jobs:\n'
        printf '  tests:\n'
        printf '    runs-on: ubuntu-latest\n'
        printf '    steps:\n'
        printf '    - uses: actions/checkout@v2.4.0\n'
        printf '    - uses: cachix/install-nix-action@v15\n'
        printf '      with:\n'
        printf '        extra_nix_config: |\n'
        printf '          access-tokens = github.com=${{ secrets.GITHUB_TOKEN }}\n'
        printf '    - run: nix flake check\n'
      ) >.github/workflows/test.yml
    fi

    if [[ ! -f .gitignore ]] || ! grep -q '^/result$' .gitignore; then
      printf '/result\n' >>.gitignore
    fi
    if ! grep -q '^/.direnv$' .gitignorre; then
      printf '/.direnv\n' >>.gitignore
    fi

    if [ ! -f README.* ] && [[ ! -f README ]]; then
      (
        printf '%s\n' "$packageName"
        printf '%s\n' "${packageName//?/=}"
        printf '\n'
        printf '%s\n' "$SLUG"
      ) >README.adoc
    fi

    if [ ! -f LICENSE* ] && [ ! -f COPYING* ]; then
      cat >UNLICENSE <<EOF
This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or
distribute this software, either in source code form or as a compiled
binary, for any purpose, commercial or non-commercial, and by any
means.

In jurisdictions that recognize copyright laws, the author or authors
of this software dedicate any and all copyright interest in the
software to the public domain. We make this dedication for the benefit
of the public at large and to the detriment of our heirs and
successors. We intend this dedication to be an overt act of
relinquishment in perpetuity of all present and future rights to this
software under copyright law.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

For more information, please refer to <http://unlicense.org/>
EOF
    fi

    if [ ! -f ChangeLog* ] && [ ! -f CHANGELOG* ]; then
      (
        printf 'Changes\n'
        printf '=======\n'
        printf '\n'
        printf   'Unreleased\n'
        printf '%s----------\n' ""
        printf '\n'
      ) >CHANGELOG.adoc
    fi

    if [[ ! -f .envrc ]] || [[ $(cat .envrc) = "use nix" ]]; then
        printf 'use flake\n' >.envrc
    fi

    if [[ ! -d $(git rev-parse --git-dir 2>/dev/null) ]]; then
      git init
    fi

    if ! git remote |grep -q '^origin$'; then
      git remote add origin git@github.com:eraserhd/$packageName.git
    fi

    firstCommit=false
    if ! git log >/dev/null 2>&1; then
        firstCommit=true
    fi

    if [[ -n $(git status --porcelain) ]]; then
        git add -A
        if $firstCommit; then
            git commit -m "Initial commit"
            git checkout -b main
            git branch -D master
        else
            git commit -m "Update project structure"
        fi
    fi
}

main "$@"
