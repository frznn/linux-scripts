#!/bin/bash

# Check repo argument
if [ "$#" -lt 2 ]; then
    echo "USAGE: $0 ORG REPO_NAME TOKEN"
    return
fi

# Set organization name and GitHub API token
ORG="$1"
REPO="$2"
TOKEN="$3"

# Request
URL="https://api.github.com/repos/$ORG/$REPO/commits"
#TODO: if TOKEN != ""  then add "-H \"Authorization: Bearer $TOKEN\"\ " 
H=" -H \"Accept: application/vnd.github+json\" \
  -H \"Authorization: Bearer $TOKEN\"\ 
  -H \"X-GitHub-Api-Version: 2022-11-28\""

response=$(curl -s -L --include $H $URL)

# Remove the first line ("HTTP/2 200") from the output
response=$(echo "$response" | sed '1d')

# Split the output into header and json
header=$(echo "$response" | awk 'BEGIN{RS="\r\n";ORS="\r\n"} /^[a-zA-Z0-9-]+:/')
commits=$(echo "$response" | awk '!/^[a-zA-Z0-9-]+:/')

echo $response > out
echo $header > header

# If paginated, get last page
if [[ $header == *"link"* ]]; then
  # Extract the last page value
  link_line=$(echo "$header" | grep -i "^link:")
  last_page=$(echo "$link_line" | sed -n 's/.*page=\([0-9]\+\)[^0-9].*rel="last".*/\1/p')

  # Get last-page commits
  commits=$(curl -s -L $H $URL?page=$last_page)
fi

# Print first commit's author
echo $commits | jq '.[-1].commit.author.name'

return
