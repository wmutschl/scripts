#!/bin/bash
# Raspberry Pi 4 Model B: write Home Assistant OS to an SD card on macOS, then read it back.
#
# Takes the image and its SHA-256 sums from the metadata that Raspberry Pi Imager uses
# (version.home-assistant.io/rpi-imager-haos.json), checks the download
# and the decompressed image, writes the card with dd and verifies what landed on it.
# The first MiB (MBR and GPT) goes on last, so macOS sees no partitions,
# and mounts none, until the rest of the card is verified.
#
# Needs xz (brew install xz) and jq (part of macOS 15 and later).
# Usage: ./flash-haos.sh diskN        # find diskN with: diskutil list external physical
set -euo pipefail

board=rpi4-64
metadata_url=https://version.home-assistant.io/rpi-imager-haos.json
cache_dir="$HOME/Library/Caches/flash-haos"
mib=1048576

die() { echo "Error: $*" >&2; exit 1; }
sha256() { shasum -a 256 "$@" | cut -d ' ' -f 1; }
disk_info() { diskutil info -plist "/dev/$disk" | plutil -extract "$1" raw -o - -; }

[ "$(uname -s)" = Darwin ] || die "this script is for macOS; elsewhere use Raspberry Pi Imager"
if [ $# -ne 1 ] || ! [[ ${1#/dev/} =~ ^disk[0-9]+$ ]]; then
  echo "Usage: $0 diskN" >&2
  echo "External disks on this Mac:" >&2
  diskutil list external physical >&2
  exit 2
fi
disk=${1#/dev/}
raw=/dev/r$disk
command -v xz >/dev/null || die "xz not found; install it with: brew install xz"
command -v jq >/dev/null || die "jq not found; install it with: brew install jq"

# Current image for the board, as offered by Raspberry Pi Imager
metadata=$(curl -fsSL "$metadata_url") || die "cannot download $metadata_url"
entry=$(jq -ce --arg board "$board" \
  '[.os_list[] | select(.url | test("/haos_" + $board + "-[^/]+[.]img[.]xz$"))] | first' \
  <<<"$metadata") || die "no $board image listed in $metadata_url"
name=$(jq -r .name <<<"$entry")
url=$(jq -r .url <<<"$entry")
xz_sha=$(jq -r .image_download_sha256 <<<"$entry")
img_sha=$(jq -r .extract_sha256 <<<"$entry")
img_size=$(jq -r .extract_size <<<"$entry")
[[ $xz_sha =~ ^[0-9a-f]{64}$ && $img_sha =~ ^[0-9a-f]{64}$ ]] || die "metadata lacks SHA-256 sums"
[[ $img_size =~ ^[0-9]+$ ]] && [ "$img_size" -gt "$mib" ] && [ $((img_size % 512)) -eq 0 ] \
  || die "unexpected image size in metadata: $img_size"

# Download once, keep it for the next card, drop older versions
mkdir -p "$cache_dir"
xz_file=$cache_dir/${url##*/}
if [ -f "$xz_file" ] && [ "$(sha256 "$xz_file")" = "$xz_sha" ]; then
  echo "Using $xz_file"
else
  echo "Downloading $name"
  curl -fL --retry 3 --progress-bar -o "$xz_file.part" "$url"
  mv "$xz_file.part" "$xz_file"
  [ "$(sha256 "$xz_file")" = "$xz_sha" ] || { rm -f "$xz_file"; die "SHA-256 of the download does not match"; }
  find "$cache_dir" -name "haos_$board-*.img.xz" ! -name "${xz_file##*/}" -delete
fi

work=$(mktemp -d "${TMPDIR:-/tmp}/flash-haos.XXXXXX")
trap 'rm -rf "$work"' EXIT
img=$work/$(basename "$xz_file" .xz)
echo "Decompressing and checking the image"
xz -dc "$xz_file" >"$img"
[ "$(stat -f %z "$img")" = "$img_size" ] || die "decompressed image has the wrong size"
[ "$(sha256 "$img")" = "$img_sha" ] || die "SHA-256 of the decompressed image does not match"

# Only a whole, external or removable, physical disk: not the boot disk, no Mac partitions, at most 2 TiB
diskutil info "/dev/$disk" >/dev/null 2>&1 || die "/dev/$disk does not exist"
[ "$(disk_info WholeDisk)" = true ] || die "$disk is not a whole disk"
[ "$(disk_info RemovableMediaOrExternalDevice)" = true ] || die "$disk is neither external nor removable"
[ "$(disk_info VirtualOrPhysical)" != Virtual ] || die "$disk is a virtual disk"
[ "$(disk_info Writable)" = true ] || die "$disk is write-protected"
boot_store=$(diskutil info -plist / | plutil -extract APFSPhysicalStores.0.APFSPhysicalStore raw -o - - 2>/dev/null || true)
if [ -n "$boot_store" ]; then
  [ "$(diskutil info -plist "$boot_store" | plutil -extract ParentWholeDisk raw -o - -)" != "$disk" ] \
    || die "$disk holds the running macOS"
fi
diskutil list -plist "/dev/$disk" | plutil -convert json -o - - \
  | jq -e '[.. | .Content? | strings | select(startswith("Apple_"))] | length == 0' >/dev/null \
  || die "$disk holds APFS or HFS+ partitions, so it is a Mac disk and not the card"
size=$(disk_info TotalSize)
[ "$size" -ge "$img_size" ] || die "$disk is smaller than the image"
[ "$size" -le 2199023255552 ] || die "$disk is larger than 2 TiB, so it is not an SD card"

echo
diskutil list "/dev/$disk"
echo "This ERASES /dev/$disk ($(disk_info MediaName), $(awk -v s="$size" 'BEGIN { printf "%.1f", s / 1e9 }') GB) and writes $name."
read -r -p "Type $disk to continue: " answer
[ "$answer" = "$disk" ] || die "aborted, nothing was written"

sudo -v
diskutil unmountDisk "/dev/$disk"
# Blank the partition tables first, then write everything after them
sudo dd if=/dev/zero of="$raw" bs=1m count=1 status=none
sudo dd if="$img" of="$raw" bs=1m iseek=1 oseek=1 status=progress

echo "Reading the card back"
full=$((img_size / mib - 1))          # whole MiBs after the first one
rest=$((img_size % mib / 512))        # remaining 512-byte sectors
card_sha=$({
  sudo dd if="$raw" bs=1m iseek=1 count="$full" status=none &&
  if [ "$rest" -gt 0 ]; then
    sudo dd if="$raw" bs=512 iseek=$(((full + 1) * 2048)) count="$rest" status=none
  fi
} | sha256) || die "reading the card failed"
[ "$card_sha" = "$(dd if="$img" bs=1m iseek=1 status=none | sha256)" ] \
  || die "the card does not hold what was written; try another card or card reader"

# Now the partition tables, which make the partitions visible to macOS
sudo dd if="$img" of="$raw" bs=1m count=1 status=none
[ "$(sudo dd if="$raw" bs=1m count=1 status=none | sha256)" = "$(dd if="$img" bs=1m count=1 status=none | sha256)" ] \
  || die "the partition tables on the card do not match the image"

diskutil eject "/dev/$disk" || echo "Eject the card in Finder before you remove it."
echo "Done: $name is on the card and verified."
