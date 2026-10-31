#!/bin/zsh
# gl-probe.sh — read-only diagnostics for the Apple TGL GLDriver activation experiment (docs/OPENGL.md).
# Run on the installed macOS (XPS 13 Plus or X13 Yoga), no sudo. Writes gl-probe-report.txt to the
# current directory; paste it back into the issue/chat. Nothing on the system is modified.
# Requires: macOS, Command Line Tools for the cgl-probe build step (xcode-select --install).
set -u
HERE=${0:A:h}
OUT=${PWD}/gl-probe-report.txt
exec > >(tee "$OUT") 2>&1

echo "== gl-probe: $(date) =="
sw_vers
echo "kernel: $(uname -v)"
echo "boot-args: $(nvram boot-args 2>/dev/null || echo '(none readable)')"
echo

echo "== A. kext side (TGL accelerator + HookCase) =="
kmutil showloaded 2>/dev/null | grep -iE "TGL|HookCase|NootedGreen" || echo "  (kmutil showloaded unavailable or no match)"
echo

echo "== B. GLDriver bundles on disk =="
GLB=""
for d in /Library/Extensions /System/Library/Extensions /Library/GPUBundles /System/Library/GPUBundles; do
  find "$d" -maxdepth 2 -name "*GLDriver*.bundle" 2>/dev/null
done | while read -r b; do
  echo "  $b"
  plutil -p "$b/Contents/Info.plist" 2>/dev/null | grep -E "CFBundleIdentifier|CFBundleVersion" | sed 's/^/    /'
done
TGLGL=/Library/Extensions/AppleIntelTGLGraphicsGLDriver.bundle
[[ -d $TGLGL ]] && GLB=$TGLGL
if [[ -n $GLB ]]; then
  echo "  -- IOKitPersonalities of AppleIntelTGLGraphicsGLDriver (its matching rule):"
  plutil -p "$GLB/Contents/Info.plist" 2>/dev/null | sed -n '/IOKitPersonalities/,$p' \
    | grep -E '"=> \{|IOClass|IOProviderClass|IOPCIMatch|IOPCIPrimaryMatch|IONameMatch|IOGLBundle|CFBundleIdentifier' | sed 's/^/    /'
else
  echo "  !! AppleIntelTGLGraphicsGLDriver.bundle not installed (run macos/install-macos.sh)"
fi
echo

echo "== C. accelerator service: does it advertise a GL bundle? =="
ioreg -lw0 -p IOService 2>/dev/null | grep -iE "GLBundle|GLPlugin|IOGL" | head -20 | sed 's/^/  /'
echo "  -- TGL accelerator service properties:"
ioreg -lw0 -p IOService 2>/dev/null | grep -iE "AppleIntelTGL|Gen7" | head -10 | sed 's/^/  /'
echo

echo "== D. how OpenGL.framework selects a GL driver (string scan) =="
OFW=/System/Library/Frameworks/OpenGL.framework/Versions/A/OpenGL
if [[ -f $OFW ]]; then
  # strings(1) needs CLT; grep -ao is the fallback
  scan() { if command -v strings >/dev/null 2>&1; then strings "$OFW" | grep -aE "$1"; else grep -aoE "$2" "$OFW" | grep -aE "$1"; fi; }
  echo "  GLDriver-ish names:"; scan "[A-Za-z0-9_]+GLDriver" "[A-Za-z0-9_]+GLDriver" | sort -u | sed 's/^/    /'
  echo "  bundle path patterns:"; scan "GPUBundles|Library/Extensions|GLDriver" "/[A-Za-z0-9_/.-]+(GPUBundles|GLDriver)[A-Za-z0-9_/.-]*" | sort -u | head -20 | sed 's/^/    /'
  echo "  property-ish names:"; scan "IOGLBundle|GLBundle|IOGLPlugin" "[A-Za-z]*GLBundle[A-Za-z]*|[A-Za-z]*GLPlugin[A-Za-z]*" | sort -u | sed 's/^/    /'
else
  echo "  !! $OFW not found"
fi
echo

echo "== E. cgl-probe (accelerated vs software pixel formats) =="
SRC=$HERE/cgl-probe.c
if ! command -v clang >/dev/null 2>&1; then
  echo "  clang missing: run 'xcode-select --install' and re-run this script"
elif [[ -f $SRC ]]; then
  TMP=$(mktemp -d)
  if clang -framework OpenGL -o "$TMP/cgl-probe" "$SRC" 2>&1 | sed 's/^/  /'; then
    echo "  -- run WITHOUT DYLD filter:"
    DYLD_PRINT_LIBRARIES=1 "$TMP/cgl-probe" 2>&1 | grep -avE "^dyld\[" | sed 's/^/  /'
    echo "  -- dylibs loaded during CGL (GL/TGL/GLDriver lines):"
    DYLD_PRINT_LIBRARIES=1 "$TMP/cgl-probe" 2>&1 | grep -aiE "GLDriver|TGL|OpenGL|IGC|libGL" | sed 's/^/  /'
    "$TMP/cgl-probe" >/dev/null 2>&1; rc=$?
    echo "  cgl-probe exit: $rc (0=accelerated YES, 1=software only, 2=no context)"
  fi
  rm -rf "$TMP"
else
  echo "  !! cgl-probe.c not next to this script ($SRC)"
fi
echo
echo "== done: $OUT =="
