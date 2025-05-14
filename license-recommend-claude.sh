#!/bin/bash

CSV_INPUT="repos.csv"
CSV_OUTPUT="license-repo.csv"
MODEL="claude-3-5-sonnet-20241022"
RATE_LIMIT_DELAY=13

if [[ ! -f "$CSV_INPUT" ]]; then
    echo "Error: CSV file not found."
    exit 1
fi

echo "Repository,Repository_url,AI_Recommended_License","Reason" > "$CSV_OUTPUT"

tail -n +2 "$CSV_INPUT" | while IFS=',' read -r repo_name repo_url; do
  repo_name=$(echo "$repo_name" | xargs)
  repo_url=$(echo "$repo_url" | xargs)
  if [[ -z "$repo_name" || -z "$repo_url" ]]; then
      echo "Skipping invalid row: $repo_name | $repo_url"
      continue
  fi

  prompt="Given an OSS Repository named '${repo_name}' with URL '${repo_url}', based on community engagement and commercial differentiation, recommend a license from the following: MIT, MPL-2.0, or BUSL.
  Respond with:
  <license>
  <short reason>
  Where:
  - <license> is one of: MIT, MPL-2.0, or BUSL (no formatting).
  - <short reason> is a brief sentence explaining why this license is suitable."

  response=$(curl -s https://api.anthropic.com/v1/messages \
                  -H "x-api-key: $API_KEY"\
                  -H "anthropic-version: 2023-06-01" \
                  -H "Content-Type: application/json" \
                  -d @- <<EOF
                  {
                    "model": "$MODEL",
                    "max_tokens": 1024,
                    "messages": [
                      {"role": "user", "content": "$prompt"}
                    ]
                  }
EOF
)
  echo "Response: $response" >&2 
  full_text=$(echo "$response" | jq -r '.content[0].text')
  license=$(echo "$full_text" | grep -oE '\b(MIT|BUSL|MPL-2\.0)\b' | head -n1)
  reason=$(echo "$full_text" | sed -n '2p' | xargs)

  if [[ -z "$license" || "$license" == "null" ]]; then
      license="No license"
  fi

  if [[ -z "$reason" || "$reason" == "null" ]]; then
      reason="No reason provided"
  fi

  echo "$repo_name,$repo_url,$license,\"$reason\"" >> "$CSV_OUTPUT"
  echo "Processed: $repo_name"

  sleep "$RATE_LIMIT_DELAY"
done

echo "All done. Results saved to: $CSV_OUTPUT"