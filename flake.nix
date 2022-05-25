{
  description = "TODO: fill me in";
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils }:
    (flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        add-missing = pkgs.callPackage ./derivation.nix {};
      in {
        packages = {
          default = add-missing;
          inherit add-missing;
        };
        checks = {
          test = pkgs.runCommandNoCC "add-missing-test" {} (''
    set -x

    export PATH="${add-missing}/bin:${pkgs.git}/bin:$PATH"
    export GIT_AUTHOR_NAME="Foo Bar" GIT_COMMITTER_NAME="Foo Bar"
    export GIT_AUTHOR_EMAIL="foo@example.com" GIT_COMMITTER_EMAIL="foo@example.com"

    testCase() {
      mkdir -p "$out/$1"
      cd "$out/$1"
      return $?
    }

    testCase empty-dir
    add-missing
    grep -q '^/result' .gitignore
    grep -q '^/.direnv$' .gitignore
    grep -q '^empty-dir$' README.adoc
    grep -q '^=========$' README.adoc
    grep -q '^use flake$' .envrc
    grep -q 'http://unlicense.org/' UNLICENSE
    grep -q '^Changes$' CHANGELOG.adoc
    [[ -n $(git rev-parse --git-dir) ]]
    [[ -f .github/workflows/test.yml ]]
    git remote -v |grep -q '^origin	git@github.com:eraserhd/empty-dir.git (fetch)$'
    [[ $(cat derivation.nix) = '{ stdenv, lib, ... }:

stdenv.mkDerivation rec {
  pname = "empty-dir";
  version = "0.1.0";

  src = ./.;

  meta = with lib; {
    description = "TODO: fill me in";
    homepage = "https://github.com/eraserhd/empty-dir";
    license = licenses.publicDomain;
    platforms = platforms.all;
    maintainers = [ maintainers.eraserhd ];
  };
}' ]]
    [[ -z $(git status --porcelain) ]]
    [[ $(git rev-parse --abbrev-ref HEAD) = main ]]

    testCase specified-slug
    add-missing --slug 'Blork the flarpshreeper'
    grep -q 'description = "Blork the flarpshreeper"' derivation.nix
    grep -q '^Blork the flarpshreeper$' README.adoc

    testCase gitignore-no-result
    printf '/foo\n' >.gitignore
    add-missing
    grep -q '^/foo$' .gitignore
    grep -q '^/result$' .gitignore

    testCase gitignore-yes-result
    printf '/result\n' >.gitgnore
    add-missing
    (( 1 == $(grep -c '^/result$' .gitignore) ))

    testCase has-README-md
    touch README.md
    add-missing
    [[ ! -f README.adoc ]]

    testCase bare-REDME
    touch README
    add-missing
    [[ ! -f README.adoc ]]

    testCase has-envrc
    touch .envrc
    add-missing
    (( 0 == $(grep -c '^use flake$' .envrc) ))

    testCase has-nix-envrc
    printf 'use nix\n' >.envrc
    add-missing
    (( 1 == $(grep -c '^use flake$' .envrc) ))

    testCase has-overlay-nix
    add-missing
    [[ ! -f overlay.nix ]]

    testCase has-default-nix
    printf 'xyz\n' >default.nix
    add-missing
    [[ ! -f default.nix ]]

    testCase has-LICENSE
    printf 'xyz\n' >LICENSE.md
    add-missing
    [[ ! -f UNLICENSE ]]

    testCase has-COPYING
    printf 'xyz\n' >COPYING
    add-missing
    [[ ! -f UNLICENSE ]]

    testCase has-ChangeLog
    printf 'xyz\n' >ChangeLog
    add-missing
    [[ ! -f CHANGELOG.adoc ]]

    testCase has-CHANGELOG-adoc
    printf 'xyz\n' >CHANGELOG.adoc
    add-missing
    [[ $(cat CHANGELOG.adoc) = xyz ]]

    testCase has-CHANGELOG-md
    printf 'xyz\n' >CHANGELOG.md
    add-missing
    [[ ! -f CHANGELOG.adoc ]]

    testCase has-git-dir
    git init
    add-missing >$out/log 2>&1
    if grep -q 'Reinitialized' $out/log; then false; fi

    testCase no-flake-nix
    add-missing
    [[ $(cat flake.nix) = "{
  description = \"TODO: fill me in\";
  inputs = {
    flake-utils.url = \"github:numtide/flake-utils\";
  };
  outputs = { self, nixpkgs, flake-utils }:
    (flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.\''${system};
        no-flake-nix = pkgs.callPackage ./derivation.nix {};
      in {
        packages = {
          default = no-flake-nix;
          inherit no-flake-nix;
        };
        checks = {
          test = pkgs.runCommandNoCC \"no-flake-nix-test\" {} '""'
            mkdir -p \$out
            : \''${no-flake-nix}
          '""';
        };
    })) // {
      overlays.default = final: prev: {
        no-flake-nix = prev.callPackage ./derivation.nix {};
      };
    };
}" ]]

    set +x
  '');
        };
    })) // {
      overlays.default = final: prev: {
        add-missing = prev.callPackage ./derivation.nix {};
      };
    };
}
