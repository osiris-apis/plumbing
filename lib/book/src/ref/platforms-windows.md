# Windows Platform

Applications for the Windows platform are commonly distributed with declarative
or custom-made installers and are given a lot of leeway in how the application
is structured. The introduction of the
[*Universal Windows Platform (UWP)*](https://learn.microsoft.com/en-us/windows/uwp)
and later the
[*Windows App SDK*](https://learn.microsoft.com/en-us/windows/apps/windows-app-sdk/)
is an attempt to enforce more structure. Typically, an application is confined
to a single directory and uses PE+ binary files for the Intel architecture. At
runtime, applications are put into a sandbox with a virtualized view of the
system, using a wide array of platform APIs to interact with the system and
other components.

Followingly, an in-depth description of modern *Windows Applications*, with
many links to official documentation from Microsoft. Note that the Windows
platform has historically been very accepting of deviations from platform
recommendations, and thus has seen a wide range of ad-hoc solutions to common
problems. This guide focuses on *Windows Applications* as
[documented by Microsoft](https://learn.microsoft.com/en-us/windows/apps)
and follows official recommendations. If this deviates from wide spread
practice, it will be denoted shortly.

Microsoft officially states *Windows 10, version 1809* as minimum requirement
for the *Windows App SDK*, which we use as baseline requirement for this
documentation. Note that this version is far beyond support of Microsoft,
though, and thus users can likely set higher minimum requirements.

## ABI

Historically, the Windows platform has targetted Intel 32-bit architectures,
but has also seen support for other architectures like *DEC Alpha*, *MIPS*,
*PowerPC*, *ARMv7*, and *Itanium*. The latest releases have limited
architecture support to *Intel 64-bit* and *ARM 64-bit*. The maintenance
releases for older Windows platforms still support *Intel 32-bit* and
*ARM 32-bit*, but those are not considered in this documentation.

- **Intel 64-bit**: The 64-bit Intel architecture (i.e., **x86-64**) is the
  default for all current Windows platforms. Windows uses its
  [own ABI](https://learn.microsoft.com/en-us/cpp/build/x64-software-conventions)
  and deviates heavily from other platforms. The official platform ABI is often
  denoted as **MSVC**. Ports of common UNIX software sometimes uses the
  **System V** ABI on Windows as well. However, any foreign ABI will have to
  use *foreign function interfaces (FFI)* to interact with the platform.

- **ARM 64-bit**: The 64-bit ARM architecture is officially support by the
  Windows platform and follows the
  [Standard ARM ABI](https://github.com/ARM-software/abi-aa),
  with
  [minor exceptions](https://learn.microsoft.com/en-us/cpp/build/arm64-windows-abi-conventions).

Machine code is packaged as
[*PE32+*](https://learn.microsoft.com/en-us/windows/win32/debug/pe-format),
(which is an extension to *PE*/*PE32*, itself an extension to *COFF*). They
still carry an *MS-DOS MZ Stub*, but mostly for historic reasons.

No special runtime is required on the platform, yet most applications link to
the
[*Microsoft C Runtime (CRT)*](https://learn.microsoft.com/en-us/cpp/c-runtime-library/c-run-time-library-reference)
to gain access to common functionality and access platform interfaces.
