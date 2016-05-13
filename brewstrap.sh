#!/bin/sh
VERSION=0.1
ORIGWD=`pwd`
HOMEBREW_DIR=${HOMEBREW_DIR:-$HOME}
BREWSTRAP_DIR=$HOMEBREW_DIR/.linuxbrew/Cellar/brewstrap/$VERSION

set -e
set -x

before_extraction() {
  mkdir -p $BREWSTRAP_DIR
  cd $BREWSTRAP_DIR
}

after_extraction() {
  # Do not verify certs as they are unavailable
  [ -e $HOME/.curlrc ] && cp $HOME/.curlrc $HOME/.curlrc.bak
  touch $HOME/.curlrc
  cat $HOME/.curlrc.bak|awk '{print};END {print "-k" }' > $HOME/.curlrc
  # Restore original `.curlrc` after completion
  trap "[ -e $HOME/.curlrc.bak ] && mv $HOME/.curlrc.bak $HOME/.curlrc" EXIT
  cd $BREWSTRAP_DIR/bin
  # `/bin/bash` may not be available
  find -type f | xargs sed -i -e "s@/bin/bash@$BREWSTRAP_DIR/bin/bash@"
  # Install self. Not the best way possible, but should suffice until a better
  # one is suggested.
  cp $1 ./brewstrap
  chmod +x brewstrap
  # Download Linuxbrew installer
  $BREWSTRAP_DIR/bin/ruby <<-EORUBY
    require 'open-uri'
    open('linuxbrew-install', 'wb') do |file|
      file << open('https://raw.githubusercontent.com/Linuxbrew/install/master/install').read
    end
EORUBY
  # Substitute system paths with those provided by brewstrap
  sed -i -e "s@/bin/bash@$BREWSTRAP_DIR/bin/bash@" \
    -e "s@/usr/bin/curl@$BREWSTRAP_DIR/bin/curl@" \
    -e "s@/usr/bin/which@$(which which)@" \
    -e '/HOMEBREW_REPO.*=/s@https://@git://@' \
    -e 's@# no analytics.*@system "#{HOMEBREW_PREFIX}/Cellar/brewstrap/'$VERSION'/bin/brewstrap", "--fixpaths"@' \
    linuxbrew-install
  export PATH=$PATH:$BREWSTRAP_DIR/bin
  export MAGIC=$BREWSTRAP_DIR/share/file/magic.mgc
  export TERMINFO=$BREWSTRAP_DIR/usr/share/terminfo
  # Hack to install Linuxbrew inside an arbitrary directory
  HOME=$HOMEBREW_DIR ruby linuxbrew-install
  export PATH=$HOMEBREW_DIR/.linuxbrew/bin:$PATH
  # tmpfs may be noexec, better stick to something else
  export HOMEBREW_TEMP=$HOMEBREW_DIR/.tmp
  mkdir -p $HOMEBREW_TEMP
  # Necessary to use dupes bottled for Linuxbrew
  brew tap homebrew/dupes git://github.com/Linuxbrew/homebrew-dupes.git
  # List of essentials following https://github.com/Linuxbrew/brew/issues/32
  brew install \
    binutils \
    gcc \
    linux-headers || brew postinstall gcc
  # glibc is unlinked since an older loader (the one in bottles) cannot work
  # with newer glibc
  brew install --force-bottle glibc || brew unlink glibc
  # Enable use of keg_only glibc
  sed -i.bak -e 's/\(.*prepend_path "LIBRARY_PATH".*\)/\1\nprepend_path "LIBRARY_PATH", Formula["glibc"].lib/' \
    $HOMEBREW_DIR/.linuxbrew/Library/Homebrew/extend/ENV/std.rb
  specfile=$(find -L $(brew --prefix gcc) -name specs|sed -ne '/\/lib\//p')
  sed -i.brewstrap -e 's@\(.*-isystem.*\)@\1 -I'"$HOMEBREW_DIR/.linuxbrew/Cellar/glibc/$(brew info glibc|sed -ne 's/glibc: [a-z]\+ \([^ ]*\).*/\1/p')/include@" $specfile
  # Perl needs this hack to compile on a system lacking /usr/include
  sed -i -e 's@-Dprefix=#{prefix}@-Dprefix=#{prefix}\n-Dlocincpth=#{Formula["glibc"].include}@' \
    $HOMEBREW_DIR/.linuxbrew/Library/Taps/homebrew/homebrew-core/Formula/perl.rb
  # perl tests tend to fail, probably a FIXME
  brew install perl --without-test
  # gawk tests require working en_US.UTF-8 locale, another FIXME
  yes 2|brew install --debug gawk
  # `libblkid` requires libudev.h which is a part of `systemd` formula that depends on `util-linux` (circular dependency)
  # `setpriv` requires cap-ng.h which is a port of `libcap-ng` that lacks formula
  sed -i.bak -e 's/\(.*"--disable-kill".*\)/\1,\n"--disable-libblkid",\n"--disable-setpriv"/' \
    $HOMEBREW_DIR/.linuxbrew/Library/Taps/homebrew/homebrew-core/Formula/util-linux.rb
  brew install \
    bash \
    coreutils \
    diffutils \
    file-formula \
    findutils \
    gnu-sed \
    gnu-tar \
    gnu-which \
    grep \
    make \
    util-linux
  # The following depend on openssl which in turn depends on perl
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
    $HOMEBREW_DIR/.linuxbrew/bin/brew \
    $HOMEBREW_DIR/.linuxbrew/Library/brew.sh \
    $HOMEBREW_DIR/.linuxbrew/Library/ENV/scm/git \
    $HOMEBREW_DIR/.linuxbrew/Library/Homebrew/utils.rb \
    $HOMEBREW_DIR/.linuxbrew/Library/Homebrew/keg_relocate.rb
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
    -e "s@/usr/bin/which@$(which which)@" \
    -e "s@/usr/bin/awk@$(which awk)@" \
    $HOMEBREW_DIR/.linuxbrew/bin/brew \
    $HOMEBREW_DIR/.linuxbrew/Library/brew.sh \
    $HOMEBREW_DIR/.linuxbrew/Library/ENV/scm/git \
    $HOMEBREW_DIR/.linuxbrew/Library/Homebrew/utils.rb \
    $HOMEBREW_DIR/.linuxbrew/Library/Homebrew/keg_relocate.rb
  sed -i.bak -e '/default_remote/N;s@https://@git://@' \
    $HOMEBREW_DIR/.linuxbrew/Library/Homebrew/tap.rb
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
