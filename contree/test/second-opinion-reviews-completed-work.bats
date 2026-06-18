#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/second-opinion/SKILL.md"

@test "second-opinion skill derives the completed work from the working-tree git diff" {
  run cat "$SKILL"
  [[ "$output" == *"git diff"* ]]
}

@test "second-opinion skill reads the test trees as the contract the work must satisfy" {
  run cat "$SKILL"
  [[ "$output" == *"Test Trees"* || "$output" == *"TEST_TREES.md"* ]]
  [[ "$output" == *"contract"* ]]
}

@test "second-opinion skill sends the work to Z.AI's GLM 5.2 chat completions API authenticated with ZAI_API_KEY" {
  run cat "$SKILL"
  [[ "$output" == *"glm-5.2"* ]]
  [[ "$output" == *"api.z.ai"* ]]
  [[ "$output" == *"chat/completions"* ]]
  [[ "$output" == *"ZAI_API_KEY"* ]]
}

@test "second-opinion skill surfaces GLM 5.2's review attributed to GLM 5.2" {
  run cat "$SKILL"
  [[ "$output" == *"surface"* || "$output" == *"Surface"* ]]
  [[ "$output" == *"attribut"* ]]
}

@test "second-opinion skill stops without calling the API when there is no change" {
  run cat "$SKILL"
  [[ "$output" == *"no change"* ]]
  [[ "$output" == *"stop"* ]]
}

@test "second-opinion skill surfaces a failed review request as an error and fabricates no review" {
  run cat "$SKILL"
  [[ "$output" == *"fails"* ]]
  [[ "$output" == *"error"* ]]
  [[ "$output" == *"fabricate"* ]]
}
