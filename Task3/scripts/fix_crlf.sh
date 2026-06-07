#!/bin/bash
for f in /mnt/d/NSU_FIT_3rd_course/Bioinformatic/Task3/scripts/*.sh; do
  tr -d '\r' < "$f" > "${f}.tmp"
  mv "${f}.tmp" "$f"
  chmod +x "$f"
done
