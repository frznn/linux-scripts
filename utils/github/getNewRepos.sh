#!/bin/bash

# Check repo argument
if [ "$#" -lt 2 ]; then
  echo "USAGE: $0 ORG TOKEN [NUM_REPOS]"
  exit 1
fi

# Set organization name and GitHub API token
ORG="$1"
TOKEN=$2
NUM_REPOS="$3"

URL="https://api.github.com/orgs/$ORG/repos?sort=created_at\&per_page=$NUM_REPOS"

H="-H \"Accept: application/vnd.github+json\" \
  -H \"Authorization: Bearer $TOKEN\"\ 
  -H \"X-GitHub-Api-Version: 2022-11-28\""

# response=$(curl -s -L $H $URL)

H="-H \"Accept: application/vnd.github+json\"   -H \"Authorization: Bearer $TOKEN\"  -H \"X-GitHub-Api-Version: 2022-11-28\" "
H1="-H \"Accept: application/vnd.github+json\""
# Using H2 doesn't work, probably due to $TOKEN not being replaced correctly in the string
#H2="-H \"Authorization: Bearer $TOKEN\""

H3="-H "X-GitHub-Api-Version: 2022-11-28""

response=$(curl -s -L $H1 -H "Authorization: Bearer $TOKEN" $H3 $URL)
# echo $response | jq '.[].name'
echo $response | jq '.[].name'


