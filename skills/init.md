---
name: overseer-init
description: Use when user says "/overseer-init" or wants to set up Overseer for a project. Generates a quality rubric.
---

# Initialize Overseer for This Project

Generate a `.claude/overseer/rubric.yml` customized for this project.

## Process

1. **Detect project type:** Check for package.json (frontend/backend), Dockerfile, framework files (Next.js, Flask, etc.)

2. **Ask the user one question:** "What type of project is this?"
   - Frontend (website, landing page, web app)
   - Backend (API, server, service)
   - CLI tool
   - Fullstack

3. **Copy the appropriate default rubric** from `${CLAUDE_PLUGIN_ROOT}/defaults/`

4. **Customize:** Read the project's existing code and customize the rubric:
   - If Next.js → add Next.js-specific criteria
   - If the project has a design system → reference it in criteria
   - If there are existing brand colors/fonts → add to criteria
   - Add project-specific routes to `screenshots.capture`

5. **Save** to `.claude/overseer/rubric.yml`

6. **Confirm:** Show the user what was generated and explain each section briefly.
