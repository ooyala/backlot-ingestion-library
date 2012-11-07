#!/bin/sh
patterns='{config.ru,**/*.{rb}}'

bundle exec rerun --pattern $patterns -- \
rackup --port 7081 config.ru -E ${RACK_ENV:-development} -O "rerun_uploader_server"
