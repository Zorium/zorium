#!/bin/bash
set -e
COMMAND="$1"
shift 1
if [ -z $COMMAND ]; then
  echo "Missing COMMAND"
  exit 1
fi

case $COMMAND in
  report-coverage)
    istanbul report text
    istanbul report html
    echo "file://$(pwd)/coverage/index.html"
  ;;
  test-server)
    COFFEECOV_INIT_ALL=false mocha --timeout 300 --require coffeescript/register --require coffee-coverage/register-istanbul test/zorium_server.coffee
  ;;
  watch-server)
    mocha -w --watch-extensions coffee --timeout 300 --require coffeescript/register test/zorium_server.coffee
  ;;
  test-browser)
    ALL_BROWSERS=1 karma start
  ;;
  watch-browser)
    WATCH=1 karma start
  ;;
  *)
    echo "Error, unknown command $COMMAND" >&2
    exit 1
  ;;
esac
