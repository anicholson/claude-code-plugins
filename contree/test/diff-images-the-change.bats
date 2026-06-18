#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/diff/SKILL.md"

@test "diff skill determines the change to depict from any natural-language indication the user gave" {
  run cat "$SKILL"
  [[ "$output" == *"natural-language"* || "$output" == *"natural language"* ]]
  [[ "$output" == *"indicat"* ]]
}

@test "diff skill absent a clear indication depicts the last non-trivial, naturally grouped changes, not a single commit and not only the working tree" {
  run cat "$SKILL"
  [[ "$output" == *"naturally grouped"* || "$output" == *"naturally-grouped"* ]]
  [[ "$output" == *"non-trivial"* ]]
  [[ "$output" == *"trunk-sync"* ]]
  [[ "$output" == *"commit"* ]]
  [[ "$output" == *"working tree"* ]]
}

@test "diff skill gathers a change that includes new files not yet tracked by git" {
  run cat "$SKILL"
  [[ "$output" == *"untracked"* ]]
}

@test "diff skill generates an image of the change using OpenAI gpt-image-2 via the images generations API" {
  run cat "$SKILL"
  [[ "$output" == *"gpt-image-2"* ]]
  [[ "$output" == *"images generations"* ]]
}

@test "diff skill request sends only parameters the gpt-image-2 API accepts (no response_format, which it rejects)" {
  run cat "$SKILL"
  [[ "$output" == *".data[0].b64_json"* && "$output" != *"response_format:"* ]]
}

@test "diff skill chooses what the image depicts from the nature of the change, its important details, and its audience" {
  run cat "$SKILL"
  [[ "$output" == *"nature of the change"* ]]
  [[ "$output" == *"important details"* ]]
  [[ "$output" == *"audience"* ]]
}

@test "diff skill saves the returned image as a .png file" {
  run cat "$SKILL"
  [[ "$output" == *"save"* ]]
  [[ "$output" == *".png"* ]]
}

@test "diff skill surfaces those choices to the user for review" {
  run cat "$SKILL"
  [[ "$output" == *"surface"* ]]
  [[ "$output" == *"review"* ]]
}

@test "diff skill surfaces a failed gpt-image-2 request as an error and fabricates no image" {
  run cat "$SKILL"
  [[ "$output" == *"fails"* ]]
  [[ "$output" == *"error"* ]]
  [[ "$output" == *"fabricate"* ]]
}
