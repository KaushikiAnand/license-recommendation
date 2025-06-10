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

  prompt="You are a HashiCorp licensing specialist. Below is the metadata and a README excerpt for the repository \"$repo_url\".
  === METADATA ===
  • Repository: \"$repo_url\"
  === END METADATA ===
  Using the following **three judgment criteria**, provide a concise (max 200 words) recommendation on whether **this repository's license should**:
    1. Remain under MPL.
    2. Be moved to BUSL.
    3. Or be flagged for legal review.
  **Judgment Criteria**:
    1. Standalone Utility:
       - Does the repo deliver valuable functionality on its own?
       - Look for API presence, “getting started” instructions, or standalone CLI usage.
    2. Commercial Value:
       - Would a competitor gain a tangible advantage by using or building upon this code?
       - Look for keywords like “enterprise,” “platform,” “framework,” or high adoption signals.
    3. Strategic Risk:
       - Does this repo integrate deeply with core HashiCorp products or contain unique innovation the company wants to protect?
       - Look for mentions of “core product,” “deep integration,” or novel techniques.
  **Instructions**:
    • Briefly (1-2 sentences each) assess the repo on each of the three criteria above.
    • Then give a final recommendation: “MPL”, “BUSL”, or “Legal Review,” with a one-sentence rationale.
  **Note**: Use the metadata (stars/forks/watchers, topics) to calibrate your answer. If usage is low and the code is purely utility with no strategic IP, MPL is fine. If commercial value or strategic risk is high, prefer BUSL or “Legal Review.”
  Begin now."

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

  content=$(echo "$response" | jq -r '.content[0].text')
  license=$(echo "$content" | grep -oE '^(MIT|BUSL|MPL-2\.0)')
  reason=$(echo "$content" | sed -E "s/^(MIT|BUSL|MPL-2\.0)[[:space:]]*[:\-]*[[:space:]]*//")

  if [[ -z "$license" || "$license" == "null" ]]; then
      license="No license"
  fi

  if [[ -z "$reason" || "$reason" == "null" ]]; then
      reason="No reason provided"
  fi

  reason=$(echo "$reason" | tr -d '\r' | sed 's/\"/\"\"/g')

  echo "\"$repo_name\",\"$repo_url\",\"$license\",\"$reason\"" >> "$CSV_OUTPUT"
  echo "Processed: $repo_name"

  sleep "$RATE_LIMIT_DELAY"
done

echo "All done. Results saved to: $CSV_OUTPUT"