#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
project_dir="${script_dir:h}"
build_dir="${project_dir}/build"
dist_dir="${project_dir}/dist"
app_dir="${dist_dir}/iyh.app"
xcode_developer_dir="/Applications/Xcode.app/Contents/Developer"
swift_compiler="${xcode_developer_dir}/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
module_cache="${build_dir}/ModuleCache"

if [[ ! -x "${swift_compiler}" ]]; then
    print -u2 "Xcode toolchain not found at ${swift_compiler}"
    exit 1
fi

export DEVELOPER_DIR="${xcode_developer_dir}"
export CLANG_MODULE_CACHE_PATH="${module_cache}"
export SWIFT_MODULECACHE_PATH="${module_cache}"

sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
mkdir -p "${build_dir}" "${module_cache}" "${app_dir}/Contents/MacOS" "${app_dir}/Contents/Resources"

sources=("${project_dir}"/Sources/IYH/*.swift)
frameworks=(-framework AppKit -framework Carbon -framework ApplicationServices)

for architecture in x86_64 arm64; do
    "${swift_compiler}" \
        -parse-as-library \
        -swift-version 5 \
        -O \
        -whole-module-optimization \
        -sdk "${sdk_path}" \
        -target "${architecture}-apple-macosx13.5" \
        -module-cache-path "${module_cache}" \
        "${sources[@]}" \
        "${frameworks[@]}" \
        -o "${build_dir}/iyh-${architecture}"
done

lipo -create \
    "${build_dir}/iyh-x86_64" \
    "${build_dir}/iyh-arm64" \
    -output "${app_dir}/Contents/MacOS/iyh"

cp "${project_dir}/Resources/Info.plist" "${app_dir}/Contents/Info.plist"
cp "${project_dir}/Resources/AppIcon.icns" "${app_dir}/Contents/Resources/AppIcon.icns"
print -n 'APPL????' > "${app_dir}/Contents/PkgInfo"

codesign --force --sign - --timestamp=none "${app_dir}"
"${app_dir}/Contents/MacOS/iyh" --self-test

print "Built ${app_dir}"
