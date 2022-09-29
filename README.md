#build-scripts

## The Theory

Building software should be repeatable and straightforward.
Engineers building the same code in different ways will yield different
results, making the development process less deterministic.

These simple build scripts aim to remove the randomness from development and
provide a simple framework that can be used by the developer on the desktop and
by and automated build and test system.

ARM should be moving to single binaries built from common source wherever
possible, these build scripts take the concept further enabling a single build
to create binaries for a number (if not all) of similar platforms in one go. The
scripts will also provide a mechanism for building a single platform where they
need to be delivered in isolation.

Any change which breaks the ability to build multiple platforms is bad, so will
be rejected at code review!

The build is controlled by a platform files and filesystem files, the
platform file specifies which components need to be build and provide
configuration parameters for each component. Platform files describe a single
platform, but there is functionality for having similar flavours of a platform,
and building all flavours for a platform at once. Platform and filesystem
configuration are decoupled (see the Platforms and Filesystems sections later),
but platform files can specify some filesystem specific variables that only take
effect if that filesystem is also being built.

The scripts also provide for a build-all that will build all components, but
also provide for building individual components in isolation.

The build scripts provide the following functions:
- clean - clean out the build objects
- build - perform a build
- package - package up the built binaries
- all - do a clean, build and package in one go! This is only supported by the
        build-all.sh script.

## Structure

There are 3 special files, `framework.sh`, `build-all.sh` and `parse_params.sh`.

`framework.sh` - This file contains helper environment variable and is
        responsible for making the calls in the individual build scripts, it
        also provides error handling so that each build script doesn't need to.

`build-all.sh` - This scripts is responsible for checking the arguments parsed
        to the build, loading framework.sh and then executing the individual
        build scripts.

`parse_params.sh` - This script handles arguments to the build scripts and is
        used by the previously mentioned scripts.

There are then a series of individual build scripts for each component, each
script contains 3 functions:
- `do_build()` - the build stage
- `do_clean()` - the clean stage
- `do_package()` - the package stage.

Each function must be protected with a `component_BUILD_ENABLED` variable to
enable the platform to control if the build for a component is to be executed by
that platform.

Each script must include a description of the variables it uses, but also must
include the following lines at the bottom to enable it to work with the build
framework:
```
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/framework.sh $@
```

`build-target-bins.sh` is a special script that must be run last, it is
responsible for collecting together the build output and putting it in platform
specific directories ready for testing or release.

## Running The Build

You can either build everything or an individual component, you can call the
build script from anywhere withing workspace (i.e. from the root or further in).

```
#Set some variables used by commands
BUILD_SCRIPT_DIR=$(pwd) # Assuming we're in the build-script directory
PLATFORM=juno
FLAVOUR=juno
FILESYSTEM=busybox
COMMAND=build #Can be build/clean/package
#Command can also be 'all' for build-all.sh only
#If command is omitted, 'build' is assumed

#Run $COMMAND on all components for specified platform/flavour/filesystem
$BUILD_SCRIPT_DIR/build-all.sh \
	-p $PLATFORM \
	-t $FLAVOUR \
	-f $FILESYSTEM \
	$COMMAND

#Run $COMMAND on linux component for specified platform/flavour/filesystem
$BUILD_SCRIPT_DIR/build-linux.sh \
	-p $PLATFORM \
	-t $FLAVOUR \
	-f $FILESYSTEM \
	$COMMAND
```

###Examples

The following examples assume that the present working directory is one folder
up from this directory.

If you are unsure what platforms, flavours or filesystems are available in this
workspace, then just run `./build-scripts/build-all.sh -h`. This will show the
available choices.

--------------------------------------------------------------------------------

```
./build-scripts/build-all.sh -p juno -f all
```
 - The above builds for the juno platform. All filesystems are also built. No
 packaging steps are done.

--------------------------------------------------------------------------------

```
./build-scripts/build-all.sh -p juno -f all package
```
 - Packages juno binaries into the output directory. This *must* be run
after the build for juno (previous example). For more reliable results, use the
following example for a more reliable way of building and packaging in one go.

--------------------------------------------------------------------------------

```
#Set platform and flavour and filesystem
#For single flavour platforms like Juno, flavour is set to platform.
./build-scripts/build-all.sh -p $platform -f $filesystem -t $flavour all

#For single flavour platform builds "-t" can be omitted.
#For example for juno, packaging for OE:
#./build-scripts/build-all.sh -p juno -f oe all
```
 - Cleans the source directories, then builds the a particular flavour of the
 given platforms. Then packages up the output.

--------------------------------------------------------------------------------

```
./build-scripts/build-all.sh -p all -t all -f all clean
```

 - Cleans the source directories for all components for all components.

--------------------------------------------------------------------------------

```
#Set 'platform' to an avaliable platform
./build-scripts/build-all.sh -p $platform all
```
 - Cleans the source directories, then for each flavour of the given platform,
 it will build source directories, and then package up the output.

--------------------------------------------------------------------------------

## Configs

Config files provide configuration for platforms and flavours of that
platform. The structure on the filesystem is shown below.

```
configs/
├── common
│   └── common.base
└── platform_name
    ├── flavour1_name
    ├── platform_name.base
    └── flavour2_name
```

There will be a folder named after the platform. This should contain a `.base`
file named after the platform which contains the core configuration for that
platform. This should `source` the `common.base` file for the default
configuration. Then a flavour file should source the `.base` file for this
platform. Further flavours are subsequently a lot easier to define.

If this behaviour is not desired, and only one flavour of the platform is
required then the following structure might be desired instead:

```
configs/
├── common
│   └── common.base
└── my_platform
    └── my_platform
```

This platform file should still source the `common.base` file for the defaults,
then can override variables as appropriate.

The `common.base` file has comments on the types of variables than can and
should be overridden.

These platform files also declare the compilers and tools required for each
build step so that the build scripts can be used by multiple types of build (32
and 64bit for example).

## Filesystems

Filesystem files are very similar to the platform files, but they will only be
sourced if the particular filesystem is being built from the options passed to
the build scripts.

This means that only one platform file needs to be maintained for a particular
platform, and this can be configured to work for multiple filesystems.

##Results of the build

Built binaries will be stored in a folder named output, in the same directory as
the build-scripts folder. Under this output folder, a sub-directory will be
named after platforms, and then platform flavour name will be one below that.

This is not the case for platforms with only a single flavour, and they will be
stored in a subfolder with the name of the platform under the output folder.

Output for the juno flavour of the juno platform will be stored under
`output/juno/`.
