#!/data/data/com.termux/files/usr/bin/bash
#
# One-command G2 dump from Termux.
#
#   pkg install -y curl
#   curl -fsSLO https://raw.githubusercontent.com/kaicia/retroid-g2-linux/refs/heads/BRANCH/scripts/termux-bootstrap.sh
#   less termux-bootstrap.sh        # read it before running it
#   bash termux-bootstrap.sh
#
# It installs what is missing, clones or updates the repository, collects the
# read-only G2 dump, commits it and pushes it. Safe to re-run.
#
# The collector it invokes is STRICTLY READ-ONLY on the G2: no flash, erase,
# format, repartition, slot switch, AVB or firmware operation, and no
# block-device content is read. See the header of
# scripts/run-g2-consolidated-hardware-dump-readonly-v2.sh.
#
# Overridable:
#   G2_REF     branch to use          (default: the branch below)
#   G2_REPO    checkout path          (default: $HOME/retroid-g2-linux)
#   G2_REMOTE  clone URL              (default: the HTTPS URL below)
set -u

G2_REF="${G2_REF:-claude/content-analysis-04z778}"
G2_REPO="${G2_REPO:-$HOME/retroid-g2-linux}"
G2_REMOTE="${G2_REMOTE:-https://github.com/kaicia/retroid-g2-linux.git}"
COLLECTOR="scripts/run-g2-consolidated-hardware-dump-readonly-v2.sh"

say(){ echo; echo "==> $*"; }
die(){ echo; echo "ERROR: $*" >&2; exit 1; }

say "G2 dump bootstrap"
echo "    ref    : $G2_REF"
echo "    repo   : $G2_REPO"
echo "    remote : $G2_REMOTE"

# ---------------------------------------------------------------- 1. Termux
if [ -z "${PREFIX:-}" ] || [ ! -d "${PREFIX:-/nonexistent}" ]; then
  die "this does not look like Termux (\$PREFIX is not set).
       Run it inside Termux on the phone that the G2 is plugged into."
fi

# ------------------------------------------------------------ 2. dependencies
say "checking packages"
need_pkg=""
for c in git tar curl; do
  command -v "$c" >/dev/null 2>&1 || need_pkg="$need_pkg $c"
done
command -v fakeroot >/dev/null 2>&1 || need_pkg="$need_pkg fakeroot"

if [ -n "$need_pkg" ]; then
  echo "    installing:$need_pkg"
  # shellcheck disable=SC2086
  pkg install -y $need_pkg || die "pkg install failed for:$need_pkg"
else
  echo "    all present"
fi

# adb: prefer termux-adb, which reaches USB devices without root.
if command -v termux-adb >/dev/null 2>&1; then
  echo "    adb: termux-adb"
elif command -v adb >/dev/null 2>&1; then
  echo "    adb: adb (plain)"
else
  echo "    adb: missing, installing android-tools"
  pkg install -y android-tools || die "could not install android-tools.
       termux-adb is the better option for USB access but is not in the main
       Termux repository; install it separately if plain adb cannot see the G2."
fi

# ------------------------------------------------------------------ 3. repo
if [ -d "$G2_REPO/.git" ]; then
  say "updating existing checkout"
  git -C "$G2_REPO" remote set-url origin "$G2_REMOTE"
  git -C "$G2_REPO" fetch origin "$G2_REF" || die "fetch failed"
else
  say "cloning"
  git clone "$G2_REMOTE" "$G2_REPO" || die "clone failed"
  git -C "$G2_REPO" fetch origin "$G2_REF" || die "fetch failed"
fi

say "checking out $G2_REF"
if git -C "$G2_REPO" rev-parse --verify --quiet "refs/heads/$G2_REF" >/dev/null; then
  git -C "$G2_REPO" checkout "$G2_REF" || die "checkout failed"
else
  git -C "$G2_REPO" checkout -b "$G2_REF" --track "origin/$G2_REF" \
    || die "could not create a local branch tracking origin/$G2_REF"
fi

