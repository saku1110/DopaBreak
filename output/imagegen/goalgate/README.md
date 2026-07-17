# GoalGate UI Mockups

Generated: 2026-06-27

## Files

| File | Contents |
| --- | --- |
| `01_onboarding_board.png` | Welcome, purpose selection, goal creation, target app / Screen Time permission |
| `02_core_app_board.png` | Home, goal detail, stats, widget setup, settings |
| `03_shield_flow_board.png` | Breath delay, usage summary, intention check, time selection, saved/cancel result |

## gpt-image-2 CLI note

The gpt-image-2 CLI prompt batch is saved at `tmp/imagegen/goalgate_prompts.jsonl` with 14 individual screen prompts.

The attempted CLI command was:

```bash
python3 /Users/solotech/.codex/skills/.system/imagegen/scripts/image_gen.py generate-batch \
  --input tmp/imagegen/goalgate_prompts.jsonl \
  --out-dir output/imagegen/goalgate \
  --concurrency 3
```

The API returned `billing_hard_limit_reached`, so the final board images above were generated with the built-in image generation tool and copied into this workspace.

