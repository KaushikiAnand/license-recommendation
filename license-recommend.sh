#!/bin/bash

CSV_INPUT="repos.csv"
CSV_OUTPUT="license-repo.csv"
MODEL="claude-3-5-sonnet-20241022"
RATE_LIMIT_DELAY=2

if [[ ! -f "$CSV_INPUT" ]]; then
    echo "Error: CSV file not found."
    exit 1
fi

echo "Repository,Repository_url,AI_Recommended_License" > "$CSV_OUTPUT"

tail -n +2 "$CSV_INPUT" | while IFS=',' read -r repo_name repo_url; do
  repo_name=$(echo "$repo_name" | xargs)
  repo_url=$(echo "$repo_url" | xargs)
  if [[ -z "$repo_name" || -z "$repo_url" ]]; then
      echo "Skipping invalid row: $repo_name | $repo_url"
      continue
  fi

  prompt="Given an OSS Repository named '${repo_name}' with url '${repo_url}', based on Community engagement and Commercial differentiation recommend a license which should be used for the repo '${repo_name}'. You have to recommend the license as MIT or MPL-2.0 or BUSL, if none of then can be used return the value as No license."

  response=$(curl -s https://api.anthropic.com/v1/messages \
                  -H "x-api-key: $API_KEY"\
                  -H "anthropic-version: 2023-06-01" \
                  -H "Content-Type: application/json" \
                  -d @- <<EOF
                  {
                    "model": "$MODEL",
                    "messages": [
                      {"role": "user", "content": "$prompt"}
                    ]
                  }
EOF
)

  license=$(echo "$response" | jq -r '.content[0].text' | tr '\n' ' ' | sed 's/,//g')

  if [[ -z "$license" || "$license" == "null" ]]; then
      license="No license"
  fi

  echo "$repo_name,$repo_url,$license" >> "$CSV_OUTPUT"
  echo "Processed: $repo_name"

  sleep "$RATE_LIMIT_DELAY"
done

echo "All done. Results saved to: $CSV_OUTPUT"