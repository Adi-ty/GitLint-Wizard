# GitLint Wizard 🔮✨

A smart Git commit enforcer with **Conventional Commits validation**, **auto-versioning**, and **AI-powered message generation**.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://makeapullrequest.com)



## Features

### Core Features
- 🚦 Enforce Conventional Commit standards
- 🚀 Automatic semantic version bumping
- 😎 Type-specific emoji prefixes
- 🔧 Fully configurable rules
- 🛡️ Pre-commit hook integration

### AI Features
- 🤖 AI-generated commit messages
- 🔍 Context-aware analysis of `git diff`
- ✅ Auto-validation of AI suggestions

## Installation

### Quick Install (curl)

```bash
# Install in current repository
curl -L https://raw.githubusercontent.com/Adi-ty/GitLint-Wizard/main/gitlint-wizard.sh | bash -s install
```

### Manual Installation

```bash
git clone https://github.com/Adi-ty/GitLint-Wizard.git
cd gitlintwizard
./gitlintwizard.sh install
```

### AI Requirements
1. Get Gemini API Key: [Gemini API Key](https://aistudio.google.com/apikey)
2. Install Dependencies
```bash
# macos
brew install jq

# Linux
sudo apt-get install jq
```

### Usage

Commit normally - the wizard will guide you:

```bash
git commit -m "feat: add new authentication system"
```

Valid message format:

```bash
type(scope): description [JIRA-123]
```

#### AI-Powered Commits
```bash
# Stage changes first
git add .

# Generate and commit
./gitlintwizard.sh ai-commit

🤖 Analyzing changes...
Use this commit message?: 'feat(auth): implement password strength checker' [Y/n] y
✨ feat(auth): implement password strength checker
Version bumped to 1.2.0!
```

### Configuration

Edit .gitlintwizardrc in your repo root:

```bash
# Allowed commit types
TYPES=feat,fix,chore,docs,style,refactor,test

# Max subject length (chars)
MAX_LENGTH=72

# Require JIRA ticket
REQUIRE_JIRA=false

# Emoji support
USE_EMOJI=true

# Auto-versioning
AUTO_VERSION=true

# Required for AI features
GEMINI_API_KEY="your-api-key"
```

### How It Works

1. Hook Installation
   Creates prepare-commit-msg Git hook

2. Message Validation
   Checks against:

- Commit type validity

- Proper format

- Subject length

- JIRA ticket presence

3. Version Bumping
   Updates VERSION file using semantic versioning:

- feat → minor (0.1.0 → 0.2.0)

- fix → patch (0.1.0 → 0.1.1)

4. Emoji Magic
   Adds type-specific emojis:

```bash
✨ feat: New feature
🐛 fix: Bug fix
📚 docs: Documentation
```

### Uninstall

Remove from your repository:

```bash
./gitlintwizard.sh uninstall
```

### Contributing

1. Fork the repository

2. Create feature branch (`git checkout -b feat/amazing-feature`)

3. Commit changes (follow the commit conventions!)

4. Push to branch

5. Open a PR
