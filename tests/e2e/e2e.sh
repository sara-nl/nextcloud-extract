#!/usr/bin/env bash
# End-to-end test against a running Nextcloud with this app enabled.
#
# usage: tests/e2e/e2e.sh <base_url> docker <container>
#        E2E_PW=<password> tests/e2e/e2e.sh <base_url> ssh <user@host> <nextcloud_path>
#
# Creates the user exttestalice and uploads archives to her folder /exttest, which is deleted
# before and after the run. Checks access to the extract endpoint, that the Files page loads the
# file action, that Nextcloud reports the archives with a mime type the file action is shown
# for, extracting zip, tar, tar.gz, tar.bz2, gz and 7z, and that files with a forbidden name
# are removed from the extracted folder. tar, gz, bz2 and 7z need 7za on the server; without
# it those cases are skipped.
# In ssh mode E2E_PW is required, because the test user would otherwise get a password that
# is public in this repository. Set E2E_CLEANUP=1 to also delete the test user.
# Needs curl and python3.
set -uo pipefail
BASE=$1; MODE=$2; shift 2
if [ "$MODE" = docker ]; then CONTAINER=$1; else HOST=$1; NCPATH=$2; fi

if [ "$MODE" = ssh ] && [ -z "${E2E_PW:-}" ]; then
	echo "Set E2E_PW to a password of your own when testing a server over ssh." >&2
	exit 2
