libfuse
=======

About
-----

This is a fork of the libfuse reference implementation which may be found here:
[https://github.com/libfuse/libfuse](https://github.com/libfuse/libfuse)

NOTE: Not all upstream release tags are present - that's a GitHub PITA issue that doesn't seem to be easily automated.

This fork is designed to build with **CMake**, otherwise it should be identical to
the reference platform.  The best reference for using libfuse is the reference
implementation.  BUT - This is the place to come for information about building
libfuse with CMake instead of meson.

FUSE (Filesystem in Userspace) is an interface for userspace programs
to export a filesystem to the Linux kernel. The FUSE project consists
of two components: the *fuse* kernel module (maintained in the regular
kernel repositories) and the *libfuse* userspace library (maintained
in this repository). libfuse provides the reference implementation
for communicating with the FUSE kernel module.

A FUSE file system is typically implemented as a standalone
application that links with libfuse. libfuse provides functions to
mount the file system, unmount it, read requests from the kernel, and
send responses back. libfuse offers two APIs: a "high-level",
synchronous API, and a "low-level" asynchronous API. In both cases,
incoming requests from the kernel are passed to the main program using
callbacks. When using the high-level API, the callbacks may work with
file names and paths instead of inodes, and processing of a request
finishes when the callback function returns. When using the low-level
API, the callbacks must work with inodes and responses must be sent
explicitly using a separate set of API functions.


Development Status
------------------

libfuse is shipped by all major Linux distributions and has been in
production use across a wide range of systems for many years. However,
at present libfuse does not have any active, regular contributors. The
current maintainer continues to apply pull requests and makes regular
releases, but unfortunately has no capacity to do any development
beyond addressing high-impact issues. When reporting bugs, please
understand that unless you are including a pull request or are
reporting a critical issue, you will probably not get a response. If
you are using libfuse, please consider contributing to the project.


Supported Platforms
-------------------

* Linux (fully)
* BSD (mostly/best-effort)
* For OS-X, please use [OSXFUSE](https://osxfuse.github.io/)
  

Installation
------------

You can download libfuse from https://github.com/libfuse/libfuse/releases. To build and
install, you must use [Meson](http://mesonbuild.com/) and
[Ninja](https://ninja-build.org).  After downloading the tarball and `.sig` file, verify
it using [signify](https://www.openbsd.org/papers/bsdcan-signify.html):

    signify -V -m fuse-X.Y.Z.tar.gz -p fuse-X.Y.pub
    
The `fuse-X.Y.pub` file contains the signing key and needs to be obtained from a
trustworthy source. Each libfuse release contains the signing key for the release after it
in the `signify` directory, so you only need to manually acquire this file once when you
install libfuse for the first time.

To build and install, you are free to use meson or CMake

We recommend to use [CMake](https://cmake.org/) the hugely superior meta-make
system.  CMake allows a developer to use a wide variety of build systems and
includes native support for various command-line or GUI environments such as
Visual Studio, Eclipse, CodeBlocks, Ninja, or plain old Unix make.

You are free to use the Unix make, Ninja, or any other CMake supported make
system - see, CMake is better than meson !

### Building with CMake

Out of source builds are *highly* recommended.  Simply create a (temporary)
build directory and run CMake:

    $ mkdir build; cd build
    $ cmake ..

The defaults match upstream's meson build: utilities, examples and tests are
all built, and the build type is `RelWithDebInfo` (`-O2 -g`, meson's
`debugoptimized`). As in meson, `NDEBUG` is never defined unless you ask for
it - the tests and examples rely on `assert()` running.

Options are set with `-D` on the command line (or with `ccmake`/`cmake-gui`).
Each one mirrors a meson option:

| CMake option | meson option | Default |
|---|---|---|
| `OPTION_BUILD_UTILS` | `utils` | `ON` |
| `OPTION_BUILD_EXAMPLES` | `examples` | `ON` |
| `OPTION_BUILD_TESTS` | `tests` | `ON` |
| `OPTION_ENABLE_IO_URING` | `enable-io-uring` | `ON` (used if liburing is found) |
| `OPTION_ENABLE_CUSTOM_IO` | `enable-custom-io` | `OFF` (see `doc/README.custom-io`) |
| `OPTION_ENABLE_USDT` | `enable-usdt` | `OFF` |
| `OPTION_DISABLE_LIBC_SYMBOL_VERSION` | `disable-libc-symbol-version` | `OFF` |
| `OPTION_SYNC_INIT` | `sync-init` | `auto` (`auto`, `always`, `never`) |
| `OPTION_SERVICE_SOCKET_DIR` | `service-socket-dir` | empty = `/run/fuse` |
| `OPTION_SERVICE_SOCKET_PERMS` | `service-socket-perms` | empty = `0220` |
| `OPTION_SYSTEMD_SYSTEM_UNIT_DIR` | `systemd-system-unit-dir` | empty = ask pkg-config |
| `OPTION_UDEVRULESDIR` | `udevrulesdir` | empty = ask pkg-config |
| `OPTION_INITSCRIPTDIR` | `initscriptdir` | `/etc/init.d/` (empty = don't install) |
| `OPTION_USEROOT` | `useroot` | `ON` (make fusermount3 setuid root on install) |
| `OPTION_NDEBUG` | `b_ndebug` | `OFF` |

For example, to install into your home directory without the setuid step:

    $ cmake -DCMAKE_INSTALL_PREFIX=$HOME/FUSE/install -DOPTION_USEROOT=OFF ..

To build, test and install, you then use make (or other supported build systems):

    $ make
    $ sudo ../test/run-tests.py --build-dir .
    $ sudo make install

`make check` builds everything and runs the same suite through `ctest`.

### Running the tests

Running the tests requires bash, Python 3 and (to resolve core dumps)
gdb. Instead of running the tests as root, the majority of tests can
also be run as a regular user if *util/fusermount3* is made setuid root
first; the rest then skip themselves:

    $ ../test/run-tests.py --build-dir . --setuid-helpers

Each test gets its own working and log directory, and the runner prints
what every one of them cost. See the README under *test/cases* for how
to add one and where to look when one fails.

NOTE: Some tests are designed to "drop privileges" and so will be skipped if the
user is not root.

### Building with meson

The meson build files are kept, unchanged from upstream, so upstream's own
instructions also work:

    $ mkdir build; cd build
    $ meson setup ..
    $ meson configure            # list options
    $ ninja

### Keeping this fork in sync with upstream

See [cmake/README.md](cmake/README.md) for how upstream changes are merged and
how `cmake/check-meson-parity.py` checks that the CMake build still produces
what meson does.

Security implications
---------------------

The *fusermount3* program is installed setuid root. This is done to
allow normal users to mount their own filesystem implementations.
If built, the *fuservicemount3* program will also be installed setuid
root so that normal users can access containerized filesystem
implementations.

To limit the harm that malicious users can do this way, *fusermount3*
enforces the following limitations:

  - The user can only mount on a mountpoint for which they have write
    permission

  - The mountpoint must not be a sticky directory which isn't owned by
    the user (like /tmp usually is)

  - No other user (including root) can access the contents of the
    mounted filesystem (though this can be relaxed by allowing the use
    of the *allow_other* and *allow_root* mount options in
    */etc/fuse.conf*)


If you intend to use the *allow_other* mount options, be aware that
FUSE has an unresolved [security
bug](https://github.com/libfuse/libfuse/issues/15): if the
*default_permissions* mount option is not used, the results of the
first permission check performed by the file system for a directory
entry will be re-used for subsequent accesses as long as the inode of
the accessed entry is present in the kernel cache - even if the
permissions have since changed, and even if the subsequent access is
made by a different user. This is of little concern if the filesystem
is accessible only to the mounting user (which has full access to the
filesystem anyway), but becomes a security issue when other users are
allowed to access the filesystem (since they can exploit this to
perform operations on the filesystem that they do not actually have
permissions for).

This bug needs to be fixed in the Linux kernel and has been known
since 2006 but unfortunately no fix has been applied yet. If you
depend on correct permission handling for FUSE file systems, the only
workaround is to use `default_permissions` (which does not currently
support ACLs), or to completely disable caching of directory entry
attributes.

Building your own filesystem
------------------------------

FUSE comes with several example file systems in the `example`
directory. For example, the *passthrough* examples mirror the contents
of the root directory under the mountpoint. Start from there and adapt
the code!

The documentation of the API functions and necessary callbacks is
mostly contained in the files `include/fuse.h` (for the high-level
API) and `include/fuse_lowlevel.h` (for the low-level API). An
autogenerated html version of the API is available in the `doc/html`
directory and at http://libfuse.github.io/doxygen.


Getting Help
------------

If you need help, please ask on the <fuse-devel@lists.linux.dev>
mailing list (subscribe by mailing
<fuse-devel+subscribe@lists.linux.dev>, archive at
https://lore.kernel.org/fuse-devel/).

Please report any bugs on the GitHub issue tracker at
https://github.com/libfuse/libfuse/issues.

Please report CMake related libfuse bugs here:
https://github.com/Smit-tay/libfuse-cmake/issues


Professional Support
--------------------

Professional support is offered via [Rath Consulting](http://www.rath-consulting.biz).
