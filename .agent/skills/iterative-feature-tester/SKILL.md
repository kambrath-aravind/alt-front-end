---
name: iterative-feature-tester
description: 'Tests the usability and functionality of newly added features using real data. Iterates on the feature implementation until it meets the defined output requirements. Use when asked to test a feature, validate usability, or ensure a new addition works as expected.'
---

# Iterative Feature Tester

A skill designed to validate newly added features by testing them with real-world data, checking against strict output requirements, and iteratively improving the code until the feature perfectly meets the necessary criteria.

## When to Use This Skill

- User asks to "test the usability of a feature" or "validate the new addition".
- User wants to ensure a feature handles real data correctly.
- You need to iteratively fix a feature that isn't producing the expected output.

## Prerequisites

- The feature must be documented in the `features/` directory within this skill folder.
- Each feature file should define the input data requirements, expected output, and usability requirements.
- **Data Generation Rules:** The agent MUST NOT use mocked, hallucinated, or AI-generated data. The agent MUST use tools like `curl`, Python scripts, `wget`, or internal application logging to fetch actual, real-world data payloads from the internet or the live application environment before testing.

## How it Works: The `features/` Directory

Every feature you test should have its own markdown file in the `.agent/skills/iterative-feature-tester/features/` folder. 

When invoked to test a feature (e.g., "Test the new barcode scanner UI"), you should:
1. Look for or create `features/<feature-name>.md`.
2. Review the defined requirements, real data inputs, and expected outputs.

## Step-by-Step Workflows

### 1. Feature Definition Setup
If the feature isn't defined yet:
- Create a new file in `features/<feature-name>.md`.
- Detail the exact output requirements and usability standards.
- **Fetch Real Data**: Use actual `curl` commands, network requests via scripts, or database queries to obtain 100% real-world test data to populate the `features/<feature-name>.md` file. Never substitute real data with generated/mocked assumptions.

### 2. Execution & Testing
- Run the code or simulate the UI interaction using the provided real data.
- Capture the actual output or behavior.
- Compare the actual output against the expected output requirements defined in the feature file.

### 3. Iterative Improvement
- **If the feature meets requirements:** Mark the test as passed and summarize the successful validation for the user.
- **If the feature FAILS:** 
  - Analyze the gap between actual and expected behavior.
  - Modify the implementation code to address the failure.
  - Re-run the test with the real data.
  - Repeat this loop process iteratively until the feature confidently meets all output requirements.

## Troubleshooting

- **Missing Real Data:** If the feature lacks real data to test with, you MUST write a script or use network tools to fetch the exact payloads from the actual APIs/endpoints. **Do not hallucinate data.**
- **Infinite Loop Prevention:** Limit iterative attempts to 3-5 cycles. If the feature still fails after 5 attempts, stop and ask the user for architectural guidance.