fi
PW=${E2E_PW:-'Ext-e2e-Pw-2026-Qr7!'}
A=exttestalice
DIR=exttest
APP_DIR=$(cd "$(dirname "$0")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

occ() {
	if [ "$MODE" = docker ]; then
		docker exec -e OC_PASS="$PW" -u www-data "$CONTAINER" php occ "$@"
	else
		ssh -o BatchMode=yes "$HOST" "sudo -n -u www-data env OC_PASS=$(printf '%q' "$PW") php $NCPATH/occ $(printf '%q ' "$@")"
	fi
}
on_server() { # runs a shell command on the server
	if [ "$MODE" = docker ]; then
		docker exec "$CONTAINER" sh -c "$1"
	else
		ssh -o BatchMode=yes "$HOST" "$1"
	fi
}
check() { if [ "$2" = "$3" ]; then echo "PASS  $1"; pass=$((pass+1)); else echo "FAIL  $1 (expected '$3', got '$2')"; fail=$((fail+1)); fi; }
skip() { echo "SKIP  $1"; }

dav() { # <method> <path below the user root> [curl args...], prints the http status
	local method=$1 path=$2; shift 2
	curl -s -u "$A:$PW" -X "$method" -o /dev/null -w '%{http_code}' "$@" "$BASE/remote.php/dav/files/$A/$path"
}
dav_get() { curl -s -u "$A:$PW" "$BASE/remote.php/dav/files/$A/$1"; }
# The mime type Nextcloud reports for a file, which the Files app uses to show the action
mime_of() {
	curl -s -u "$A:$PW" -X PROPFIND -H 'Depth: 0' \
		-d '<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:getcontenttype/></d:prop></d:propfind>' \
		"$BASE/remote.php/dav/files/$A/$1" |
		python3 -c 'import sys, xml.etree.ElementTree as ET
try:
    el = ET.fromstring(sys.stdin.read()).find(".//{DAV:}getcontenttype")
    print(el.text if el is not None else "-")
except ET.ParseError:
    print("-")'
}

# Logs in with a session like the browser does, so the request token belongs to it
JAR=$TMP/cookies
TOKEN=
login() {
	TOKEN=$(curl -s -c "$JAR" -b "$JAR" -u "$A:$PW" "$BASE/index.php/csrftoken" |
		python3 -c 'import json,sys
try:
    print(json.load(sys.stdin)["token"])
except Exception:
    print("")')
}
# Calls the extract endpoint like the file action does, prints "<http status> <response as json>"
extract() { # <file name> <mime> [token]
	local token=${3-$TOKEN} body
	body=$(python3 -c 'import json,sys; print(json.dumps({"nameOfFile": sys.argv[1], "directory": "/" + sys.argv[3], "external": 0, "mime": sys.argv[2]}))' "$1" "$2" "$DIR")
	curl -s -c "$JAR" -b "$JAR" -u "$A:$PW" -H 'Accept: application/json' -H 'Content-Type: application/json' \
		${token:+-H "requesttoken: $token"} -X POST -d "$body" -w '\n%{http_code}' \
		"$BASE/index.php/apps/extract/ajax/extract.php" |
		python3 -c 'import json,sys
body, status = sys.stdin.read().rsplit("\n", 1)
try:
    data = json.loads(body)
except Exception:
    data = None
print(status + " " + json.dumps(data))'
}
status() { echo "${1%% *}"; }
# Evaluates a Python expression on the data of a response (as d), "-" when it fails
get() {
	python3 -c 'import json,sys
d = json.loads(sys.argv[1].split(" ", 1)[1])
try:
    r = eval(sys.argv[2])
except Exception:
    r = "-"
print("yes" if r is True else "no" if r is False else r)' "$1" "$2"
}

# Mime types the file action in the Files app is shown for
SUPPORTED_MIMES=$(python3 -c 'import re,sys
src = open(sys.argv[1]).read()
block = re.search(r"SUPPORTED_MIMES = \[(.*?)\]", src, re.S).group(1)
print(" ".join(re.findall(r"\x27([^\x27]+)\x27", block)))' "$APP_DIR/src/actions/extract-action.ts")

is_supported() {
	case " $SUPPORTED_MIMES " in
		*" $1 "*) echo yes ;;
		*) echo no ;;
	esac
}
# Names in a folder, sorted and comma separated
list() {
	curl -s -u "$A:$PW" -X PROPFIND -H 'Depth: 1' "$BASE/remote.php/dav/files/$A/$1" |
		python3 -c 'import sys, urllib.parse, xml.etree.ElementTree as ET
try:
    hrefs = [h.text for h in ET.fromstring(sys.stdin.read()).iter("{DAV:}href")][1:]
    print(",".join(sorted(urllib.parse.unquote(h.rstrip("/").rsplit("/", 1)[1]) for h in hrefs)))
except ET.ParseError:
    print("-")'
}

echo "== Setup"
occ user:info $A >/dev/null 2>&1 || occ user:add --password-from-env $A >/dev/null
occ user:resetpassword --password-from-env $A >/dev/null
dav DELETE "$DIR" >/dev/null
check "create test folder" "$(dav MKCOL "$DIR")" 201
HAS_7ZA=no
on_server 'command -v 7za' >/dev/null 2>&1 && HAS_7ZA=yes

# Every archive holds top.txt and sub/nested.txt
python3 - "$TMP" <<'EOF'
import bz2, gzip, io, os, sys, tarfile, zipfile
tmp = sys.argv[1]
files = {"top.txt": b"top level\n", "sub/nested.txt": b"nested file\n"}
with zipfile.ZipFile(os.path.join(tmp, "data.zip"), "w") as z:
    for name, data in files.items():
        z.writestr(name, data)
    # A name Nextcloud forbids, the app has to remove it after extracting
    z.writestr(".htaccess", b"Deny from all\n")
for name, mode in (("plain.tar", "w"), ("targz.tar.gz", "w:gz"), ("data2.tar.bz2", "w:bz2")):
    with tarfile.open(os.path.join(tmp, name), mode) as t:
        for fname, data in files.items():
            info = tarfile.TarInfo(fname)
            info.size = len(data)
            t.addfile(info, io.BytesIO(data))
with gzip.open(os.path.join(tmp, "single.txt.gz"), "wb") as g:
    g.write(b"single file\n")
EOF

echo "== Access"
code=$(curl -s -o /dev/null -w '%{http_code}' -H 'Accept: application/json' -H 'Content-Type: application/json' \
	-X POST -d '{}' "$BASE/index.php/apps/extract/ajax/extract.php")
check "anonymous request is refused" "$code" 401
login
check "got a request token" "$([ -n "$TOKEN" ] && echo yes || echo no)" yes
check "request without request token is refused" "$(status "$(extract data.zip application/zip '')")" 412
files_page=$(curl -s -c "$JAR" -b "$JAR" -u "$A:$PW" "$BASE/index.php/apps/files/")
check "Files page loads the init script" "$(echo "$files_page" | grep -q 'extract/js/extract-init' && echo yes || echo no)" yes
check "Files page loads the file action" "$(echo "$files_page" | grep -q 'extract/js/extract-extractAction' && echo yes || echo no)" yes

# <archive> <folder it extracts to> <file inside the folder> <expected content> [needs 7za]
test_archive() {
	local archive=$1 folder=$2 inner=$3 content=$4 needs7za=${5:-} mime r
	echo "== $archive"
	if [ "$needs7za" = 7za ] && [ "$HAS_7ZA" = no ]; then
		skip "$archive: 7za is not installed on the server"
		return
	fi
	if [ "$archive" = data7.7z ]; then
		# Python cannot write 7z, so make it on the server
		on_server 'd=$(mktemp -d) && cd "$d" && printf "top level\n" > top.txt && mkdir sub &&
			printf "nested file\n" > sub/nested.txt && 7za a -bd x.7z top.txt sub >/dev/null && cat x.7z; rm -rf "$d"' > "$TMP/$archive"
	fi
	check "$archive: upload" "$(dav PUT "$DIR/$archive" --data-binary "@$TMP/$archive")" 201
	mime=$(mime_of "$DIR/$archive")
	check "$archive: file action is shown for its mime type ($mime)" "$(is_supported "$mime")" yes
	r=$(extract "$archive" "$mime")
	check "$archive: extract" "$(status "$r")" 200
	check "$archive: reports success" "$(get "$r" "bool(d['code'])")" yes
	check "$archive: returns the extracted folder" "$(get "$r" "isinstance(d['extracted']['fileId'], int) and d['extracted']['source'].endswith('/$DIR/$folder')")" yes
	check "$archive: $inner is extracted" "$(dav_get "$DIR/$folder/$inner")" "$content"
}

test_archive data.zip data sub/nested.txt "nested file"
# Without .htaccess, which Nextcloud forbids
check "data.zip: forbidden file .htaccess is removed" "$(list "$DIR/data")" "sub,top.txt"
test_archive plain.tar plain top.txt "top level" 7za
test_archive targz.tar.gz targz top.txt "top level" 7za
check "targz.tar.gz: intermediate .tar is removed" "$(list "$DIR/targz")" "sub,top.txt"
test_archive data2.tar.bz2 data2 sub/nested.txt "nested file" 7za
test_archive single.txt.gz single.txt single.txt "single file" 7za
test_archive data7.7z data7 top.txt "top level" 7za

echo "== Cleanup"
dav DELETE "$DIR" >/dev/null
if [ "${E2E_CLEANUP:-}" = 1 ] || [ "$MODE" = docker ]; then
	occ user:delete $A >/dev/null
fi

echo
echo "$pass passed, $fail failed"
[ "$fail" = 0 ]
