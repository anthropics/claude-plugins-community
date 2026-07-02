# Setup iReview

Initialize iReview configuration.

```bash
if [ ! -f .ireview.json ]; then
  cp "${CLAUDE_PLUGIN_ROOT}/.ireview.example.json" .ireview.json
  echo "Created .ireview.json — edit model and API key settings."
else
  echo ".ireview.json already exists."
fi
```

API key priority:
1. CLAUDE_PLUGIN_OPTION_API_KEY (plugin secure config)
2. IREVIEW_API_KEY environment variable
3. api_key field in .ireview.json
