#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BREWSTRAP=$SCRIPT_DIR/brewstrap.sh
VERSION=$(sed -ne "s/^VERSION=\(.*\)$/\1/p" $BREWSTRAP)
DEPLOY_DIR=$SCRIPT_DIR/deploy
DIST_DIR=$SCRIPT_DIR/dist
TARBALL=$DIST_DIR/brewstrap-$VERSION.tar

ensure_cd() {
  [ -d $1 ] || mkdir -p $1
  cd $1
}

get_minos_resource() {
  [ -e $1 ] || bash $DEPLOY_DIR/s $2 && tar xf $2*tar*
}

download_deps() {
  ensure_cd $DEPLOY_DIR
  [ -e s ] || wget -q s.minos.io/s
  [ -e bin/ruby ] || wget -qO- https://d6r77u77i8pq3.cloudfront.net/releases/traveling-ruby-20141215-2.1.5-linux-x86_64.tar.gz | tar xz
  get_minos_resource bin/bash bash
  get_minos_resource bin/curl curl
  get_minos_resource bin/file file
  get_minos_resource bin/git git
  get_minos_resource usr/bin/tput ncurses-bin
  get_minos_resource bin/tar tar
  get_minos_resource usr/share/terminfo terminfo
}

prepare_dist() {
  ensure_cd $DIST_DIR
  [ -f $TARBALL ] && rm $TARBALL
  tar cf $TARBALL -C $DEPLOY_DIR bin bin.real include lib share/file/magic.mgc usr/bin usr/share
  cat $BREWSTRAP $TARBALL > $DIST_DIR/brewstrap-$VERSION.sh
}

download_deps
prepare_dist
