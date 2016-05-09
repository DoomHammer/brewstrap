# What is this?

`brewstrap` is a hack allowing to install [Linuxbrew](http://linuxbrew.sh/) on
a system lacking compiler and package manager. It bundles the required software,
hacks the installer and then installs all of the essential software.

# How to use it?

On a "host" machine run the `deploy.sh` script. It will produce
`dist/brewstrap-$VERSION.sh` which s both a bootstrap script as well as an
archive containing necessary binaries. It is around 50MB but well worth it.

Next, transfer the said bootstrap script to a target machine and run
`./brewstrap-$VERSION.sh` (substituting `$VERSION` with appropriate digits.
After around half an hour you should have a somewhat working Linuxbrew
installation

**IMPORTANT**: instead of usual `brew` command you should be using `sbrew`
wrapper (installed by the bootstrap script). This will hopefully change in the
future.

# Target requirements

Target system only needs a modest set of tools available:
- `/bin/sh`
- working glibc installation including `libpthread.so`
- `awk`
- `cat`
- `chmod`
- `mkdir`
- `sed`
- `tail`
- `tar`

An example of a target system can be obtained from contained Dockerfile. Whole system takes 84MB (80MB of it being `glibc`).

# Future work

- Integrate as much as possible into [Linuxbrew](https://github.com/Linuxbrew/brew)
- Slim down the bootsrap archive (if possible)
- Maybe drop the `libpthread` and `glibc` dependency?
