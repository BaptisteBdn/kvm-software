#!/bin/bash
curl -X POST -H 'Content-Type: application/json' -H 'X-Secret: xxxxxxx' -d '{"to": "guest"}' http://ip-api:5001/switch > /dev/null 2>&1
