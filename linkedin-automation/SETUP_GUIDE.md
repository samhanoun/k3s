# LinkedIn Automation Setup Guide

> **Version:** 1.0.0  
> **Last Updated:** December 12, 2025  
> **Purpose:** Step-by-step setup for the LinkedIn content automation workflow

---

## 📋 Prerequisites

| Requirement | Status | Notes |
|-------------|--------|-------|
| N8N instance | ✅ Running on K3S | Already deployed |
| OpenAI API key | ⬜ Configure | Work-provided account |
| LinkedIn Developer App | ⬜ Configure | Already created |
| Slack workspace | ⬜ Configure | For review notifications |
| Google Sheets | ⬜ Optional | For tracking posts |

---

## 🔧 Step 1: LinkedIn API Setup

### 1.1 Create LinkedIn App (if not done)

1. Go to [LinkedIn Developer Portal](https://www.linkedin.com/developers/)
2. Click "Create App"
3. Fill in:
   - **App name:** Content Automation
   - **LinkedIn Page:** Your company/personal page
   - **App logo:** Upload any logo
4. Accept terms and create

### 1.2 Request API Access

LinkedIn requires approval for posting. Request these products:

| Product | Purpose | Approval Time |
|---------|---------|---------------|
| **Share on LinkedIn** | Post content | Instant for personal use |
| **Sign In with LinkedIn using OpenID Connect** | OAuth authentication | Instant |
| **Marketing Developer Platform** | Company page posting (optional) | 1-2 weeks |

### 1.3 Get OAuth Credentials

1. Go to your app → **Auth** tab
2. Note down:
   ```
   Client ID: xxxxxxxxxxxx
   Client Secret: xxxxxxxxxxxxxxxxxxxxxxxx
   ```

3. Add **Redirect URLs**:
   ```
   https://your-n8n-domain.com/rest/oauth2-credential/callback
   ```

### 1.4 Get Your LinkedIn Person ID

You need your LinkedIn URN for posting. Get it via API:

```bash
curl -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
     "https://api.linkedin.com/v2/me"
```

Response will include:
```json
{
  "id": "xxxxxx",  ← This is your Person ID
  ...
}
```

Your full URN is: `urn:li:person:xxxxxx`

### 1.5 OAuth Scopes Required

When configuring OAuth, request these scopes:
```
openid
profile
email
w_member_social
```

For company page posting, also add:
```
w_organization_social
```

---

## 🔧 Step 2: N8N Credential Setup

### 2.1 OpenAI Credentials

1. In N8N, go to **Settings → Credentials**
2. Click **Add Credential → OpenAI API**
3. Enter:
   - **API Key:** Your work-provided OpenAI API key
   - Save and test

### 2.2 LinkedIn OAuth2 Credentials

1. Add Credential → **LinkedIn OAuth2 API**
2. Enter:
   - **Client ID:** From step 1.3
   - **Client Secret:** From step 1.3
3. Click **Connect** to authorize
4. Grant permissions when redirected to LinkedIn

### 2.3 Slack Credentials (for review)

1. Go to [Slack API](https://api.slack.com/apps)
2. Create new app or use existing
3. Add **OAuth Scopes**:
   ```
   chat:write
   channels:read
   ```
4. Install to workspace
5. Copy **Bot User OAuth Token**
6. In N8N, add Slack credential with this token

### 2.4 SMTP Credentials (for email review)

1. Add Credential → **SMTP**
2. For Gmail:
   ```
   Host: smtp.gmail.com
   Port: 465
   Secure: true
   User: your-email@gmail.com
   Password: App-specific password
   ```
3. Test sending

---

## 🔧 Step 3: Import Workflow

### 3.1 Import the JSON

1. In N8N, click **Add Workflow**
2. Click **...** menu → **Import from File**
3. Select `n8n-workflow.json` from this folder
4. Workflow will appear with nodes

### 3.2 Update Placeholders

Find and replace these placeholders in the workflow:

| Placeholder | Replace With |
|-------------|--------------|
| `YOUR_OPENAI_CREDENTIAL_ID` | Your OpenAI credential ID |
| `YOUR_LINKEDIN_CREDENTIAL_ID` | Your LinkedIn OAuth credential ID |
| `YOUR_SLACK_CREDENTIAL_ID` | Your Slack credential ID |
| `YOUR_SMTP_CREDENTIAL_ID` | Your SMTP credential ID |
| `YOUR_LINKEDIN_PERSON_ID` | Your LinkedIn person ID (from 1.4) |
| `YOUR_GOOGLE_SHEET_ID` | Google Sheets document ID |
| `your-email@example.com` | Your email address |
| `#linkedin-posts` | Your Slack channel name |

### 3.3 Test Individual Nodes

Test each node manually before enabling automation:

1. **Fetch Recent CVEs** → Should return 20 CVEs
2. **Process CVE Data** → Should extract top CVE
3. **Generate Post Content** → Should produce LinkedIn post
4. **Generate Visual** → Should produce image URL
5. **Send to Slack** → Should post preview message

---

## 🔧 Step 4: Configure Triggers

### 4.1 Schedule Trigger

Default: Every 6 hours

To customize:
1. Open "Schedule: Every 6 Hours" node
2. Adjust interval (recommended: 6-12 hours)
3. Add specific times if preferred:
   ```
   - 09:00 (morning post)
   - 14:00 (afternoon post)
   ```

### 4.2 Manual Trigger (Webhook)

For on-demand posts:

1. Activate the workflow
2. Copy the webhook URL from the node
3. Test with:
   ```bash
   curl -X POST https://your-n8n-domain.com/webhook/linkedin-post
   ```

### 4.3 Custom Topic Posts

For manual topic selection (not CVE-based), use the webhook with body:

```json
{
  "topic": "Terraform state security",
  "language": "FR",
  "tone": "lessons learned",
  "length": "medium"
}
```

---

## 🔧 Step 5: Approval Workflow

### 5.1 Slack Approval

When a post is ready:
1. Check `#linkedin-posts` channel
2. Review the content and image
3. React with:
   - ✅ to approve and publish
   - ❌ to reject

### 5.2 Email Approval

Alternatively:
1. Check email for "LinkedIn Post Ready: CVE-xxxx"
2. Review content and image preview
3. Click approval link or reply to approve

### 5.3 Manual Publishing

If you prefer manual control:
1. Review in Slack/email
2. Copy the post content
3. Download the image
4. Post manually to LinkedIn

---

## 📊 Tracking & Analytics

### Google Sheets Structure

Create a sheet with these columns:

| A | B | C | D | E | F | G | H |
|---|---|---|---|---|---|---|---|
| Created | CVE ID | Severity | Language | Content | Image URL | Status | Engagement |

### Status Values
- `pending_review` - Awaiting approval
- `approved` - Ready to post
- `published` - Posted to LinkedIn
- `rejected` - Not published

### Engagement Tracking (Manual)

After 48 hours, update the sheet with:
- Impressions
- Reactions
- Comments
- Shares

---

## 🐛 Troubleshooting

### NVD API Rate Limiting

If you get 429 errors:
1. Add delay between requests
2. Use API key from NVD (free, higher limits)
3. Reduce polling frequency

### LinkedIn API Errors

| Error Code | Meaning | Solution |
|------------|---------|----------|
| 401 | Token expired | Reconnect OAuth in N8N |
| 403 | Insufficient permissions | Request additional scopes |
| 429 | Rate limited | Wait 24 hours, reduce posting |

### DALL-E Issues

If images don't generate:
1. Check OpenAI quota/billing
2. Simplify the prompt
3. Use backup: Mermaid.js diagrams

### Slack Not Receiving

1. Verify bot is in the channel
2. Check channel name (with #)
3. Test with a simple message node

---

## 📅 Recommended Schedule

| Day | Time (CET) | Language | Content Type |
|-----|------------|----------|--------------|
| Monday | 09:00 | FR | Quick tip |
| Tuesday | 14:00 | ENG | CVE alert (automated) |
| Wednesday | 09:00 | ENG | Deep dive |
| Thursday | 14:00 | FR | Story/experience |
| Friday | 10:00 | ENG | Hot take |

---

## 🔄 Workflow Diagram

```
┌─────────────────┐     ┌──────────────────┐
│  Scheduled      │     │  Manual Webhook  │
│  (Every 6h)     │     │  (On-demand)     │
└────────┬────────┘     └────────┬─────────┘
         │                       │
         └───────────┬───────────┘
                     ▼
         ┌───────────────────────┐
         │  Fetch NVD CVE Data   │
         │  (Last 3 days, HIGH+) │
         └───────────┬───────────┘
                     ▼
         ┌───────────────────────┐
         │  Process & Select     │
         │  Top CVE by Score     │
         └───────────┬───────────┘
                     ▼
         ┌───────────────────────┐
         │  Has Valid CVE Data?  │
         └───────────┬───────────┘
                     │
         ┌───────────┴───────────┐
         ▼                       ▼
    ┌─────────┐         ┌───────────────┐
    │  Skip   │         │  Generate     │
    └─────────┘         │  Content (AI) │
                        └───────┬───────┘
                                │
                        ┌───────┴───────┐
                        ▼               ▼
               ┌────────────┐   ┌────────────┐
               │ GPT-4o     │   │ DALL-E 3   │
               │ Post Text  │   │ Image      │
               └─────┬──────┘   └─────┬──────┘
                     │                │
                     └───────┬────────┘
                             ▼
                 ┌───────────────────────┐
                 │  Combine & Validate   │
                 └───────────┬───────────┘
                             │
         ┌───────────────────┼───────────────────┐
         ▼                   ▼                   ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│  Slack Review   │  │  Email Review   │  │  Google Sheets  │
│  Notification   │  │  Notification   │  │  Log Entry      │
└────────┬────────┘  └─────────────────┘  └─────────────────┘
         │
         ▼ (After approval)
┌─────────────────────────────┐
│  Approval Webhook Received  │
└───────────────┬─────────────┘
                ▼
┌─────────────────────────────┐
│  Post to LinkedIn API       │
│  (UGC Post with Image)      │
└───────────────┬─────────────┘
                ▼
┌─────────────────────────────┐
│  Success Response           │
└─────────────────────────────┘
```

---

## 🔐 Security Notes

1. **Never commit credentials** to Git
2. **Use N8N's credential system** - encrypted at rest
3. **Rotate LinkedIn tokens** every 60 days
4. **Monitor API usage** to detect abuse
5. **Review all posts** before publishing (human in the loop)

---

## 🔄 Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-12-12 | Initial setup guide |

---

*This guide is maintained in both GitHub (linkedin-automation/) and Obsidian (k3s/) for version control.*
