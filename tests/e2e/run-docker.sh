#!/usr/bin/env bash
# Starts the official Nextcloud Docker image, installs the app from this checkout
# and runs the end-to-end test against it. The container is removed afterwards.
#
# usage: tests/e2e/run-docker.sh <image tag, e.g. 35 or latest> [port]
#
# 7-Zip is installed in the container, it extracts everything but zip and rar.
# Set FORCE_ENABLE=1 to enable the app on a Nextcloud version newer than max-version in info.xml.
set -euo pipefail
TAG=${1:?usage: $0 <image tag, e.g. 35 or latest> [port]}
PORT=${2:-8080}
APP_DIR=$(cd "$(dirname "$0")/../.." && pwd)
CONTAINER=extract-e2e-$TAG
IMAGE=nextcloud:$TAG-apache
if [ "$TAG" = latest ]; then
	IMAGE=nextcloud:apache
fi

docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
trap 'docker rm -f "$CONTAINER" >/dev/null 2>&1 || true' EXIT

docker run -d --name "$CONTAINER" -p "127.0.0.1:$PORT:80" \
	-e SQLITE_DATABASE=nextcloud \
	-e NEXTCLOUD_ADMIN_USER=admin \
	-e NEXTCLOUD_ADMIN_PASSWORD="$(head -c 24 /dev/urandom | base64)" \
	-e NEXTCLOUD_TRUSTED_DOMAINS=localhost \
	"$IMAGE" >/dev/null

echo "Installing 7-Zip..."
docker exec "$CONTAINER" sh -c 'apt-get update -qq && apt-get install -y -qq p7zip-full >/dev/null' ||
	echo "Could not install 7-Zip, only the zip tests run" >&2

echo "Waiting for Nextcloud ($TAG) to be installed..."
for _ in $(seq 1 120); do
	if curl -s "http://localhost:$PORT/status.php" | grep -q '"installed":true'; then
		break
	fi
	sleep 2
done
curl -s "http://localhost:$PORT/status.php" | grep -q '"installed":true' || { docker logs "$CONTAINER" | tail -20; exit 1; }

# COPYFILE_DISABLE keeps macOS tar from adding ._ files, which Nextcloud would load as classes
docker exec "$CONTAINER" mkdir -p /var/www/html/custom_apps/extract
COPYFILE_DISABLE=1 tar -C "$APP_DIR" -cf - appinfo css img js l10n lib templates |
	docker exec -i "$CONTAINER" tar -C /var/www/html/custom_apps/extract -xf - 2>/dev/null
docker exec "$CONTAINER" chown -R www-data:www-data /var/www/html/custom_apps/extract
docker exec -u www-data "$CONTAINER" php occ app:enable ${FORCE_ENABLE:+--force} extract

# The web server can answer 404 for a short while until it knows the routes of the new app
for _ in $(seq 1 30); do
	code=$(curl -s -o /dev/null -w '%{http_code}' -H 'Accept: application/json' -X POST "http://localhost:$PORT/index.php/apps/extract/ajax/extract.php")
	[ "$code" = 401 ] && break
	sleep 1
done

status=0
"$APP_DIR/tests/e2e/e2e.sh" "http://localhost:$PORT" docker "$CONTAINER" || status=$?

echo "== Nextcloud log (warnings and errors)"
log=$(docker exec "$CONTAINER" sh -c 'cat /var/www/html/data/nextcloud.log 2>/dev/null' || true)
echo "$log"

# Requests the test makes to be refused are logged as info, below the default log level.
# Any error in the log, such as an uncaught exception, fails the run, and so does a PHP
# warning in the code of this app.
unexpected=$(echo "$log" | python3 -c 'import json,sys
for line in sys.stdin:
    try:
        entry = json.loads(line)
    except ValueError:
        continue
    if entry.get("level", 0) >= 3 or (entry.get("level") == 2 and "/custom_apps/extract/" in entry.get("message", "")):
        print(entry["message"][:300])')
if [ -n "$unexpected" ]; then
	echo "== Unexpected errors in the Nextcloud log"
	echo "$unexpected"
	status=1
fi
exit $status
