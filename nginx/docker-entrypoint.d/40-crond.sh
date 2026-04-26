#!/bin/sh
# alpine: crond, debian: cron
if command -v crond > /dev/null 2>&1; then
    exec crond -f -l 8
elif command -v cron > /dev/null 2>&1; then
    exec cron -f -l 8
fi
