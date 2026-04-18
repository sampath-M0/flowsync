-- =============================================================================
-- FlowSync — Supabase schema, RLS, and auth profile trigger
-- Run in Supabase Dashboard → SQL → New query (fresh project or review diffs)
-- =============================================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- -----------------------------------------------------------------------------
-- Tables
-- -----------------------------------------------------------------------------

CREATE TABLE public.organizations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  owner_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  organization_id uuid REFERENCES public.organizations (id) ON DELETE SET NULL,
  name text,
  plan text NOT NULL DEFAULT 'free' CHECK (plan IN ('free', 'pro')),
  role text NOT NULL DEFAULT 'admin' CHECK (role IN ('admin', 'member')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.team_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations (id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users (id) ON DELETE SET NULL,
  name text NOT NULL,
  email text NOT NULL,
  role text NOT NULL DEFAULT 'member' CHECK (role IN ('admin', 'member')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_team_members_org ON public.team_members (organization_id);
CREATE INDEX idx_team_members_user ON public.team_members (user_id);

CREATE TABLE public.workflows (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations (id) ON DELETE CASCADE,
  created_by uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  title text NOT NULL,
  description text,
  status text NOT NULL DEFAULT 'not_started'
    CHECK (status IN ('not_started', 'in_progress', 'completed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_workflows_org ON public.workflows (organization_id);

CREATE TABLE public.steps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workflow_id uuid NOT NULL REFERENCES public.workflows (id) ON DELETE CASCADE,
  title text NOT NULL,
  description text,
  status text NOT NULL DEFAULT 'not_started'
    CHECK (status IN ('not_started', 'in_progress', 'completed')),
  -- Logged-in assignee (auth user). NULL when assigned only to a demo row in team_members.
  assigned_to uuid REFERENCES auth.users (id) ON DELETE SET NULL,
  assigned_team_member_id uuid REFERENCES public.team_members (id) ON DELETE SET NULL,
  assigned_to_name text,
  due_date date,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT steps_single_assignee_chk CHECK (
    NOT (assigned_to IS NOT NULL AND assigned_team_member_id IS NOT NULL)
  )
);

CREATE INDEX idx_steps_workflow ON public.steps (workflow_id);

-- -----------------------------------------------------------------------------
-- Helper functions (SECURITY DEFINER avoids RLS recursion)
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.user_organization_ids()
RETURNS SETOF uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT o.id FROM public.organizations o WHERE o.owner_id = (SELECT auth.uid())
  UNION
  SELECT tm.organization_id FROM public.team_members tm WHERE tm.user_id = (SELECT auth.uid());
$$;

CREATE OR REPLACE FUNCTION public.user_is_org_admin(check_org uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.organizations o
    WHERE o.id = check_org AND o.owner_id = (SELECT auth.uid())
  )
  OR EXISTS (
    SELECT 1 FROM public.team_members tm
    WHERE tm.organization_id = check_org
      AND tm.user_id = (SELECT auth.uid())
      AND tm.role = 'admin'
  );
$$;

REVOKE ALL ON FUNCTION public.user_organization_ids() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.user_organization_ids() TO authenticated;

REVOKE ALL ON FUNCTION public.user_is_org_admin(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.user_is_org_admin(uuid) TO authenticated;

-- -----------------------------------------------------------------------------
-- New user → profile row (signup)
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.profiles (id, name, plan, role)
  VALUES (
    new.id,
    COALESCE(new.raw_user_meta_data->>'name', split_part(COALESCE(new.email, ''), '@', 1)),
    'free',
    'admin'
  );
  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE PROCEDURE public.handle_new_user();

-- -----------------------------------------------------------------------------
-- Row Level Security
-- -----------------------------------------------------------------------------

ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workflows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.steps ENABLE ROW LEVEL SECURITY;

-- organizations
CREATE POLICY "orgs_select_member"
  ON public.organizations FOR SELECT TO authenticated
  USING (id IN (SELECT public.user_organization_ids()));

CREATE POLICY "orgs_insert_owner"
  ON public.organizations FOR INSERT TO authenticated
  WITH CHECK (owner_id = (SELECT auth.uid()));

CREATE POLICY "orgs_update_owner"
  ON public.organizations FOR UPDATE TO authenticated
  USING (owner_id = (SELECT auth.uid()))
  WITH CHECK (owner_id = (SELECT auth.uid()));

-- profiles
CREATE POLICY "profiles_select_own"
  ON public.profiles FOR SELECT TO authenticated
  USING (id = (SELECT auth.uid()));

CREATE POLICY "profiles_update_own"
  ON public.profiles FOR UPDATE TO authenticated
  USING (id = (SELECT auth.uid()))
  WITH CHECK (id = (SELECT auth.uid()));

-- team_members
CREATE POLICY "team_select_org"
  ON public.team_members FOR SELECT TO authenticated
  USING (organization_id IN (SELECT public.user_organization_ids()));

CREATE POLICY "team_insert_admin"
  ON public.team_members FOR INSERT TO authenticated
  WITH CHECK (public.user_is_org_admin(organization_id));

CREATE POLICY "team_update_admin"
  ON public.team_members FOR UPDATE TO authenticated
  USING (public.user_is_org_admin(organization_id))
  WITH CHECK (public.user_is_org_admin(organization_id));

CREATE POLICY "team_delete_admin"
  ON public.team_members FOR DELETE TO authenticated
  USING (public.user_is_org_admin(organization_id));

-- workflows
CREATE POLICY "wf_select_org"
  ON public.workflows FOR SELECT TO authenticated
  USING (organization_id IN (SELECT public.user_organization_ids()));

CREATE POLICY "wf_insert_admin"
  ON public.workflows FOR INSERT TO authenticated
  WITH CHECK (
    organization_id IN (SELECT public.user_organization_ids())
    AND public.user_is_org_admin(organization_id)
    AND created_by = (SELECT auth.uid())
  );

CREATE POLICY "wf_update_admin"
  ON public.workflows FOR UPDATE TO authenticated
  USING (
    organization_id IN (SELECT public.user_organization_ids())
    AND public.user_is_org_admin(organization_id)
  )
  WITH CHECK (
    organization_id IN (SELECT public.user_organization_ids())
    AND public.user_is_org_admin(organization_id)
  );

CREATE POLICY "wf_delete_admin"
  ON public.workflows FOR DELETE TO authenticated
  USING (
    organization_id IN (SELECT public.user_organization_ids())
    AND public.user_is_org_admin(organization_id)
  );

-- steps
CREATE POLICY "steps_select_org"
  ON public.steps FOR SELECT TO authenticated
  USING (
    workflow_id IN (
      SELECT w.id FROM public.workflows w
      WHERE w.organization_id IN (SELECT public.user_organization_ids())
    )
  );

CREATE POLICY "steps_insert_admin"
  ON public.steps FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.workflows w
      WHERE w.id = workflow_id
        AND w.organization_id IN (SELECT public.user_organization_ids())
        AND public.user_is_org_admin(w.organization_id)
    )
  );

CREATE POLICY "steps_update_admin"
  ON public.steps FOR UPDATE TO authenticated
  USING (
    workflow_id IN (
      SELECT w.id FROM public.workflows w
      WHERE w.organization_id IN (SELECT public.user_organization_ids())
        AND public.user_is_org_admin(w.organization_id)
    )
  )
  WITH CHECK (
    workflow_id IN (
      SELECT w.id FROM public.workflows w
      WHERE w.organization_id IN (SELECT public.user_organization_ids())
        AND public.user_is_org_admin(w.organization_id)
    )
  );

CREATE POLICY "steps_delete_admin"
  ON public.steps FOR DELETE TO authenticated
  USING (
    workflow_id IN (
      SELECT w.id FROM public.workflows w
      WHERE w.organization_id IN (SELECT public.user_organization_ids())
        AND public.user_is_org_admin(w.organization_id)
    )
  );

-- -----------------------------------------------------------------------------
-- Optional: existing DB — add assignee column + clean old conflation of IDs
-- (Skip on a brand-new run that used the CREATE TABLE above.)
-- -----------------------------------------------------------------------------
/*
ALTER TABLE public.steps
  ADD COLUMN IF NOT EXISTS assigned_team_member_id uuid
  REFERENCES public.team_members (id) ON DELETE SET NULL;

ALTER TABLE public.steps DROP CONSTRAINT IF EXISTS steps_single_assignee_chk;
ALTER TABLE public.steps ADD CONSTRAINT steps_single_assignee_chk CHECK (
  NOT (assigned_to IS NOT NULL AND assigned_team_member_id IS NOT NULL)
);

-- If older app stored team_members.id inside assigned_to, move it across:
UPDATE public.steps s
SET
  assigned_team_member_id = t.id,
  assigned_to = NULL
FROM public.team_members t
WHERE s.assigned_to IS NOT NULL
  AND s.assigned_team_member_id IS NULL
  AND t.id = s.assigned_to
  AND t.user_id IS NULL;
*/
