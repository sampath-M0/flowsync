# ⚡ FlowSync — SaaS Workflow Management Tool

FlowSync is a full-stack SaaS workflow management application that helps teams organize, track, and complete multi-step workflows with role-based access control and subscription-based feature gating.

---

## 📋 What the Application Does

FlowSync provides a complete workflow management experience:

### Core Features
- **Authentication** — Secure sign-up and login powered by Supabase Auth with session management and auto-redirect
- **Dashboard** — Real-time overview of active workflows, completed tasks, pending steps, and team member count with a personalized welcome banner
- **Workflow Management** — Full CRUD (Create, Read, Update, Delete) for workflows with title, description, status tracking, and progress bars
- **Step Management** — Break workflows into individual steps with assignees, due dates, status tracking, and overdue highlighting
- **Team Management** — Add team members by name/email, assign roles (Admin/Member), and manage access
- **Analytics** — Interactive charts (donut, bar, line) showing workflow status distribution, step completion rates, and creation trends over time (Pro plan only)
- **Settings** — Profile editing, organization management, password changes, and plan upgrade/downgrade

### Subscription Plans (Mock)
| Feature | Free Plan | Pro Plan ($19/mo) |
|---------|-----------|-------------------|
| Workflows | Up to 3 | Unlimited |
| Team Members | Up to 2 | Unlimited |
| Dashboard | ✅ | ✅ |
| Analytics | ❌ | ✅ |

### Role-Based Access
- **Admin** — Can create/edit/delete workflows, manage steps, add/remove team members
- **Member** — Can view workflows and steps (read-only)

---

## 🛠 Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | HTML5, CSS3, Vanilla JavaScript |
| Backend / Database | [Supabase](https://supabase.com) (PostgreSQL + Auth + Row Level Security) |
| Charts | [Chart.js](https://www.chartjs.org/) v4 |
| Design | Custom dark-themed CSS design system with glassmorphism, gradients, and micro-animations |

---

## 🤖 AI Tools / Models Used

| Tool | How It Was Used |
|------|----------------|
| **Google Gemini** (via Antigravity IDE) | Used for debugging database schema mismatches, converting ES modules to UMD-compatible scripts, fixing RLS policies, and auditing frontend–backend integration logic |
| **Supabase MCP Server** | Used to inspect database tables, execute SQL migrations, verify RLS policies, and manage the Supabase project directly from the IDE |

---

## 🚀 How to Run the Project Locally

### Prerequisites
- [Node.js](https://nodejs.org/) (v16 or higher) — only needed for the local HTTP server
- A modern web browser (Chrome, Firefox, Edge)

### Steps

1. **Clone or download** the project to your local machine.

2. **Navigate** to the project directory:
   ```bash
   cd "assignment 2"
   ```

3. **Start a local HTTP server** (required for Supabase API calls):
   ```bash
   npx -y http-server -p 8080 -c-1 --cors
   ```
   > The `-c-1` flag disables caching, and `--cors` enables cross-origin requests.

4. **Open in browser**:
   ```
   http://localhost:8080
   ```

5. **Create an account** by clicking "Get Started Free" on the landing page, or navigate directly to:
   ```
   http://localhost:8080/auth.html?mode=signup
   ```

6. **Log in** and explore the dashboard, workflows, team management, analytics, and settings pages.

### Project Structure

```
assignment 2/
├── index.html              # Landing page
├── auth.html               # Login / Signup
├── dashboard.html          # Main dashboard
├── workflows.html          # Workflow list + CRUD
├── workflow-detail.html    # Individual workflow + step management
├── team.html               # Team member management
├── analytics.html          # Charts & analytics (Pro only)
├── settings.html           # Profile, plan, org, security settings
├── css/
│   ├── main.css            # Global design system & tokens
│   ├── app.css             # App layout (sidebar, cards, tables)
│   └── landing.css         # Landing page specific styles
├── js/
│   └── supabase.js         # Supabase client + shared helper functions
├── supabase/
│   └── schema.sql          # Database schema, RLS policies, triggers
├── prd.md                  # Product Requirements Document
└── README.md               # This file
```

---



---

## 📄 License

This project was built as a assignment.
