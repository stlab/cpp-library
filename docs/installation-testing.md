# Test installation in your own workflow

If you maintain a library that needs installation testing, provide a separate
GitHub Actions workflow. Generated cpp-library CI tests source builds, not
installation. You do not need installation-specific dependency declarations
in your library's `CMakeLists.txt`.

## Before you begin

Declare dependencies after `cpp_library_setup()`. Generate your consumer
presets and CI with cpp-library, and use ordinary `target_link_libraries()`
calls for dependencies.

Identify every required dependency, its version, and how to install it
independently. Source locations alone do not describe installation recipes.
Dependencies must be available as installed packages before you configure
your library for installation.

## Add a workflow

Copy the [cel-euclid installation workflow](examples/cel-euclid-install.yml) to
`.github/workflows/install.yml` in cel-euclid. For another library, replace the
dependency checkouts, their installation commands, and the installation-option
name with those for your project.

The example runs on manual dispatch and performs these steps:

1. Check out the client and pinned dependency sources. Fetch tags for CEL
   packages so cpp-library discovers their release versions.
2. Build and install GLM 1.0.3 in its own build with `GLM_BUILD_INSTALL=ON`.
3. Build and install cel-runtime 1.1.2, then cel-parser 1.1.1, in separate builds.
4. Configure cel-euclid with its `install` preset and the installation prefix
   in `CMAKE_PREFIX_PATH`, then build and install it.
5. Run the existing cpp-library package-artifact check.

The GLM-specific setting belongs in GLM's installation command, not the
client's `CPMAddPackage()` declaration. The workflow accounts for cel-runtime
and cel-parser as well as GLM: all required packages must be installed even
when only GLM is maintained outside the CEL project.

Run the workflow from your repository's **Actions** tab. During configuration,
confirm that CPM reports local packages for the installed dependencies rather
than fetching them into the client's build. If it fetches one, check the
installed version and `CMAKE_PREFIX_PATH`.

`CPM_USE_LOCAL_PACKAGES=ON` prefers installed packages; it does not prohibit
source fallback. The workflow still fetches cpp-library itself through CPM.
Do not set `CPM_LOCAL_PACKAGES_ONLY` globally unless you also arrange for that
toolkit dependency to be satisfied.

## Check the result

The final step prints `Installed cel-euclid artifacts found` with the package
directory. A missing package artifact or an artifact absent from the install
manifest fails the check.

This verifies the root package's installation artifacts only. It does not
compile an installed consumer or guarantee that downstream dependency
resolution succeeds.
