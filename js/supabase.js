// ============================================================
// supabase.js — Supabase Client & Shared Helpers
// Loaded as a regular <script> (NOT module) so pages work with file:// URLs
// ============================================================

(function () {
  'use strict';

  var SUPABASE_URL  = 'https://wrzbtnmcxgxkhuoaywbt.supabase.co';
  var SUPABASE_ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndyemJ0bm1jeGd4a2h1b2F5d2J0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU4MjE0NjksImV4cCI6MjA5MTM5NzQ2OX0.G1-igCYLnoYe0A1CgUqXToKs5Gmstm_aRtUT9LkTn_s';

  // Create Supabase client using UMD global
  var sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON);

  // ── Session Helpers ──

  async function getSession() {
    var result = await sb.auth.getSession();
    return result.data.session;
  }

  async function getUser() {
    var result = await sb.auth.getUser();
    return result.data.user;
  }

  async function getProfile(userId) {
    var result = await sb.from('profiles').select('*').eq('id', userId).single();
    if (result.error) return null;
    return result.data;
  }

  async function getUserOrg(userId) {
    // Check if user owns an org
    var ownerResult = await sb.from('organizations').select('*').eq('owner_id', userId).maybeSingle();
    if (ownerResult.data) return ownerResult.data;

    // Check if user is a member of an org
    var memberResult = await sb.from('team_members').select('organizations(*)').eq('user_id', userId).maybeSingle();
    return (memberResult.data && memberResult.data.organizations) || null;
  }

  // ── Guard: redirect to auth if not logged in ──
  async function requireAuth(redirectTo) {
    redirectTo = redirectTo || 'auth.html';
    var session = await getSession();
    if (!session) {
      window.location.href = redirectTo;
      return null;
    }
    return session;
  }

  // ── Guard: redirect to dashboard if already logged in ──
  async function requireGuest(redirectTo) {
    redirectTo = redirectTo || 'dashboard.html';
    var session = await getSession();
    if (session) {
      window.location.href = redirectTo;
    }
  }

  // ── Toast notifications ──
  function showToast(message, type) {
    type = type || 'info';
    var container = document.getElementById('toast-container') ||
      (function () {
        var el = document.createElement('div');
        el.id = 'toast-container';
        el.className = 'toast-container';
        document.body.appendChild(el);
        return el;
      })();

    var icons = { success: '✓', error: '✕', info: 'ℹ' };
    var toast = document.createElement('div');
    toast.className = 'toast toast-' + type;
    toast.innerHTML = '<span>' + (icons[type] || icons.info) + '</span><span>' + message + '</span>';
    container.appendChild(toast);
    setTimeout(function () { toast.remove(); }, 4000);
  }

  // ── Format date ──
  function formatDate(dateStr) {
    if (!dateStr) return '—';
    return new Date(dateStr).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
  }

  // ── Status label ──
  function statusLabel(status) {
    var map = { not_started: 'Not Started', in_progress: 'In Progress', completed: 'Completed' };
    return map[status] || status;
  }

  function statusBadgeClass(status) {
    var map = { not_started: 'badge-not-started', in_progress: 'badge-in-progress', completed: 'badge-completed' };
    return map[status] || 'badge-not-started';
  }

  // ── Progress calculation ──
  function calcProgress(steps) {
    if (!steps || steps.length === 0) return 0;
    var done = steps.filter(function (s) { return s.status === 'completed'; }).length;
    return Math.round((done / steps.length) * 100);
  }

  // ── HTML escaping ──
  function escHtml(str) {
    var d = document.createElement('div');
    d.appendChild(document.createTextNode(str || ''));
    return d.innerHTML;
  }

  function escAttr(str) {
    return (str || '').replace(/'/g, "\\'").replace(/"/g, '&quot;');
  }

  // ── Expose everything globally ──
  window.FlowSync = {
    sb: sb,
    getSession: getSession,
    getUser: getUser,
    getProfile: getProfile,
    getUserOrg: getUserOrg,
    requireAuth: requireAuth,
    requireGuest: requireGuest,
    showToast: showToast,
    formatDate: formatDate,
    statusLabel: statusLabel,
    statusBadgeClass: statusBadgeClass,
    calcProgress: calcProgress,
    escHtml: escHtml,
    escAttr: escAttr
  };
})();
