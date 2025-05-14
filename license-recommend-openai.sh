#!/bin/bash

CSV_INPUT="repos.csv"
CSV_OUTPUT="license-repo-openai.csv"
MODEL="gpt-4"
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

  prompt="You are an expert in open-source licensing.

   Given the open-source repository \"$repo_name\" hosted at \"$repo_url\", recommend the most suitable license based on:

   1. Community engagement — fostering contributions and adoption.
   2. Commercial differentiation — protecting business interests.

   Choose strictly ONE license: MIT, MPL-2.0, or BUSL.

   Respond ONLY with the license name (MIT, MPL-2.0, or BUSL) — no explanation, no formatting."

  response=$(curl -s https://api.openai.com/v1/chat/completions \
                  -H "Authorization: Bearer $OPENAI_API_KEY" \
                  -H "Content-Type: application/json" \
                  -d "$(jq -nc \
                        --arg model "$MODEL" \
                        --arg prompt "$prompt" \
                        '{
                          model: "$MODEL",
                          messages: [
                            {"role": "user", "content": "$prompt"}
                          ],
                          temperature: 0,
                          max_tokens: 100
                         }')"
)
  
   echo "$response" | jq -r '.choices[0].message.content' >&2
  
  license=$(echo "$response" | jq -r '.choices[0].message.content' | grep -iEo 'MPL-2\.0|BUSL|MIT' | head -n1)

  if [[ -z "$license" || "$license" == "null" ]]; then
      license="No license"
  fi

  echo "$repo_name,$repo_url,$license" >> "$CSV_OUTPUT"
  echo "Processed: $repo_name"

  sleep "$RATE_LIMIT_DELAY"
done

echo "All done. Results saved to: $CSV_OUTPUT"