#!/bin/bash

CSV_INPUT="repos.csv"
CSV_OUTPUT="license-repo-openai.csv"
MODEL="gpt-3.5-turbo"
RATE_LIMIT_DELAY=20

if [[ ! -f "$CSV_INPUT" ]]; then
    echo "Error: CSV file not found."
    exit 1
fi

echo "Repository,Repository_url,AI_Recommended_License,Reason" > "$CSV_OUTPUT"

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
   Respond ONLY with the license name and a short one-sentence reason. Format it like this (no bullet points, no markdown):
   LICENSE: <MIT|MPL-2.0|BUSL>
   REASON: <brief reason>"

  response=$(curl -s https://api.openai.com/v1/chat/completions \
                  -H "Authorization: Bearer $OPENAI_API_KEY" \
                  -H "Content-Type: application/json" \
                  -d "$(jq -nc \
                        --arg model "$MODEL" \
                        --arg prompt "$prompt" \
                        '{
                          model: $model,
                          messages: [
                            {"role": "user", "content": $prompt}
                          ],
                          temperature: 0.3,
                          max_tokens: 150
                         }')"
)
  
  content=$(echo "$response" | jq -r '.choices[0].message.content // empty')

  license=$(echo "$content" | grep -iEo 'LICENSE: *(MIT|MPL-2\.0|BUSL)' | grep -iEo 'MIT|MPL-2\.0|BUSL' | head -n1)
  reason=$(echo "$content" | grep -i '^REASON:' | sed 's/^REASON:[ ]*//')

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