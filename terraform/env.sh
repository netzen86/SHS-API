#!/bin/sh

# env.sh

# Change the contents of this output to get the environment variables
# of interest. The output must be valid JSON, with strings for both
# keys and values.
cat <<EOF
{
  "POSTGRES_DB": "$POSTGRES_DB",
  "POSTGRES_USER": "$POSTGRES_USER",
  "POSTGRES_PASSWORD": "$POSTGRES_PASSWORD",
  "fullchain": "$fullchain",
  "privkey": "$privkey"
}
EOF