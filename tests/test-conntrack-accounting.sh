#!/bin/sh
# Safe fixture test: no real sysctl or firewall changes.
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
CONFFILE="$work/config"
: > "$CONFFILE"
# Redirect only the availability probe to a fixture.
sed "s|/proc/sys/net/netfilter/nf_conntrack_acct|$work/acct|g" "$repo/etc/init.d/common" > "$work/common"
. "$work/common"
sysctl() {
  printf '%s\n' "$*" >> "$work/calls"
  case "$*" in
    *nf_conntrack_acct*) return "$acct_rc" ;;
  esac
}
for mode in missing present failed; do
  rm -f "$work/acct"
  : > "$work/calls"
  acct_rc=0
  [ "$mode" = missing ] || : > "$work/acct"
  [ "$mode" != failed ] || acct_rc=1
  system_config 2> "$work/error"
  if [ "$mode" = missing ]; then
    ! grep -q nf_conntrack_acct "$work/calls"
  else
    grep -qx -- '-w net.netfilter.nf_conntrack_acct=1' "$work/calls"
  fi
  if [ "$mode" = failed ]; then
    grep -q 'Failed to enable conntrack accounting' "$work/error"
  else
    test ! -s "$work/error"
  fi
  grep -qx -- '-w net.netfilter.nf_conntrack_checksum=0' "$work/calls"
  grep -qx -- '-w net.netfilter.nf_conntrack_tcp_be_liberal=1' "$work/calls"
done
printf '%s\n' 'Conntrack accounting checks passed'