# The collector refuses to run on a dirty tree so the dump lands as its own
# commit. Say so here rather than letting it fail after the device is plugged in.
if ! git -C "$G2_REPO" diff --quiet || ! git -C "$G2_REPO" diff --cached --quiet; then
  echo
  git -C "$G2_REPO" status --short
  die "the checkout has uncommitted changes. Commit or stash them, then re-run."
fi

git -C "$G2_REPO" pull --ff-only origin "$G2_REF" || die "pull --ff-only failed"

[ -f "$G2_REPO/$COLLECTOR" ] || die "$COLLECTOR is not present on $G2_REF.
       Pick a ref that has it, e.g.  G2_REF=main bash termux-bootstrap.sh"

# ------------------------------------------------------------ 4. git identity
if ! git -C "$G2_REPO" config user.email >/dev/null; then
  say "git identity is not set — needed to commit"
  printf '    name  : '; read -r gname
  printf '    email : '; read -r gemail
  [ -n "$gname" ] && [ -n "$gemail" ] || die "both are required"
  git -C "$G2_REPO" config user.name  "$gname"
  git -C "$G2_REPO" config user.email "$gemail"
fi

# ---------------------------------------------------------- 5. push credentials
# Deliberately never handled by this script: git prompts on the first push and
# stores what you type. Nothing secret passes through here or lands in the repo.
case "$G2_REMOTE" in
  https://*)
    if [ -z "$(git -C "$G2_REPO" config --get credential.helper || true)" ]; then
      say "enabling git's credential store for the push"
      echo "    On the first push git will ask for a username and password."
      echo "    The password must be a GitHub Personal Access Token, not your"
      echo "    account password. Create a fine-grained token limited to"
      echo "    kaicia/retroid-g2-linux with Contents: read and write."
      echo
      echo "    It is stored in plain text at ~/.git-credentials. If that is not"
      echo "    acceptable on this phone, stop now and use SSH instead:"
      echo "      G2_REMOTE=git@github.com:kaicia/retroid-g2-linux.git bash termux-bootstrap.sh"
      git -C "$G2_REPO" config credential.helper store
    fi
    ;;
esac

# ------------------------------------------------------------------ 6. device
say "waiting for the G2 over ADB"
echo "    Plug the G2 into this phone and accept the USB debugging prompt"
echo "    on the G2's screen if it appears."
echo

if command -v termux-adb >/dev/null 2>&1; then
  adb_cmd(){ ANDROID_NO_USE_FWMARK_CLIENT=1 fakeroot termux-adb "$@"; }
else
  adb_cmd(){ adb "$@"; }
fi

n=0
until adb_cmd devices 2>/dev/null | awk 'NR>1 && $2=="device" {n++} END{exit !(n==1)}'; do
  n=$((n + 1))
  if [ "$n" -ge 30 ]; then
    echo
    adb_cmd devices 2>/dev/null || true
    die "no single authorized device after ~60s.
       'unauthorized' means the prompt on the G2 has not been accepted.
       An empty list means the cable or termux-adb cannot see it."
  fi
  printf '.'
  sleep 2
done
echo
echo "    device ready:"
adb_cmd devices | sed 's/^/      /'

# ----------------------------------------------------------------- 7. collect
say "collecting (read-only; archiving the device tree may take a minute)"
cd "$G2_REPO" || die "cannot enter $G2_REPO"
G2_REPO="$G2_REPO" bash "$COLLECTOR"
rc=$?

echo
if [ "$rc" -eq 0 ]; then
  say "done — dump committed and pushed to $G2_REF"
  git -C "$G2_REPO" log --oneline -1
  echo
  echo "    Newest artifacts:"
  ls -1t "$G2_REPO/dumps/g2" 2>/dev/null | head -4 | sed 's/^/      /'
else
  say "the collector exited with status $rc"
  echo "    Anything it committed is safe locally in $G2_REPO."
  echo "    If only the push failed:  git -C $G2_REPO push -u origin $G2_REF"
fi
exit "$rc"
