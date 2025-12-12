# LinkedIn Content Automation

Automated workflow for creating and publishing LinkedIn posts about DevOps, DevSecOps, and Cybersecurity topics.

## 📁 Files in This Folder

| File | Description |
|------|-------------|
| `SMART_PROMPT.md` | AI prompt templates with anti-detection rules |
| `TOPIC_LIBRARY.md` | 35+ content topics organized by category |
| `n8n-workflow.json` | Complete N8N workflow (import this) |
| `SETUP_GUIDE.md` | Step-by-step configuration instructions |

## 🚀 Quick Start

1. **Import the workflow** into N8N:
   ```
   N8N → Add Workflow → Import from File → n8n-workflow.json
   ```

2. **Configure credentials** (see SETUP_GUIDE.md):
   - OpenAI API
   - LinkedIn OAuth2
   - Slack (for review)

3. **Update placeholders** in the workflow nodes

4. **Test manually** before enabling schedule

## 🔄 Workflow Overview

```
CVE Feed → AI Content Generation → Visual Creation → Review → Publish
    ↓              ↓                     ↓            ↓         ↓
   NVD         GPT-4o/Claude         DALL-E 3      Slack    LinkedIn
```

## 📊 Features

- ✅ **Auto CVE Monitoring** - Fetches HIGH/CRITICAL CVEs from NVD
- ✅ **Human-like Content** - Anti-AI detection prompts
- ✅ **Bilingual Support** - French and English posts
- ✅ **Visual Generation** - LinkedIn-optimized images (1200x627)
- ✅ **Human Review** - Slack/email approval before posting
- ✅ **Post Tracking** - Google Sheets logging

## 📅 Recommended Schedule

| Day | Time | Language | Type |
|-----|------|----------|------|
| Mon | 09:00 | FR | Quick Tip |
| Tue | 14:00 | ENG | CVE Alert |
| Wed | 09:00 | ENG | Deep Dive |
| Thu | 14:00 | FR | Story |
| Fri | 10:00 | ENG | Hot Take |

## 🔗 Related Documentation

- [N8N Deployment Guide](../docs/N8N_Deployment_Guide.md)
- [Secrets Management](../docs/Secrets_Management_Guide.md)

---

*Last Updated: December 12, 2025*
