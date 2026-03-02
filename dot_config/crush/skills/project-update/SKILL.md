---
name: project-update
description: Generate a project update for the Linear project provided.
---

# Project Update Generator

Generate a short weekly summary of work done on Linear projects.

## Instructions

1. **Identify the target** from the provided arguments: $ARGUMENTS
   - This may be a project link, project name, team name, or date range.
   - If a team is specified, gather all in-progress projects for that team.
   - If a date range is specified, filter to issues completed or actively worked on during that period.

2. **Fetch project data** using the Linear MCP tools:
   - Get project information (name, status, lead)
   - Get issues updated/completed within the relevant time period
   - Filter to issues with meaningful activity (state changes, completions)

3. **Generate a short summary** for each project listing the key things that were done:
   - Focus on completed work and meaningful progress
   - Use concise bullet points (one line per item)
   - Reference issue identifiers (e.g., INF-123) for traceability
   - Skip projects with no activity in the period
   - Group by project name

## Output Format

**IMPORTANT: Do NOT use markdown tables. Linear's text box does not render tables properly. Use bullet lists instead.**

```
## [Team Name] — Week of [Date Range]

### [Project Name]
- [What was done] (ISSUE-ID)
- [What was done] (ISSUE-ID)

### [Project Name]
- [What was done] (ISSUE-ID)
```

## Guidelines

- Keep each bullet to one sentence describing what was accomplished
- Only include projects that had activity during the period
- Order projects by amount of activity (most active first)
- If an issue is in review but not yet merged/done, note it as "in review"
- Don't include status assessments, risk analysis, or recommended actions — just what was done
