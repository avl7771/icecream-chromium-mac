# icecream-chromium-mac

These instructions can be used to build Chromium or Chromium-based projects on
Mac using [icecream](https://github.com/icecc/icecream), possibly in combination
with [ccache](https://ccache.samba.org/). Compilation can be distributed to
macOS and Linux hosts. It was inspired by a similar effort found at
https://github.com/darktears/icecream-mac.

## Icecream setup on Mac client

On the client (the machine you're running the build on), you'll need to install
a recent version of icecream. At the moment of writing the latest release, 1.1,
doesn't include some of the fixes that are needed to make this work. I've
prepared an unofficial '1.2pre' release from icecream's master branch as of 3
January 2018 (see the [forked
repository](https://github.com/avl7771/icecream/releases)).

I assume you have [Homebrew](https://brew.sh) installed. Install icecream using
Homebrew:

```bash
$ brew install avl7771/homebrew-icecream/icecream
```

Make sure to follow the instructions to make the `iceccd` daemon run at startup.
Check using `ps` whether it's running on your machine.

Then clone this repository which contains scripts to create the icecream
environment pakages from Chromium's clang binaries, so that we can use the
included clang version to compile on Mac and Linux:

```bash
$ git clone https://github.com/avl7771/icecream-chromium-mac
```

## Icecream setup on Mac or Linux hosts

You'll need icecream 1.1 or newer on any host you want to participate. Install
and start it as normal. At least one host will need to run an icecc scheduler.

## Building with icecream

You'll need to set the following GN arguments to make building with icecc
possible. Set these using `gn args`:

```bash
enable_precompiled_headers=false
clang_use_chrome_plugins=false
ffmpeg_use_atomics_fallback=true
```

In addition, if you don't use `ccache`, also set

```bash
cc_wrapper="icecc"
```

If you *do* use `ccache`, put this in your `ccache.conf`:

```bash
prefix_command=icecc
```

Alternatively you can use the `CCACHE_PREFIX` environment variable to get the
same effect.

Finally, you'll need to set the `ICECC_VERSION` environment variable to use
custom-built environments when you're running `ninja` to build. It's set like
this, using the scripts and files from this repository:

```bash
$ export ICECC_VERSION=`path/to/geticeccversion.sh path/to/chromium/src`
```

To make sure that you're always using the correct environment for the repository
you're building from, I recommend setting it for your `ninja` build only:

```bash
$ ICECC_VERSION=`path/to/geticeccversion.sh path/to/chromium/src` ninja -j30 -C out/Debug chrome
```

Vary the `-j` parameter to find something fitting for the number of hosts available. That's it, enjoy your distributed compile!
