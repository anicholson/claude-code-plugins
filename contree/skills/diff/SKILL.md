---
name: diff
description: "Generate a single image that represents the current change, using OpenAI's gpt-image-2 model. TRIGGER when: the user runs /diff, or asks to see, picture, illustrate, or visualise the current change or diff."
---

# Diff

Turns the current change into one image — a picture of what this diff does — using OpenAI's **gpt-image-2** model. Invoked on demand; nothing fires automatically.

## When to Use

- The user runs `/diff`.
- The user asks to see, picture, illustrate, or visualise the current change.

## Process

### 1. Read the change

Derive the change from the working tree: run `git diff` and `git diff --staged` to see what actually changed. If there is no change, say so and stop — there is nothing to depict.

### 2. Decide what the image should depict

The image is an editorial choice, not a transcription of the diff. Decide what to depict from three inputs:

- **the nature of the change** — a new capability, a refactor, a bug fix, a deletion, a config change? The kind of change sets the visual register.
- **the important details** — the one or two things a viewer most needs to grasp. Leave the rest out; an image that shows everything shows nothing.
- **the intended audience** — a teammate reviewing the PR, a non-technical stakeholder, your future self. The audience sets the vocabulary and the level of abstraction.

### 3. Generate the image with gpt-image-2

Call OpenAI's images generations API with the `gpt-image-2` model (pinned id `gpt-image-2-2026-04-21`), authenticated with `OPENAI_API_KEY`. Write a prompt that captures your step-2 decisions. The response is base64 — decode it and save the returned image as a `.png` file in the project.

```bash
curl -sS -X POST "https://api.openai.com/v1/images/generations" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg prompt "$PROMPT" '{
        model: "gpt-image-2-2026-04-21",
        prompt: $prompt,
        size: "1024x1024",
        quality: "high",
        response_format: "b64_json"
      }')" \
  | jq -r '.data[0].b64_json' | base64 --decode > diff.png
```

### 4. Surface your choices

Show the saved image's path and surface the choices you made for the user to review: what you depicted, which details you foregrounded and which you dropped, and the audience you pitched it at. The user reviews — they may ask you to redraw with different choices.

## Failure is loud

If the gpt-image-2 request fails — missing `OPENAI_API_KEY`, an API error, a non-2xx response, or empty `data` — surface the failure as an error and stop. Never fabricate an image, write a placeholder file, or report success you did not get. A missing image is an honest outcome; a fake one is not.
