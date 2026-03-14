# Contributing to Group Acca

Welcome to the team! To ensure we keep the main codebase clean, functioning, and conflict-free, please follow this guide when setting up your environment and contributing code.

## Initial Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/richarddoyle/group-acca.git
   cd group-acca
   ```

2. **Add the Secrets File (CRITICAL):**
   For security, API keys and Supabase credentials are not stored in GitHub. You must ask Richard for the `Secrets.swift` file directly via a secure messaging app. 
   
   Once you receive it, drop `Secrets.swift` into the `WeeklyAcca/` directory alongside the other Swift files (e.g., `WeeklyAcca/WeeklyAcca/Secrets.swift`). 
   
   *Note: This file is already in our `.gitignore`, so you won't accidentally commit it.*

3. **Open the Project:**
   Open `WeeklyAcca.xcodeproj` in Xcode and make sure the app builds and runs successfully in the simulator.

## Our Git Workflow

We use a standard "Feature Branch" workflow. The `main` branch is strictly for stable, release-ready code. **Never push code directly to `main`.**

### 1. Create a branch for your feature or fix
Before making any changes, create a new branch from `main`:
```bash
# Make sure your local main is up to date
git checkout main
git pull

# Create and switch to your new branch
git checkout -b feature/your-feature-name
# Examples: feature/new-bet-type, fix/login-crash, ui/dashboard-polish
```

### 2. Commit your changes
As you work, make small, logical commits:
```bash
git add .
git commit -m "Add descriptive message of what you changed"
```

### 3. Push and open a Pull Request (PR)
When your feature is complete and tested:
```bash
git push -u origin feature/your-feature-name
```
Then, go to the GitHub repository in your web browser. You'll see a green button to **Compare & pull request**.
- Fill out a brief description of what the PR does.
- Mention any specific areas that need extra attention during review.
- Request a review from the team.

### 4. Code Review and Merge
- Reviewers will look over the code, test it locally if needed, and leave comments or approve the PR.
- Once approved, the PR will be merged into `main`.
- After merging, you can safely delete your feature branch.

## Coding Standards
- Keep Xcode warnings to an absolute minimum.
- Use SwiftUI native components and standard iOS design paradigms (e.g., native Navigation Titles, standard `Color(.systemBackground)`, etc.) wherever possible.
- If you add a new model or complex logic, considering adding a comment or a quick documentation block to explain how it works.

Happy coding!
