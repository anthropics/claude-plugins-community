# Review Code

Run AI-to-AI code review on current changes.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/ireview.sh" review $ARGUMENTS
```

Supported arguments:
- `--base main` — review against a specific branch
- `--config .ireview-security.json` — use alternate config
- `--full` — thorough mode
- `--adversarial` — challenge every design decision
- `src/auth.ts src/db.ts` — review specific files only

After review completes, parse the API response and present findings to the user.
