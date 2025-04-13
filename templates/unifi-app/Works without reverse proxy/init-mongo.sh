#!/bin/bash

if which mongosh > /dev/null 2>&1; then
  mongo_init_bin='mongosh'
else
  mongo_init_bin='mongo'
fi
"${mongo_init_bin}" <<EOF
use admin
db.auth("root", "6sGnqUU9xoNUOdJecpDCVrMSC6GbKOkIQKOzCxzFoi4M6W64")
db.createUser({
  user: "unifi",
  pwd: "VJAyzw18q8nn6WfCefFqDTVQXvKaEabISuMMgA60G4EeO3fi",
  roles: [
    { db: "unifi", role: "dbOwner" },
    { db: "unifi_stat", role: "dbOwner" }
  ]
})
EOF