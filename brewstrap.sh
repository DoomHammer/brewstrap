#!/bin/sh
VERSION=0.1
ORIGWD=`pwd`
BREWSTRAP_DIR=$HOME/.linuxbrew/Cellar/brewstrap/$VERSION

before_extraction() {
  mkdir -p $BREWSTRAP_DIR
  cd $BREWSTRAP_DIR
}

after_extraction() {
  cd $BREWSTRAP_DIR/bin
  sed -i -e "s@/bin/bash@$BREWSTRAP_DIR/bin/bash@" *
  cp $1 ./brewstrap
  chmod +x brewstrap
  $BREWSTRAP_DIR/bin/ruby <<-EORUBY
    require 'open-uri'
    open('linuxbrew-install', 'wb') do |file|
      file << open('https://raw.githubusercontent.com/Linuxbrew/install/master/install').read
    end
EORUBY
  sed -i -e "s@/bin/bash@$BREWSTRAP_DIR/bin/bash@" \
    -e "s@/usr/bin/curl@$BREWSTRAP_DIR/bin/curl@" \
    -e "s@/usr/bin/which@/bin/which@" \
    -e '/HOMEBREW_REPO.*=/s@https://@git://@' \
    -e 's@# no analytics.*@system "#{HOMEBREW_PREFIX}/Cellar/brewstrap/'$VERSION'/bin/brewstrap", "--fixpaths"@' \
    linuxbrew-install
  export PATH=$PATH:$BREWSTRAP_DIR/bin
  export MAGIC=$BREWSTRAP_DIR/share/file/magic.mgc
  export TERMINFO=$BREWSTRAP_DIR/usr/share/terminfo
  ruby linuxbrew-install
  brew tap homebrew/dupes git://github.com/Linuxbrew/homebrew-dupes.git
  # Following https://github.com/Linuxbrew/brew/issues/32
  # tput from minos returns error which may be misinterpreted in Homebrew when
  # backticks are used. Using brewed ncurses we are safe(r).
  brew install homebrew/dupes/ncurses
  sed -i -e "s@$BREWSTRAP_DIR/usr/bin/tput@$HOME/.linuxbrew/bin/tput@" \
    $HOME/.linuxbrew/Library/Homebrew/utils.rb
  brew install \
    bash \
    binutils \
    file-formula \
    findutils \
    gawk \
    gcc \
    glibc \
    gnu-sed \
    gnu-tar \
    gnu-which \
    grep \
    linux-headers \
    make \
    util-linux
  # Perl needs this hack to compile on a system lacking /usr/include
  sed -i -e 's@-Dprefix=#{prefix}@-Dprefix=#{prefix}\n-Dlocincpth=#{Formula["glibc"].include}@' \
    $HOME/.linuxbrew/Library/Taps/homebrew/homebrew-core/Formula/perl.rb
  brew install perl --without-test
  # The following depend on openssl which in turn depends on perl but doesn't
  # want to admit it (though see: https://github.com/Linuxbrew/homebrew-core/pull/232)
  brew install \
    curl \
    git \
    ruby
  # Here is a wrapper to run brew without having /bin/bash
  cat > $(brew --prefix)/bin/sbrew <<-EOF
#!$(brew --prefix bash)/bin/bash
fix_paths() {
  sed -i.bak -e "s@/bin/bash@$(brew --prefix bash)/bin/bash@" \
    -e "s@/usr/bin/curl@$(brew --prefix curl)/bin/curl@" \
    -e "s@/usr/bin/file@$(brew --prefix file-formula)/bin/file@" \
    -e "s@/usr/bin/tput@$(brew --prefix ncurses)/bin/tput@" \
    -e "s@/usr/bin/which@$(brew --prefix gnu-which)/bin/which@" \
    -e "s@/usr/bin/awk@$(brew --prefix gawk)/bin/awk@" \
    $HOME/.linuxbrew/bin/brew \
    $HOME/.linuxbrew/Library/brew.sh \
    $HOME/.linuxbrew/Library/ENV/scm/git \
    $HOME/.linuxbrew/Library/Homebrew/utils.rb \
    $HOME/.linuxbrew/Library/Homebrew/keg_relocate.rb
}
if [ "\$1" == "update" ]; then
  trap "fix_paths" EXIT
fi
tail -n +1 $(brew --prefix)/bin/brew | source /dev/stdin
EOF
  chmod +x $(brew --prefix)/bin/sbrew
  # Ideally at this point we could switch fully to upstream, but since it is
  # using hardcoded paths we are out of luck for now
  sbrew update
  sbrew doctor
  echo 'You may now `sbrew uninstall brewstrap`'
}

fix_paths() {
  # Substitue set of hardcoded paths for another set of hardcoded paths
  sed -i.bak -e "s@/bin/bash@$BREWSTRAP_DIR/bin/bash@" \
    -e "s@/usr/bin/curl@$BREWSTRAP_DIR/bin/curl@" \
    -e "s@/usr/bin/file@$BREWSTRAP_DIR/bin/file@" \
    -e "s@/usr/bin/tput@$BREWSTRAP_DIR/usr/bin/tput@" \
    -e "s@/usr/bin/which@/bin/which@" \
    -e "s@/usr/bin/awk@/bin/awk@" \
    $HOME/.linuxbrew/bin/brew \
    $HOME/.linuxbrew/Library/brew.sh \
    $HOME/.linuxbrew/Library/ENV/scm/git \
    $HOME/.linuxbrew/Library/Homebrew/utils.rb \
    $HOME/.linuxbrew/Library/Homebrew/keg_relocate.rb
  sed -i.bak -e '/default_remote/N;s@https://@git://@' \
    $HOME/.linuxbrew/Library/Homebrew/tap.rb
}

if [ "x$1" = "x--fixpaths" ]; then
  fix_paths
  exit 0
fi

before_extraction
THIS=$ORIGWD/$0
SKIP=`awk '/^__TARFILE_FOLLOWS__/ { print NR + 1; exit 0; }' $THIS`
tail -n +$SKIP $THIS | tar -x
after_extraction $THIS
exit 0
__TARFILE_FOLLOWS__
