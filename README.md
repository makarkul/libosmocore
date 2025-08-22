libosmocore - set of Osmocom core libraries
===========================================

This repository contains a set of C-language libraries that form the
core infrastructure of many [Osmocom](https://osmocom.org/) Open Source
Mobile Communications projects.

Historically, a lot of this code was developed as part of the
[OpenBSC](https://osmocom.org/projects/openbsc) project, but which are
of a more generic nature and thus useful to (at least) other programs
that we develop in the sphere of Free Software / Open Source mobile
communications.

There is no clear scope of it. We simply move all shared code between
the various Osmocom projects in this library to avoid code duplication.

The libosmocore.git repository build multiple libraries:

* **libosmocore** contains some general-purpose functions like select-loop
  abstraction, message buffers, timers, linked lists
* **libosmovty** contains routines related to the interactive command-line
  interface called VTY
* **libosmogsm** contains definitions and helper code related to GSM protocols
* **libosmoctrl** contains a shared implementation of the Osmocom control
  interface
* **libosmogb** contains an implementation of the Gb interface with its
  NS/BSSGP protocols
* **libosmocodec** contains an implementation of GSM voice codecs
* **libosmocoding** contains an implementation of GSM channel coding
* **libosmosim** contains infrastructure to interface SIM/UICC/USIM cards


Homepage
--------

The official homepage of the project is
<https://osmocom.org/projects/libosmocore/wiki/Libosmocore>

GIT Repository
--------------

You can clone from the official libosmocore.git repository using

	git clone https://gitea.osmocom.org/osmocom/libosmocore

There is a web interface at <https://gitea.osmocom.org/osmocom/libosmocore>

Documentation
-------------

Doxygen-generated API documentation is generated during the build
process, but also available online for each of the sub-libraries at
<https://ftp.osmocom.org/api/latest/libosmocore/>

Mailing List
------------

Discussions related to libosmocore are happening on the
openbsc@lists.osmocom.org mailing list, please see
<https://lists.osmocom.org/mailman/listinfo/openbsc> for subscription
options and the list archive.

Please observe the [Osmocom Mailing List
Rules](https://osmocom.org/projects/cellular-infrastructure/wiki/Mailing_List_Rules)
when posting.

Contributing
------------

Our coding standards are described at
<https://osmocom.org/projects/cellular-infrastructure/wiki/Coding_standards>

We use a Gerrit based patch submission/review process for managing
contributions.  Please see
<https://osmocom.org/projects/cellular-infrastructure/wiki/Gerrit> for
more details

The current patch queue for libosmocore can be seen at
<https://gerrit.osmocom.org/#/q/project:libosmocore+status:open>

Experimental FreeRTOS Build Support
-----------------------------------

An experimental (work-in-progress) scaffold to attempt building portions of libosmocore against FreeRTOS headers is provided.

Goals:
* Single Docker image (`docker/Dockerfile.freertos`) for reproducible builds
* Dependency fetch script pulls FreeRTOS Kernel and FreeRTOS+TCP into `deps/freertos`
* Interactive shell (`docker compose run shell`) sets up environment without forcing a build
* Automated build (`docker compose run build`) runs autotools configure & make with `--enable-freertos` so the templated `socket_compat.h` uses the fallback structure (as it would on target) and FreeRTOS shims are compiled. For mobile FreeRTOS targets add trims: `--enable-freertos --disable-gsmtap --disable-gb --disable-libsctp --disable-libusb --disable-multicast`.
* In FreeRTOS mode the lightweight `pseudotalloc` allocator is auto-enabled and the external `libtalloc` dependency is suppressed, so memory helpers resolve internally.

Limitations:
* This is only a scaffold; actual porting (replacing POSIX socket, threading, timers with FreeRTOS equivalents) is not yet complete
* Unit tests relying on Linux / POSIX may fail under this configuration

Quick Start
~~~~~~~~~~~

```
docker compose build
docker compose run shell   # interactive environment
# inside container:
source scripts/freertos_env.sh
scripts/build-libosmocore-freertos.sh

# Or one-shot build:
docker compose run build
```

Artifacts are placed under `build-freertos/`.

Updating FreeRTOS Versions
~~~~~~~~~~~~~~~~~~~~~~~~~~

Override build args:
```
docker compose build --build-arg FREERTOS_KERNEL_REF=V11.1.0 --build-arg FREERTOS_TCP_REF=V4.1.0
```

Next Steps (Not yet implemented)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
* Implement abstraction layer for sockets/timers mapping to FreeRTOS+TCP and task notifications
* Provide minimal stubs for unsupported libc calls to reduce porting surface
* Gradually enable test subsets under `OSMO_FREERTOS`
