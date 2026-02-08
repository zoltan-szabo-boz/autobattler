# Autobattler

A 3D real-time autobattler built in Godot 4.5. Two teams of units spawn on opposite sides of a battlefield and fight autonomously.

## Setup

After cloning the repo, configure git to use the tracked hooks:

```
git config core.hooksPath hooks
```

This enables a pre-commit hook that automatically injects the Discord visit notification into the web export before each commit.

## Web Build

1. Open the project in Godot and export to Web (target: `docs/index.html`)
2. Commit and push — the pre-commit hook runs `post_web_build.py` automatically to inject the notification script
3. The site is served via GitHub Pages from the `docs/` folder
