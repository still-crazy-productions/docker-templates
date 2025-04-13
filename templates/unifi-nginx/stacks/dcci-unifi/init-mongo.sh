#!/bin/bash

set -e

if which mongosh > /dev/null 2>&1; then
  mongo_init_bin='mongosh'
else
  mongo_init_bin='mongo'
fi

"${mongo_init_bin}" <<EOF
use admin
db.auth("root", "EnwrzB1EmnyjVW61GXJlkDXPqb8B9XpKDO8Ib949shLQIE0h")
db.createUser({
  user: "unifi",
  pwd: "C4mbhbTvrakqKfF9Kb5n41VKmcN9ImqxKQauw2vBNs8jiteZ",
  roles: [
    { db: "unifi", role: "dbOwner" },
    { db: "unifi_stat", role: "dbOwner" }
  ]
})