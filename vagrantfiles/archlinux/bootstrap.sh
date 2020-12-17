#!/bin/bash

echo "[TASK 1] Create venkatn user account"
useradd -m -c "Venkat Nagappan" venkatn
echo -e "admin\nadmin" | passwd venkatn >/dev/null 2>&1