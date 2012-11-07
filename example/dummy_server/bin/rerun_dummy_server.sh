#!/bin/sh
patterns='{config.ru,**/*.{rb}}'

bundle exec rerun --pattern $patterns -- \
rackup --port 7080 config.ru -E ${RACK_ENV:-development} -O "rerun_dummy_server"
