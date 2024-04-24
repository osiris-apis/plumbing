# macOS Platform

Applications for the macOS platform are distributed as packaged
*Application Bundle*. Multiple packaging and distribution formats are
available, but *Installer Packages* are the recommended solution. Binary files
use the *Mach-O* format and commonly include machine code for multiple
architectures. At runtime, an application is put into a sandbox and gets access
to common system interfaces via *Objective-C* APIs provided by the platform.

Followingly, an in-depth description of the macOS platform for applications,
with links to official documentation from Apple, if available.

## ABI

The macOS platform supports the *64-bit Intel Architecture*, as well as the
*64-bit ARM Architecture*. Neither PowerPC nor any of the previously supported
32-bit architectures are supported, anymore.

- **ARM64**: The 64-bit ARM Architecture is used exclusively for all new
  releases of the macOS platform. The
  [Standard ARM ABI](https://github.com/ARM-software/abi-aa)
  (mostly described in *aapcs64*) is followed, with
  [minor exceptions](https://developer.apple.com/documentation/xcode/writing-arm64-code-for-apple-platforms)
  specific to macOS.

- **Intel**: For backwards-compatibiliy, the *64-bit Intel Architecture* is
  still supported by the macOS platform. A 2-year transition period was
  announced, and it is unclear whether newer platform releases will include
  support for Intel architectures. The System-V *gABI* and
  [*psABI-x86-64*](https://gitlab.com/x86-psABIs/x86-64-ABI)
  are followed, with
  [minor exceptions](https://developer.apple.com/documentation/xcode/writing-64-bit-intel-code-for-apple-platforms)
  specific to macOS. For backwards-compatibility, *ARM64* Apple Silicon can
  translate *x86-64* instructions to native machine code using
  [*Rosetta*](https://developer.apple.com/documentation/apple-silicon/about-the-rosetta-translation-environment).
  Translation happens ahead-of-time and can take a significant amount of time.

Machine code is packaged as
[*Mach-O*](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/CodeFootprint/Articles/MachOOverview.html)
files. Multiple *Mach-O* binaries can be combined into a
*Universal macOS Binary* using the native
[*lipo*](https://developer.apple.com/documentation/apple-silicon/building-a-universal-macos-binary)
utility. Technically, universal binaries are a superset of the *Mach-O* format,
yet they are usually described as part of the *Mach-O* format and are treated
by the platform alike.

No specific runtime is required to execute on macOS, yet most of the system
interfaces are exclusively accessible via *Objective-C* APIs. Those require the
binary to provide a suitable runtime compatible with the
[*macOS Objective-C runtime*](https://developer.apple.com/documentation/objectivec/objective-c_runtime)
usually linked from */usr/lib/libobjc.A.dylib*. This runtime is unique to macOS
and differs significantly from other *Objective-C* runtimes, in particular the
one used by GNU systems.

## Toolchain

All official parts of the platform are built via **Xcode**, an integrated
development environment provided as part of the macOS platform. It uses
**LLVM** for machine-code generation, **clang** as C/C++/Objective-C
frontend, and **LD64** as linker (which Apple calls *static linker*, compared
to the runtime dynamic loader **dyld**, which Apple calls *dynamic linker*).
The linker is based on the old **GCC ld** code and about to be replaced with a
new linker called **ld-prime**. Furthermore, **Xcode** provides a plentitude of
utilities alongside the standard toolchain. The `xcrun` command can be used to
invoke toolchain commands from the user-selected **Xcode** install location.

Configuration data on the macOS platform is usually stored as
*Information Property Lists*, known as
[*plist format*](https://developer.apple.com/documentation/bundleresources/information_property_list).
It is a key-value store encoded as XML. All macOS systems ship two useful
command-line utilities to introspect, modify, and convert *plists*.
`/usr/libexec/plutil` can be used to convert from/to the *plist format*, and
`/usr/libexec/PlistBuddy` allows applying basic transformations.

## Applications

The standard format for *macOS Applications* is the
[*Application Bundle*](https://developer.apple.com/documentation/bundleresources/placing_content_in_a_bundle)
(more elaborate documentation is provided in the
[*Archives*](https://developer.apple.com/library/archive/documentation/CoreFoundation/Conceptual/CFBundles/BundleTypes/BundleTypes.html#//apple_ref/doc/uid/10000123i-CH101-SW19)).
It is a plain directory following a standardized hierarchical structure that
typically contains executable code, loadable modules, and resource files.
Bundles are used for more than just applications, and can thus host resource
archives, shared frameworks, or other nested bundles.

*Application Bundles* must be regular directories on the local file system
with a name ending in `*.app`. In many ways, the macOS platform treats these
directories as single entities similar to archive files, rather than plain
directories. However, the format is not suitable for distribution, given its
unpacked file system structure.

The typical layout of an *Application Bundle* looks like this:

```txt
OsirisAnalyzer.app/
├── Contents/
│   ├── embedded.provisionprofile
│   ├── Info.plist
│   ├── {Frameworks,Helpers,Library,Plugins}/
│   │   └── ...
│   ├── MacOS/
│   │   └── OsirisAnalyzer
│   └── Resources/
│       └── ...
└── Versions/
    ├── Current -> A
    └── A/
        └── ...
```

All application content is placed in the `Contents` directory. If multiple
versions of a bundle are packaged together, they are placed in the `Version`
directory with a unique name for each version. A symlink with name `Current`
must point to the default version. Note that bundling multiple versions
together is deprecated, and thus typically the `Contents` directory is the only
directory present on the top-level of an *Application Bundle*.

The `Contents/Info.plist` file is the main manifest of the application. It
describes the high-level properties, the main executable, the distribution
properties, as well as legal metadata.

The `Contents/embedded.provisionprofile` file provides provisioning information
for the application and can be retrieved from the *Apple Developer Program* to
ensure the macOS platform recognizes the application. It combines information
about the application, the application author, as well as intended target
devices. It is signed by Apple and can thus be used to lock down the macOS
platform and restrict execution to bundles with a valid provisioning profile.

The main executable, as well as alternative application entrypoints have to be
placed in `Contents/MacOS/`. Non *Mach-O* code and any non-code resources have
to be placed in `Contents/Resources/`. Further directories are available for
nested bundles or special use-cases.

Correct placement of application resources is important if the application is
to be cryptographically signed. The macOS platform requires applications to be
signed for a wide range of functionalities, and it is expected to generally
require signing in the future. Otherwise, an application is free to make
liberate use of the directory layout.

Nested directory structures are only allowed in non-code directories (i.e.,
usually only in `Contents/Resources/`. This is, because directories are easily
misrecognized as bundles, and thus get special treatment. Hence, the common
code directories must not contain arbitrary sub-directories other than nested
bundles.

### Code Signing

*Application Bundles* can be cryptographically signed. This allows runtime
verification and attestation of the authenticity of the application, as well
as authentication and authorization of the application. *Mach-O* files can
carry their signature embedded as a special segment, while other resources in
a bundle need to carry their signature as a separate file. The `codesign` tool
is used to generate code signatures of *Mach-O* and non *Mach-O* files. A
limited amount of modifications to signed bundles is allowed, but most
modifications will invalidate the signature.

While applications can be signed with any user-created certificate, the macOS
platform will verify certificate signatures at runtime and usually require them
to be signed by an *Apple Authority* to gain access to guarded APIs and
resources. Such signed certificates can only be acquired via the paid
[*Apple Developer Program*](https://developer.apple.com/programs/).

Different kinds of certificates can be requested through the
*Apple Developer Program*. Only some certificates allow code-signing, while
others are used to sign archives and other distribution packages. Separate
certificates are used for signing development builds, release builds, and
builds for distribution outside of the Apple Mac AppStore. The correct type of
certificate must be used for each step to ensure the platform will accept it.

Apart from the craptographic signature, Bundle signatures also include a set
of attributes called
[*Entitlements*](https://developer.apple.com/documentation/bundleresources/entitlements).
These encode rights, privileges, and capabilities of the application, as well
as information about the entity that signed the bundle. These entitlements are
interpreted by the macOS platform and control what an application is allowed to
access at runtime.

Apple has released numerous in-depth articles on code-signing and related
operations:

- Docs: [Code Signing Services](https://developer.apple.com/documentation/security/code_signing_services)
- TN2206: [macOS Code Signing in Depth](https://developer.apple.com/library/archive/technotes/tn2206/_index.html)
- TN3125: [Inside Code Signing: Provisioning Profiles](https://developer.apple.com/documentation/technotes/tn3125-inside-code-signing-provisioning-profiles)
- TN3126: [Inside Code Signing: Hashes](https://developer.apple.com/documentation/technotes/tn3126-inside-code-signing-hashes)
- TN3127: [Inside Code Signing: Requirements](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements)
- TN3161: [Inside Code Signing: Certificates](https://developer.apple.com/documentation/technotes/tn3161-inside-code-signing-certificates)
- Archive: [Code Signing Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide)

### Notarization

The
[*Notarization Process*](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
allows stapling notarization tickets to a bundle and thus attesting that the
bundles has undergone the notarization process on an Apple server. This process
performs automatic validation of a bundle following a closed procedure not open
to the public.

Notarization is used to perform automatic tests on a bundle and thus prevent
a wide range of common malicious practices. It is an automated process, and
thus comes with its own class of problems.

Notarization must be performed after signing a bundle, but before distribution.
On success, the notarization ticket will be retained on apple servers and can
be queried by macOS systems. Optionally, the ticket can be stapled to a bundle
without invalidating its signature, and thus is available on offline systems.

Notarization is required for distribution via the Apple AppStore, but optional
for 3rd party distribution channels. macOS systems will include a note about
notarization when first running an application, but will not prevent
unnotarized applications from running. This might change in the future, though.

### Execution

The macOS platform provides a rich set of APIs to
[spawn *Application Bundles*](https://developer.apple.com/documentation/foundation/nsbundle).
Historically, bundles could be executed by simply running the binaries in the
`Contents/MacOS/` directory. However, this was never officially supported and
will not work on newer platforms. Instead, the provided APIs will perform
require sandbox setups, adjust resource accounting, perform signature checks,
and correctly load required bundle resources. A few notes to consider:

- **Current Directory**: The current working directory upon bundle execution
  has no significance. It does not reflect the directory the bundle is called
  in, nor should it be used to refer to user resources. In most situations, it
  is simply set to the root directory.

- **Introspection**: The `NSBundle` platform APIs must be used to introspect
  the execution environment. This provides information about the directory of
  the caller, as well as the location of the bundle itself.

- **Bundle Location**: Before execution, a bundle on a removable medium is
  always copied onto the local hard-drive. This prevents virtualized, or
  otherwise unreliable disks to modify bundle resources during execution and
  thus invalidate signatures. Bundles on the local hard-drive are executed in
  place.

## Packaging

*Application Bundles* cannot be easily distributed, since the open-coded
file system layout does not lend itself to distribution via the Web. Instead,
the macOS platform supports
[3 different ways](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution)
of packaging bundles for distribution:

- **Archives**: Simple zip-archives (or similar archive technologies) can be
  used to package bundles and additional resources. Receivers will simply
  unpack the archive and move contained bundles to the desired location.
  Note that zip-archives cannot be signed, and as such are subject to
  tampering (contained bundles can be signed individually, but the entire
  package cannot be signed as a whole).

- **Disk Images**: The *dmg* format is similar in capabilities to *archives*.
  Receivers will simply mount the image and move contained bundles to the
  desired location. However, disk images can be signed as a whole and thus
  cannot be tampered with.

- **Installers**: The *pkg* format is technically an archive that combines
  possibly multiple bundles, but can also carry more metadata and even code
  to be run at install time. The format supports signatures and the macOS
  platform comes with a suitable program that interprets these installers and
  provides visual guidance to a user. All applications submitted to the Apple
  AppStore must be provided as installer package. It is also the recommended
  distribution method by Apple.

### AppStore

The primary distribution method for applications on macOS is the official Apple
AppStore. The developer part is called *AppStoreConnect*. Its functionality is
extensively
[documented](https://developer.apple.com/help/app-store-connect/).

To validate and upload builds from the command-line, use
[altool](https://help.apple.com/asc/appsaltool).

## Rust Ecosystem

The Rust compiler has native support for *ARM* and *Intel* macOS platforms via
the
[`aarch64-apple-darwin`](https://doc.rust-lang.org/nightly/rustc/platform-support.html)
and
[`x86_64-apple-darwin`](https://doc.rust-lang.org/nightly/rustc/platform-support.html)
targets. These will produce plain *Mach-O* binaries. Neither *rustc* nor
*cargo* have any support for *Universal macOS Binaries*. The `core` and `alloc`
crates of the standard library can be used for macOS binaries without pulling
in any runtime (except if compiling as executable, in which case the C runtime
and dynamic loader are linked). If the `std` crate is used, the
*macOS Objective-C Runtime* will be linked and thus be available to other
crates as well.

The *macOS Objective-C Runtime* is exposed via the
[*objc-sys*](https://crates.io/crates/objc-sys/)
crate. The
[*objc*](https://crates.io/crates/objc/)
crate provides unsafe abstractions and macros on top of *objc-sys*. The
[*objc2*](https://crates.io/crates/objc2/)
crate is an effort to replace *objc* with safe abstractions that fully expose
the Objective-C environment to Rust. The latter is used by
[*icrate*](https://crates.io/crates/icrate/)
to provide auto-generated, safe bindings to almost all official APIs provided
by the macOS platform. None of these crates are strictly required to interact
with the macOS platform, and neither of the crates as evolved as de-facto
standard, yet.
