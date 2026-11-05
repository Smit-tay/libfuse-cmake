libfuse-cmake
=============

**libfuse, built with CMake.**

This is a fork of [libfuse](https://github.com/libfuse/libfuse), the
reference implementation of the Linux FUSE userspace library. The code is
upstream's; what this fork adds is a complete **CMake** build, and that is
the whole point of it. If you want libfuse in a CMake-based project or
toolchain, or just prefer CMake to meson, this is the place.

What that means in practice:

- **CMake is the primary build here.** It builds, installs and tests
  everything upstream's meson build does: the library, `fusermount3`,
  `mount.fuse3`, the examples, the test suite, the pkg-config file, man
  pages, udev rules and the init script.
- **It produces what meson produces.** CI checks every change to
  `master` against upstream's own meson build with
  [`cmake/check-meson-parity.py`](cmake/README.md): the same generated
  headers, compile flags, programs, exported symbols, install tree and test
  results. You can drop it in wherever upstream libfuse is expected.
- **No warning suppressions.** Upstream's meson build turns off
  `-Wsign-compare` and `-Wunused-result`; this build turns off nothing, and
  the warnings are fixed in the code instead.
- **It follows upstream.** The fork is regularly synced with upstream
  `master`, and the meson files are kept unchanged, so meson still works
  too.

Anything that isn't about the build is upstream's business: for the API,
documentation and libfuse itself, upstream is the reference. For building
libfuse with CMake, read on.

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
  

Getting the source
------------------

Upstream's release tarballs contain only the meson build. To build with
CMake, clone this repository, whose `master` tracks upstream `master`:

    $ git clone https://github.com/Smit-tay/libfuse-cmake.git
    $ cd libfuse-cmake

Not every upstream release tag is mirrored in this fork.


Building with CMake
-------------------

You need CMake 3.21 or later, a C compiler, and make or
[Ninja](https://ninja-build.org). Optional: a C++ compiler (for the
`passthrough_hp` and `memfs_ll` examples), liburing (fuse-over-io-uring),
and pkg-config with udev and systemd (to find their install directories).

Configure into a separate build directory, then build:

    $ cmake -S . -B build
    $ cmake --build build -j

Any CMake generator works: add `-G Ninja` to use Ninja, or open the build
in an IDE that understands CMake.

The defaults match upstream's meson build: utilities, examples and tests
are all built, and the build type is `RelWithDebInfo` (`-O2 -g`, meson's
`debugoptimized`). As in meson, `NDEBUG` is never defined unless you ask
for it: the tests and examples rely on `assert()`.

### Options

Options are set with `-D` when configuring, or interactively with `ccmake
build` or `cmake-gui`. To change one later, re-run the configure step with
the new value, e.g. `cmake -B build -DOPTION_BUILD_EXAMPLES=OFF`. Each
option mirrors a meson option:

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

The standard CMake settings work as usual, e.g. `CMAKE_INSTALL_PREFIX`
(default `/usr/local`), `CMAKE_BUILD_TYPE`, `CMAKE_C_COMPILER`.


Testing
-------

The tests need bash and Python 3, and gdb to resolve core dumps; `pip
install -r requirements.txt` installs the Python side of the tooling.
Most tests mount filesystems, so run the full suite as root:

    $ sudo test/run-tests.py --build-dir build

Alternatively, run it as a regular user and let it make
*util/fusermount3* setuid root first (it uses sudo for that); the tests
that need root then skip themselves:

    $ test/run-tests.py --build-dir build --setuid-helpers

Without either, most tests are skipped. Each test gets its own working
and log directory, and the runner prints what every one of them cost. See
the README under *test/cases* for how to add one and where to look when
one fails.

The suite is also registered with CTest, as the same two entries `meson
test` has (`fuse-tests`, and `fuse-tests-io-uring`, which skips itself
where the kernel lacks io-uring support):

    $ ctest --test-dir build                # run the suite
    $ cmake --build build --target check    # build everything, then run it


Installing
----------

    $ sudo cmake --install build

This installs the library, headers (under `include/fuse3`), `fuse3.pc`,
`fusermount3`, `mount.fuse3`, the man pages, the udev rule, the init
script and `fuse.conf`, in the same places meson would; the library
directory follows the platform convention (`lib64`, or `lib/<multiarch>`
on Debian and Ubuntu). With `OPTION_USEROOT` on (the default), the
install step also makes `fusermount3` setuid root, which is why it needs
root; see *Security implications* below. Run `sudo ldconfig` afterwards
if your system needs it to find a library in a new location.

To stage the install for packaging, set `DESTDIR`:

    $ DESTDIR=/tmp/fuse-stage cmake --install build

To install without root, e.g. into your home directory, turn off the
setuid step and redirect the two files that otherwise go to fixed system
paths (`/etc/init.d` and the system udev rules directory), exactly as
with meson:

    $ cmake -S . -B build -DCMAKE_INSTALL_PREFIX=$HOME/fuse \
          -DOPTION_USEROOT=OFF -DOPTION_INITSCRIPTDIR= \
          -DOPTION_UDEVRULESDIR=$HOME/fuse/lib/udev/rules.d
    $ cmake --build build -j && cmake --install build


Using libfuse from your own CMake project
-----------------------------------------

The installed libfuse is found through pkg-config, like upstream's:

    find_package(PkgConfig REQUIRED)
    pkg_check_modules(FUSE3 REQUIRED IMPORTED_TARGET fuse3)

    target_link_libraries(myfs PRIVATE PkgConfig::FUSE3)

For an install outside the default search path, point `PKG_CONFIG_PATH`
at its `pkgconfig` directory when configuring your project.


Building with meson
-------------------

The meson build files are kept unchanged from upstream, so upstream's
instructions also work:

    $ meson setup build
    $ meson configure build      # list options
    $ ninja -C build
    $ sudo test/run-tests.py --build-dir build
    $ sudo ninja -C build install

Upstream's release tarballs (meson only) are at
https://github.com/libfuse/libfuse/releases. Verify one with
[signify](https://www.openbsd.org/papers/bsdcan-signify.html) after
downloading it and its `.sig` file:

    signify -V -m fuse-X.Y.Z.tar.gz -p fuse-X.Y.pub

The `fuse-X.Y.pub` file contains the signing key and needs to be obtained
from a trustworthy source. Each libfuse release contains the signing key
for the release after it in the `signify` directory, so you only need to
manually acquire this file once.


How the fork is maintained
--------------------------

[cmake/README.md](cmake/README.md) describes how upstream changes are
merged, how `cmake/check-meson-parity.py` compares the two builds, and
the few deliberate differences between them. On GitHub, the
`CMake Build & Test` workflow builds with gcc, clang and 32-bit gcc
(warnings are errors), runs the test suite unprivileged and as root, and
runs the parity check, on every push to `master` and every pull request;
upstream's own workflows run alongside it.


Security implications
---------------------

The *fusermount3* program is installed setuid root (with CMake, unless
`OPTION_USEROOT` is off). This is done to allow normal users to mount
their own filesystem implementations.
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

Problems with the CMake build belong to this fork; please report them
at https://github.com/Smit-tay/libfuse-cmake/issues.


Professional Support
--------------------

Professional support is offered via [Rath Consulting](http://www.rath-consulting.biz).
