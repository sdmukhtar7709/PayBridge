document.addEventListener("DOMContentLoaded", () => {
  const state = {
    agents: [],
    filteredAgents: [],
    selectedAgentId: null,
    transactions: [],
    filteredTransactions: [],
    transactionsLoaded: false,
    reportTransactions: {
      totalTransactions: 0,
      totalVolume: 0,
      successRate: 0,
      transactionsPerDay: [],
    },
    reportLoaded: false,
    dashboardOverview: {
      ongoingRequests: 0,
      todaySnapshot: {
        transactions: 0,
        totalVolume: 0,
        successRate: 0,
      },
    },
    currentPage: "dashboard",
    token: "",
    tokenPayload: null,
    apiBase: "",
    toastTimer: null,
  };

  const el = {
    apiBaseUrl: document.getElementById("apiBaseUrl"),
    refreshBtn: document.getElementById("refreshBtn"),
    logoutBtn: document.getElementById("logoutBtn"),
    sessionStatus: document.getElementById("sessionStatus"),
    healthStatus: document.getElementById("healthStatus"),
    versionStatus: document.getElementById("versionStatus"),
    totalAgents: document.getElementById("totalAgents"),
    verifiedAgents: document.getElementById("verifiedAgents"),
    pendingAgents: document.getElementById("pendingAgents"),
    bannedAgents: document.getElementById("bannedAgents"),
    agentSearch: document.getElementById("agentSearch"),
    statusFilter: document.getElementById("statusFilter"),
    agentsTbody: document.getElementById("agentsTbody"),
    selectedAgent: document.getElementById("selectedAgent"),
    txSearch: document.getElementById("txSearch"),
    txStatusFilter: document.getElementById("txStatusFilter"),
    txRefreshBtn: document.getElementById("txRefreshBtn"),
    transactionsTbody: document.getElementById("transactionsTbody"),
    txDetailModal: document.getElementById("txDetailModal"),
    txDetailBody: document.getElementById("txDetailBody"),
    txDetailCloseBtn: document.getElementById("txDetailCloseBtn"),
    reportTotalTransactions: document.getElementById("reportTotalTransactions"),
    reportTotalVolume: document.getElementById("reportTotalVolume"),
    reportSuccessRate: document.getElementById("reportSuccessRate"),
    reportRefreshBtn: document.getElementById("reportRefreshBtn"),
    reportDayBars: document.getElementById("reportDayBars"),
    dashboardHealthStatus: document.getElementById("dashboardHealthStatus"),
    dashboardActiveAgents: document.getElementById("dashboardActiveAgents"),
    dashboardOngoingRequests: document.getElementById("dashboardOngoingRequests"),
    dashboardTransactionsToday: document.getElementById("dashboardTransactionsToday"),
    dashboardVolumeToday: document.getElementById("dashboardVolumeToday"),
    dashboardSuccessRateToday: document.getElementById("dashboardSuccessRateToday"),
    toast: document.getElementById("toast"),
    navItems: Array.from(document.querySelectorAll(".nav-item[data-page]")),
    pages: Array.from(document.querySelectorAll(".page[data-page]")),
  };

  const validPages = new Set(["dashboard", "agents", "transactions", "settings"]);

  function normalizeApiBase(url) {
    const fallback = "http://localhost:4000";
    const value = (url || "").trim() || fallback;
    return value.endsWith("/") ? value.slice(0, -1) : value;
  }

  function showToast(message, type) {
    if (!el.toast) {
      return;
    }

    el.toast.textContent = message;
    el.toast.style.background = type === "error" ? "#8c1d2d" : "#0f223d";
    el.toast.classList.add("show");

    window.clearTimeout(state.toastTimer);
    state.toastTimer = window.setTimeout(() => {
      el.toast.classList.remove("show");
    }, 2400);
  }

  function resolvePage(input) {
    const page = String(input || "").trim().toLowerCase();
    return validPages.has(page) ? page : "dashboard";
  }

  function setActivePage(page, shouldUpdateHash) {
    const nextPage = resolvePage(page);
    state.currentPage = nextPage;

    el.navItems.forEach((item) => {
      item.classList.toggle("is-active", item.dataset.page === nextPage);
    });

    el.pages.forEach((section) => {
      section.classList.toggle("is-active", section.dataset.page === nextPage);
    });

    if (shouldUpdateHash) {
      window.location.hash = nextPage;
    }

    if (nextPage === "transactions" && !state.transactionsLoaded) {
      fetchTransactions();
    }

    if (nextPage === "dashboard") {
      fetchReportTransactions();
      fetchDashboardOverview();
    }
  }

  function setSessionStatus(text) {
    el.sessionStatus.textContent = text;
  }

  function updateApiBaseFromInput() {
    state.apiBase = normalizeApiBase(el.apiBaseUrl.value);
    el.apiBaseUrl.value = state.apiBase;
    localStorage.setItem("cashio_admin_api_base", state.apiBase);
  }

  function decodeJwtPayload(token) {
    try {
      const parts = token.split(".");
      if (parts.length < 2) {
        return null;
      }

      const payload = parts[1].replace(/-/g, "+").replace(/_/g, "/");
      const padded = payload + "===".slice((payload.length + 3) % 4);
      return JSON.parse(atob(padded));
    } catch {
      return null;
    }
  }

  function setToken(token) {
    state.token = token || "";
    state.tokenPayload = state.token ? decodeJwtPayload(state.token) : null;

    if (!state.token) {
      setSessionStatus("No admin session found.");
      return;
    }

    const role = state.tokenPayload && state.tokenPayload.role;
    if (role !== "admin") {
      setSessionStatus("Session is invalid for admin.");
      return;
    }

    const sub = state.tokenPayload.sub || state.tokenPayload.userId || "unknown";
    setSessionStatus(`Admin token active. User: ${sub}`);
  }

  function clearAuthSession() {
    localStorage.removeItem("cashio_admin_token");
    localStorage.removeItem("cashio_admin_refresh_token");
    setToken("");
  }

  async function refreshAccessToken() {
    const refreshToken = localStorage.getItem("cashio_admin_refresh_token");
    if (!refreshToken) {
      throw new Error("Missing refresh token");
    }

    const response = await fetch(`${state.apiBase}/auth/refresh`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ refreshToken }),
    });

    let data = null;
    try {
      data = await response.json();
    } catch {
      data = null;
    }

    if (!response.ok || !data || !data.accessToken) {
      const msg = (data && (data.error || data.message)) || `HTTP ${response.status}`;
      throw new Error(msg);
    }

    localStorage.setItem("cashio_admin_token", data.accessToken);
    if (data.refreshToken) {
      localStorage.setItem("cashio_admin_refresh_token", data.refreshToken);
    }
    setToken(data.accessToken);
  }

  async function apiFetch(path, options, hasRetried) {
    updateApiBaseFromInput();
    const url = `${state.apiBase}${path}`;
    const headers = { ...(options && options.headers ? options.headers : {}) };

    if (state.token) {
      headers.Authorization = `Bearer ${state.token}`;
    }

    const response = await fetch(url, {
      ...(options || {}),
      headers,
    });

    let data = null;
    try {
      data = await response.json();
    } catch {
      data = null;
    }

    if (response.status === 401 && !hasRetried && path !== "/auth/refresh") {
      try {
        await refreshAccessToken();
        return apiFetch(path, options, true);
      } catch {
        clearAuthSession();
        redirectToLogin();
        throw new Error("Session expired. Please login again.");
      }
    }

    if (!response.ok) {
      const msg = (data && (data.error || data.message)) || `HTTP ${response.status}`;
      throw new Error(msg);
    }

    return data;
  }

  function mapAgent(raw) {
    const user = raw && raw.user ? raw.user : {};
    const fullName = [user.firstName, user.lastName].filter(Boolean).join(" ").trim();
    const normalizedStatus =
      typeof raw.status === "string" && raw.status.trim()
        ? raw.status.trim().toLowerCase()
        : raw.isBanned
          ? "banned"
          : raw.isVerified
            ? "verified"
            : "pending";

    return {
      id: raw.id,
      userId: user.id || "-",
      name: fullName || "Unnamed Agent",
      firstName: user.firstName || "-",
      lastName: user.lastName || "-",
      email: user.email || "-",
      phone: user.phone || "-",
      gender: user.gender || "-",
      maritalStatus: user.maritalStatus || "-",
      age: user.age ?? "-",
      address: user.address || "-",
      profileImage: user.profileImage || "-",
      locationName: raw.locationName || "-",
      city: raw.city || "-",
      latitude: raw.latitude ?? "-",
      longitude: raw.longitude ?? "-",
      state: raw.state || "-",
      isVerified: Boolean(raw.isVerified),
      isBanned: Boolean(raw.isBanned),
      available: Boolean(raw.available),
      cashLimit: raw.cashLimit ?? "-",
      status: normalizedStatus,
      createdAt: raw.createdAt || null,
      updatedAt: raw.updatedAt || null,
    };
  }

  function formatDate(dateStr) {
    if (!dateStr) {
      return "-";
    }

    const date = new Date(dateStr);
    if (Number.isNaN(date.getTime())) {
      return "-";
    }

    return date.toLocaleString();
  }

  function safeValue(value) {
    if (value === null || value === undefined || value === "") {
      return "-";
    }

    return String(value);
  }

  function resolveProfileImageSrc(value) {
    const raw = typeof value === "string" ? value.trim() : "";
    if (!raw || raw === "-") {
      return "";
    }

    if (raw.startsWith("data:image/")) {
      return raw;
    }

    if (raw.startsWith("http://") || raw.startsWith("https://")) {
      return raw;
    }

    if (raw.startsWith("/") || raw.startsWith("uploads/")) {
      const cleaned = raw.replace(/^\/+/, "");
      return `${state.apiBase}/${cleaned}`;
    }

    const looksLikeBase64 = /^[A-Za-z0-9+/=]+$/.test(raw) && raw.length > 120;
    if (looksLikeBase64) {
      return `data:image/jpeg;base64,${raw}`;
    }

    return "";
  }

  function renderProfileImage(value, name) {
    const src = resolveProfileImageSrc(value);
    const initials = String(name || "Agent")
      .trim()
      .split(/\s+/)
      .filter(Boolean)
      .slice(0, 2)
      .map((part) => part.charAt(0).toUpperCase())
      .join("") || "AG";

    if (!src) {
      return `
        <div class="profile-missing" title="Profile image not available">
          <span>${initials}</span>
        </div>
      `;
    }

    const href = encodeURI(src);
    return `
      <div class="profile-wrap">
        <a class="profile-link" href="${href}" target="_blank" rel="noopener">
          <img class="profile-image" src="${href}" alt="Profile image" loading="lazy" onerror="this.style.display='none'; this.parentElement.nextElementSibling.style.display='flex';">
          <span>Open image</span>
        </a>
        <div class="profile-missing" style="display:none" title="Profile image failed to load">
          <span>${initials}</span>
        </div>
      </div>
    `;
  }

  function statusBadgeClass(status) {
    if (status === "verified") {
      return "badge verified";
    }

    if (status === "banned") {
      return "badge banned";
    }

    if (status === "unverified") {
      return "badge unverified";
    }

    return "badge pending";
  }

  function statusLabel(status) {
    if (status === "verified") {
      return "Verified";
    }

    if (status === "banned") {
      return "Banned";
    }

    if (status === "unverified") {
      return "Unverified";
    }

    return "Pending";
  }

  function renderMetrics() {
    const total = state.agents.length;
    const verified = state.agents.filter((a) => a.status === "verified").length;
    const pending = state.agents.filter((a) => a.status === "pending" || a.status === "unverified").length;
    const banned = state.agents.filter((a) => a.status === "banned").length;

    el.totalAgents.textContent = String(total);
    el.verifiedAgents.textContent = String(verified);
    el.pendingAgents.textContent = String(pending);
    el.bannedAgents.textContent = String(banned);

    if (el.dashboardActiveAgents) {
      const activeAgents = state.agents.filter((agent) => agent.available && agent.status === "verified").length;
      el.dashboardActiveAgents.textContent = String(activeAgents);
    }
  }

  function renderDashboardOverview() {
    if (el.dashboardOngoingRequests) {
      el.dashboardOngoingRequests.textContent = String(state.dashboardOverview.ongoingRequests || 0);
    }

    const snapshot = state.dashboardOverview.todaySnapshot || {
      transactions: 0,
      totalVolume: 0,
      successRate: 0,
    };

    if (el.dashboardTransactionsToday) {
      el.dashboardTransactionsToday.textContent = String(snapshot.transactions || 0);
    }
    if (el.dashboardVolumeToday) {
      el.dashboardVolumeToday.textContent = formatCurrency(snapshot.totalVolume || 0);
    }
    if (el.dashboardSuccessRateToday) {
      const value = Number(snapshot.successRate || 0);
      el.dashboardSuccessRateToday.textContent = `${value.toFixed(1)}%`;
    }
  }

  function setDashboardOverviewLoading(isLoading) {
    const metricElements = [
      el.dashboardActiveAgents,
      el.dashboardOngoingRequests,
      el.dashboardTransactionsToday,
      el.dashboardVolumeToday,
      el.dashboardSuccessRateToday,
      el.dashboardHealthStatus,
    ];

    metricElements.forEach((node) => {
      if (!node) {
        return;
      }
      node.classList.toggle("metric-loading", isLoading);
      if (isLoading) {
        node.textContent = "...";
      }
    });
  }

  function transactionStatusBadgeClass(status) {
    if (status === "confirmed") {
      return "badge verified";
    }

    if (status === "approved") {
      return "badge live";
    }

    if (status === "cancelled") {
      return "badge banned";
    }

    if (status === "archived") {
      return "badge unverified";
    }

    return "badge pending";
  }

  function transactionStatusLabel(status) {
    const value = String(status || "").toLowerCase();
    if (value === "confirmed") {
      return "Confirmed";
    }
    if (value === "approved") {
      return "Approved";
    }
    if (value === "cancelled") {
      return "Cancelled";
    }
    if (value === "archived") {
      return "Archived";
    }
    return "Pending";
  }

  function mapTransaction(raw) {
    const userRaw = raw && raw.user ? raw.user : {};
    const agentRaw = raw && raw.agent ? raw.agent : {};

    return {
      id: raw && raw.id ? raw.id : "-",
      user: {
        name: userRaw.name || "Unknown User",
        phone: userRaw.phone || "-",
      },
      agent: {
        name: agentRaw.name || "Unknown Agent",
        phone: agentRaw.phone || "-",
      },
      amount: Number(raw && raw.amount ? raw.amount : 0),
      type: String((raw && raw.type) || "cash_request").toLowerCase(),
      status: String((raw && raw.status) || "pending").toLowerCase(),
      date: raw && raw.date ? raw.date : raw && raw.createdAt ? raw.createdAt : null,
    };
  }

  function formatCurrency(value) {
    const numeric = Number(value);
    if (!Number.isFinite(numeric)) {
      return "-";
    }
    return `Rs ${numeric.toLocaleString()}`;
  }

  function formatTransactionType(value) {
    const text = String(value || "").trim();
    if (!text) {
      return "-";
    }

    return text
      .replace(/_/g, " ")
      .split(" ")
      .filter(Boolean)
      .map((part) => part.charAt(0).toUpperCase() + part.slice(1).toLowerCase())
      .join(" ");
  }

  function matchesTransactionFilters(item) {
    const selectedStatus = (el.txStatusFilter && el.txStatusFilter.value) || "all";
    const search = ((el.txSearch && el.txSearch.value) || "").trim().toLowerCase();

    if (selectedStatus !== "all" && item.status !== selectedStatus) {
      return false;
    }

    if (!search) {
      return true;
    }

    const searchPool = [item.user.name, item.user.phone, item.agent.name, item.agent.phone]
      .join(" ")
      .toLowerCase();

    return searchPool.includes(search);
  }

  function renderTransactionRow(item) {
    return `
      <tr data-tx-id="${safeValue(item.id)}" data-tx-status="${safeValue(item.status)}">
        <td>
          <div class="agent-name">${safeValue(item.id)}</div>
        </td>
        <td>
          <div class="agent-name">${safeValue(item.user.name)}</div>
          <div class="agent-sub">${safeValue(item.user.phone)}</div>
        </td>
        <td>
          <div class="agent-name">${safeValue(item.agent.name)}</div>
          <div class="agent-sub">${safeValue(item.agent.phone)}</div>
        </td>
        <td>${formatCurrency(item.amount)}</td>
        <td>${formatTransactionType(item.type)}</td>
        <td><span class="${transactionStatusBadgeClass(item.status)}">${transactionStatusLabel(item.status)}</span></td>
        <td>${formatDate(item.date)}</td>
      </tr>
    `;
  }

  function openTxDetailModal() {
    if (!el.txDetailModal) {
      return;
    }
    el.txDetailModal.classList.add("open");
    el.txDetailModal.setAttribute("aria-hidden", "false");
  }

  function closeTxDetailModal() {
    if (!el.txDetailModal) {
      return;
    }
    el.txDetailModal.classList.remove("open");
    el.txDetailModal.setAttribute("aria-hidden", "true");
  }

  function verificationLabel(value) {
    return value ? "Yes" : "No";
  }

  function boolLabel(value) {
    return value ? "Yes" : "No";
  }

  function transactionHeaderLabel(status) {
    const normalized = String(status || "").toLowerCase();
    if (normalized === "confirmed") {
      return "Success";
    }
    if (normalized === "pending" || normalized === "approved") {
      return "Pending";
    }
    return "Failed";
  }

  function renderTxDetails(detail) {
    if (!el.txDetailBody) {
      return;
    }

    const transaction = detail || {};
    const user = transaction.user || {};
    const agent = transaction.agent || {};
    const location = agent.location || {};
    const verification = transaction.verification || {};
    const confirmations = verification.confirmations || {};
    const verificationTimestamps = verification.timestamps || {};
    const otpPresence = verification.otpPresence || {};
    const expiry = verification.expiry || {};
    const txTimestamps = transaction.timestamps || {};
    const rating = transaction.rating || {};

    const userRatingValue =
      rating.value === null || rating.value === undefined || Number.isNaN(Number(rating.value))
        ? "Not rated"
        : `${Number(rating.value)}/5`;
    const agentAverageValue =
      rating.agentAverage === null ||
      rating.agentAverage === undefined ||
      Number.isNaN(Number(rating.agentAverage))
        ? "-"
        : `${Number(rating.agentAverage).toFixed(2)}/5`;

    el.txDetailBody.innerHTML = `
      <section>
        <h3>Transaction</h3>
        <div class="detail-grid">
          <div class="detail-card"><span>ID</span><strong>${safeValue(transaction.id)}</strong></div>
          <div class="detail-card"><span>Amount</span><strong>${formatCurrency(transaction.amount)}</strong></div>
          <div class="detail-card"><span>Type</span><strong>${formatTransactionType(transaction.type)}</strong></div>
          <div class="detail-card"><span>Status</span><strong>${transactionStatusLabel(transaction.status)} (${transactionHeaderLabel(transaction.status)})</strong></div>
          <div class="detail-card"><span>Created At</span><strong>${formatDate(txTimestamps.createdAt || transaction.date)}</strong></div>
          <div class="detail-card"><span>Updated At</span><strong>${formatDate(txTimestamps.updatedAt)}</strong></div>
          <div class="detail-card"><span>Approved At</span><strong>${formatDate(txTimestamps.approvedAt)}</strong></div>
          <div class="detail-card"><span>Completed At</span><strong>${formatDate(txTimestamps.completedAt)}</strong></div>
        </div>
      </section>

      <section>
        <h3>User Details</h3>
        <div class="detail-grid">
          <div class="detail-card"><span>User ID</span><strong>${safeValue(user.id)}</strong></div>
          <div class="detail-card"><span>Name</span><strong>${safeValue(user.name)}</strong></div>
          <div class="detail-card"><span>Phone</span><strong>${safeValue(user.phone)}</strong></div>
          <div class="detail-card"><span>Email</span><strong>${safeValue(user.email)}</strong></div>
          <div class="detail-card"><span>Address</span><strong>${safeValue(user.address)}</strong></div>
        </div>
      </section>

      <section>
        <h3>Agent Details</h3>
        <div class="detail-grid">
          <div class="detail-card"><span>Agent ID</span><strong>${safeValue(agent.id)}</strong></div>
          <div class="detail-card"><span>Name</span><strong>${safeValue(agent.name)}</strong></div>
          <div class="detail-card"><span>Phone</span><strong>${safeValue(agent.phone)}</strong></div>
          <div class="detail-card"><span>Email</span><strong>${safeValue(agent.email)}</strong></div>
          <div class="detail-card"><span>Address</span><strong>${safeValue(agent.address)}</strong></div>
          <div class="detail-card"><span>Status</span><strong>${safeValue(agent.status)}</strong></div>
          <div class="detail-card"><span>Verified</span><strong>${boolLabel(Boolean(agent.isVerified))}</strong></div>
          <div class="detail-card"><span>Banned</span><strong>${boolLabel(Boolean(agent.isBanned))}</strong></div>
          <div class="detail-card"><span>Available</span><strong>${boolLabel(Boolean(agent.available))}</strong></div>
        </div>
      </section>

      <section>
        <h3>Location</h3>
        <div class="detail-grid">
          <div class="detail-card"><span>Shop / Location</span><strong>${safeValue(location.locationName)}</strong></div>
          <div class="detail-card"><span>City</span><strong>${safeValue(location.city)}</strong></div>
          <div class="detail-card"><span>Latitude</span><strong>${safeValue(location.latitude)}</strong></div>
          <div class="detail-card"><span>Longitude</span><strong>${safeValue(location.longitude)}</strong></div>
        </div>
      </section>

      <section>
        <h3>Verification</h3>
        <div class="detail-grid">
          <div class="detail-card"><span>OTP Verified</span><strong>${verificationLabel(Boolean(verification.otpVerified))}</strong></div>
          <div class="detail-card"><span>User Confirmed</span><strong>${verificationLabel(Boolean(confirmations.userConfirmed))}</strong></div>
          <div class="detail-card"><span>Agent Confirmed</span><strong>${verificationLabel(Boolean(confirmations.agentConfirmed))}</strong></div>
          <div class="detail-card"><span>Request OTP Generated</span><strong>${verificationLabel(Boolean(otpPresence.requestOtp))}</strong></div>
          <div class="detail-card"><span>User Confirm OTP Generated</span><strong>${verificationLabel(Boolean(otpPresence.userConfirmOtp))}</strong></div>
          <div class="detail-card"><span>Agent Confirm OTP Generated</span><strong>${verificationLabel(Boolean(otpPresence.agentConfirmOtp))}</strong></div>
          <div class="detail-card"><span>Approved At</span><strong>${formatDate(verificationTimestamps.approvedAt)}</strong></div>
          <div class="detail-card"><span>User Confirmed At</span><strong>${formatDate(verificationTimestamps.userConfirmedAt)}</strong></div>
          <div class="detail-card"><span>Agent Confirmed At</span><strong>${formatDate(verificationTimestamps.agentConfirmedAt)}</strong></div>
          <div class="detail-card"><span>Verification Completed At</span><strong>${formatDate(verificationTimestamps.completedAt)}</strong></div>
          <div class="detail-card"><span>Request OTP Expires</span><strong>${formatDate(expiry.requestOtpExpires)}</strong></div>
          <div class="detail-card"><span>Confirm OTP Expires</span><strong>${formatDate(expiry.confirmOtpExpires)}</strong></div>
        </div>
      </section>

      <section>
        <h3>Rating</h3>
        <div class="detail-grid">
          <div class="detail-card"><span>User Rating</span><strong>${safeValue(userRatingValue)}</strong></div>
          <div class="detail-card"><span>User Comment</span><strong>${safeValue(rating.comment)}</strong></div>
          <div class="detail-card"><span>Rated At</span><strong>${formatDate(rating.ratedAt)}</strong></div>
          <div class="detail-card"><span>Agent Average Rating</span><strong>${safeValue(agentAverageValue)}</strong></div>
          <div class="detail-card"><span>Total Rating Count</span><strong>${safeValue(rating.agentCount)}</strong></div>
        </div>
      </section>
    `;
  }

  async function onTransactionTableClick(event) {
    const row = event.target.closest("tr[data-tx-id]");
    if (!row) {
      return;
    }

    const txId = row.dataset.txId;
    const txStatus = String(row.dataset.txStatus || "").toLowerCase();

    if (!txId) {
      return;
    }

    if (txStatus !== "confirmed" && txStatus !== "cancelled") {
      showToast("Transaction details are available only for confirmed or cancelled transactions.", "error");
      return;
    }

    openTxDetailModal();
    if (el.txDetailBody) {
      el.txDetailBody.innerHTML = `<p class="empty-state">Loading transaction details...</p>`;
    }

    try {
      const detail = await apiFetch(`/admin/transactions/${txId}`, { method: "GET" });
      renderTxDetails(detail);
    } catch (error) {
      if (el.txDetailBody) {
        el.txDetailBody.innerHTML = `<p class="empty-state">Failed to load details: ${safeValue(error.message)}</p>`;
      }
    }
  }

  function renderTransactionsTable() {
    if (!el.transactionsTbody) {
      return;
    }

    if (!state.filteredTransactions.length) {
      el.transactionsTbody.innerHTML = `
        <tr>
          <td colspan="7" class="empty-state">No transactions found for current filters.</td>
        </tr>
      `;
      return;
    }

    el.transactionsTbody.innerHTML = state.filteredTransactions.map(renderTransactionRow).join("");
  }

  function applyTransactionFilters() {
    state.filteredTransactions = state.transactions.filter(matchesTransactionFilters);
    renderTransactionsTable();
  }

  function renderReports() {
    const report = state.reportLoaded
      ? state.reportTransactions
      : {
          totalTransactions: 0,
          totalVolume: 0,
          successRate: 0,
          transactionsPerDay: [],
        };

    if (el.reportTotalTransactions) {
      el.reportTotalTransactions.textContent = String(report.totalTransactions || 0);
    }
    if (el.reportTotalVolume) {
      el.reportTotalVolume.textContent = formatCurrency(report.totalVolume || 0);
    }
    if (el.reportSuccessRate) {
      const value = Number(report.successRate || 0);
      el.reportSuccessRate.textContent = `${value.toFixed(1)}%`;
    }

    if (!el.reportDayBars) {
      return;
    }

    const rows = Array.isArray(report.transactionsPerDay) ? report.transactionsPerDay : [];
    if (!rows.length) {
      el.reportDayBars.innerHTML = `<div class="empty-state">No daily transaction data available.</div>`;
      return;
    }

    const maxCount = Math.max(...rows.map((row) => Number(row.count) || 0), 1);
    el.reportDayBars.innerHTML = rows
      .map((row) => {
        const count = Number(row.count) || 0;
        const width = Math.round((count / maxCount) * 100);
        const date = new Date(`${row.date}T00:00:00`);
        const label = Number.isNaN(date.getTime())
          ? row.date
          : date.toLocaleDateString(undefined, { month: "short", day: "numeric" });
        return `
          <div class="day-bar-row">
            <span class="day-label">${label}</span>
            <div class="day-track"><div class="day-fill" style="width: ${width}%"></div></div>
            <span class="day-count">${count}</span>
          </div>
        `;
      })
      .join("");
  }

  function matchesActiveFilters(agent) {
    const search = (el.agentSearch.value || "").trim().toLowerCase();
    const status = el.statusFilter.value;

    const normalizedStatus = agent.status === "unverified" ? "pending" : agent.status;
    const matchesStatus = status === "all" ? true : normalizedStatus === status;
    if (!matchesStatus) {
      return false;
    }

    if (!search) {
      return true;
    }

    const searchPool = [
      agent.name,
      agent.firstName,
      agent.lastName,
      agent.phone,
    ]
      .filter(Boolean)
      .join(" ")
      .toLowerCase();

    return searchPool.includes(search);
  }

  function renderAgentRow(agent, rowClass) {
    return `
      <tr class="${rowClass}" data-row-id="${agent.id}">
        <td>
          <div class="agent-name">${safeValue(agent.name)}</div>
          <div class="agent-sub">ID: ${safeValue(agent.id)}</div>
        </td>
        <td>${safeValue(agent.email)}</td>
        <td>${safeValue(agent.phone)}</td>
        <td>${safeValue(agent.city)}, ${safeValue(agent.state)}</td>
        <td><span class="${statusBadgeClass(agent.status)}">${statusLabel(agent.status)}</span></td>
        <td>${formatDate(agent.createdAt)}</td>
        <td>${createActionButtons(agent)}</td>
      </tr>
    `;
  }

  function createActionButtons(agent) {
    const actions = [];

    if (agent.status === "banned") {
      actions.push({ key: "unban", label: "Unban", className: "unban" });
    } else if (agent.status === "verified") {
      actions.push({ key: "unverify", label: "Unverify", className: "unverify" });
      actions.push({ key: "ban", label: "Ban", className: "ban" });
    } else {
      actions.push({ key: "verify", label: "Verify", className: "verify" });
      actions.push({ key: "ban", label: "Ban", className: "ban" });
    }

    const buttons = actions
      .map(
        (action) =>
          `<button class="action-btn ${action.className}" data-action="${action.key}" data-id="${agent.id}" type="button">${action.label}</button>`
      )
      .join("");

    return `
      <div class="action-wrap">
        ${buttons}
      </div>
    `;
  }

  function renderAgentsTable() {
    const list = state.filteredAgents;

    if (!list.length) {
      el.agentsTbody.innerHTML = `
        <tr>
          <td colspan="7" class="empty-state">No agents found for current filter/search.</td>
        </tr>
      `;
      renderSelectedAgentDetail(null);
      return;
    }

    el.agentsTbody.innerHTML = list
      .map((agent) => {
        const rowClass = state.selectedAgentId === agent.id ? "active-row" : "";
        return renderAgentRow(agent, rowClass);
      })
      .join("");

    const selected = list.find((item) => item.id === state.selectedAgentId) || list[0];
    state.selectedAgentId = selected.id;
    renderSelectedAgentDetail(selected);

    const activeRow = el.agentsTbody.querySelector(`tr[data-row-id="${selected.id}"]`);
    if (activeRow) {
      activeRow.classList.add("active-row");
    }
  }

  function renderSelectedAgentDetail(agent) {
    if (!agent) {
      el.selectedAgent.innerHTML = "Select an agent row to view details.";
      return;
    }

    el.selectedAgent.innerHTML = `
      <div class="agent-grid compact">
        <div class="item"><span>Name</span><strong>${safeValue(agent.name)}</strong></div>
        <div class="item"><span>First Name</span><strong>${safeValue(agent.firstName)}</strong></div>
        <div class="item"><span>Last Name</span><strong>${safeValue(agent.lastName)}</strong></div>
        <div class="item"><span>Email</span><strong>${safeValue(agent.email)}</strong></div>
        <div class="item"><span>Phone</span><strong>${safeValue(agent.phone)}</strong></div>
        <div class="item"><span>Gender</span><strong>${safeValue(agent.gender)}</strong></div>
        <div class="item"><span>Marital Status</span><strong>${safeValue(agent.maritalStatus)}</strong></div>
        <div class="item"><span>Age</span><strong>${safeValue(agent.age)}</strong></div>
        <div class="item"><span>Address</span><strong>${safeValue(agent.address)}</strong></div>
        <div class="item full"><span>Profile Image</span>${renderProfileImage(agent.profileImage, agent.name)}</div>
        <div class="item"><span>Location Name</span><strong>${safeValue(agent.locationName)}</strong></div>
        <div class="item"><span>City / State</span><strong>${safeValue(agent.city)} / ${safeValue(agent.state)}</strong></div>
        <div class="item"><span>Latitude</span><strong>${safeValue(agent.latitude)}</strong></div>
        <div class="item"><span>Longitude</span><strong>${safeValue(agent.longitude)}</strong></div>
        <div class="item"><span>Cash Limit</span><strong>${safeValue(agent.cashLimit)}</strong></div>
        <div class="item"><span>Available</span><strong>${agent.available ? "Yes" : "No"}</strong></div>
        <div class="item"><span>Verified</span><strong>${agent.isVerified ? "Yes" : "No"}</strong></div>
        <div class="item"><span>Banned</span><strong>${agent.isBanned ? "Yes" : "No"}</strong></div>
        <div class="item"><span>Status</span><strong>${statusLabel(agent.status)}</strong></div>
        <div class="item"><span>User ID</span><strong>${safeValue(agent.userId)}</strong></div>
        <div class="item"><span>Agent ID</span><strong>${safeValue(agent.id)}</strong></div>
        <div class="item"><span>Created</span><strong>${formatDate(agent.createdAt)}</strong></div>
        <div class="item"><span>Updated</span><strong>${formatDate(agent.updatedAt)}</strong></div>
      </div>
    `;
  }

  function applyFilters() {
    state.filteredAgents = state.agents.filter(matchesActiveFilters);

    renderAgentsTable();
  }

  async function fetchAgents() {
    if (!state.token) {
      redirectToLogin();
      return;
    }

    el.refreshBtn.disabled = true;
    try {
      const result = await apiFetch("/admin/agents", { method: "GET" });
      const agentsRaw = Array.isArray(result)
        ? result
        : Array.isArray(result && result.agents)
          ? result.agents
          : [];
      state.agents = agentsRaw.map(mapAgent);
      renderMetrics();
      applyFilters();
      showToast("Agents loaded successfully.", "ok");
    } catch (error) {
      showToast(`Failed to load agents: ${error.message}`, "error");
    } finally {
      el.refreshBtn.disabled = false;
    }
  }

  async function fetchTransactions() {
    if (!state.token) {
      redirectToLogin();
      return;
    }

    if (!el.txRefreshBtn) {
      return;
    }

    el.txRefreshBtn.disabled = true;
    try {
      const result = await apiFetch("/admin/transactions?limit=300", { method: "GET" });
      const txRaw = Array.isArray(result)
        ? result
        : Array.isArray(result && result.items)
          ? result.items
          : [];

      state.transactions = txRaw.map(mapTransaction);
      state.transactionsLoaded = true;
      applyTransactionFilters();
      renderReports();
      showToast("Transactions loaded successfully.", "ok");
    } catch (error) {
      showToast(`Failed to load transactions: ${error.message}`, "error");
    } finally {
      el.txRefreshBtn.disabled = false;
    }
  }

  async function fetchReportTransactions() {
    if (!state.token) {
      redirectToLogin();
      return;
    }

    if (!el.reportRefreshBtn) {
      return;
    }

    el.reportRefreshBtn.disabled = true;

    try {
      const result = await apiFetch(`/admin/reports?days=7`, { method: "GET" });
      state.reportTransactions = result || {
        totalTransactions: 0,
        totalVolume: 0,
        successRate: 0,
        transactionsPerDay: [],
      };
      state.reportLoaded = true;
      renderReports();
    } catch (error) {
      showToast(`Failed to load reports: ${error.message}`, "error");
    } finally {
      el.reportRefreshBtn.disabled = false;
    }
  }

  async function fetchDashboardOverview() {
    if (!state.token) {
      return;
    }

    setDashboardOverviewLoading(true);
    try {
      const result = await apiFetch(`/admin/reports?days=7`, { method: "GET" });
      state.dashboardOverview = {
        ongoingRequests: Number((result && result.ongoingRequests) || 0),
        todaySnapshot: {
          transactions: Number(result && result.todaySnapshot && result.todaySnapshot.transactions ? result.todaySnapshot.transactions : 0),
          totalVolume: Number(result && result.todaySnapshot && result.todaySnapshot.totalVolume ? result.todaySnapshot.totalVolume : 0),
          successRate: Number(result && result.todaySnapshot && result.todaySnapshot.successRate ? result.todaySnapshot.successRate : 0),
        },
      };
      renderDashboardOverview();
    } catch {
      // Keep dashboard usable even when overview metrics fail.
    } finally {
      setDashboardOverviewLoading(false);
    }
  }

  function applyAgentStatus(agentId, status) {
    const normalizedStatus = String(status || "").toLowerCase();

    state.agents = state.agents.map((agent) => {
      if (agent.id !== agentId) {
        return agent;
      }

      const isVerified = normalizedStatus === "verified";
      const isBanned = normalizedStatus === "banned";
      return {
        ...agent,
        status: normalizedStatus,
        isVerified,
        isBanned,
        available: isBanned ? false : agent.available,
      };
    });
  }

  function syncSingleRow(agentId) {
    state.filteredAgents = state.agents.filter(matchesActiveFilters);

    const agent = state.agents.find((item) => item.id === agentId);
    const row = el.agentsTbody.querySelector(`tr[data-row-id="${agentId}"]`);
    const isVisible = state.filteredAgents.some((item) => item.id === agentId);

    if (agent && isVisible) {
      const rowClass = state.selectedAgentId === agentId ? "active-row" : "";
      const rowHtml = renderAgentRow(agent, rowClass);

      if (row) {
        row.outerHTML = rowHtml;
      } else {
        const empty = el.agentsTbody.querySelector(".empty-state");
        if (empty) {
          el.agentsTbody.innerHTML = "";
        }
        el.agentsTbody.insertAdjacentHTML("beforeend", rowHtml);
      }
    } else if (row) {
      row.remove();
    }

    if (!state.filteredAgents.length) {
      el.agentsTbody.innerHTML = `
        <tr>
          <td colspan="7" class="empty-state">No agents found for current filter/search.</td>
        </tr>
      `;
      state.selectedAgentId = null;
      renderSelectedAgentDetail(null);
      return;
    }

    if (state.selectedAgentId === agentId) {
      if (agent && isVisible) {
        renderSelectedAgentDetail(agent);
      } else {
        const next = state.filteredAgents[0];
        state.selectedAgentId = next.id;
        renderSelectedAgentDetail(next);

        const nextRow = el.agentsTbody.querySelector(`tr[data-row-id="${next.id}"]`);
        if (nextRow) {
          nextRow.classList.add("active-row");
        }
      }
    }
  }

  async function runModerationAction(agentId, action) {
    const endpointByAction = {
      verify: "verify",
      unverify: "unverify",
      ban: "ban",
      unban: "unban",
    };

    const endpoint = endpointByAction[action];
    if (!endpoint) {
      showToast("Unsupported moderation action.", "error");
      return;
    }

    el.refreshBtn.disabled = true;
    try {
      const result = await apiFetch(`/admin/agents/${agentId}/${endpoint}`, {
        method: "PATCH",
      });

      if (result && result.status) {
        applyAgentStatus(agentId, result.status);
      }

      renderMetrics();
      syncSingleRow(agentId);
      showToast(
        (result && result.message) || "Agent status updated successfully.",
        "ok"
      );
    } catch (error) {
      showToast(`Failed to update agent: ${error.message}`, "error");
    } finally {
      el.refreshBtn.disabled = false;
    }
  }

  async function fetchHealthAndVersion() {
    updateApiBaseFromInput();

    try {
      const health = await fetch(`${state.apiBase}/health`);
      if (health.ok) {
        const healthBody = await health.json();
        el.healthStatus.textContent = `Healthy (${healthBody && healthBody.status ? healthBody.status : "ok"})`;
        if (el.dashboardHealthStatus) {
          el.dashboardHealthStatus.textContent = "Healthy";
        }
      } else {
        el.healthStatus.textContent = `Unhealthy (HTTP ${health.status})`;
        if (el.dashboardHealthStatus) {
          el.dashboardHealthStatus.textContent = `Unhealthy (${health.status})`;
        }
      }
    } catch {
      el.healthStatus.textContent = "Unavailable";
      if (el.dashboardHealthStatus) {
        el.dashboardHealthStatus.textContent = "Unavailable";
      }
    }

    try {
      const version = await fetch(`${state.apiBase}/version`);
      if (version.ok) {
        const versionBody = await version.json();
        const name = versionBody && versionBody.name ? versionBody.name : "backend";
        const ver = versionBody && versionBody.version ? versionBody.version : "unknown";
        el.versionStatus.textContent = `${name} ${ver}`;
      } else {
        el.versionStatus.textContent = `HTTP ${version.status}`;
      }
    } catch {
      el.versionStatus.textContent = "Unavailable";
    }
  }

  function redirectToLogin() {
    updateApiBaseFromInput();
    window.location.href = "AuthScreen/index.html";
  }

  function logout() {
    clearAuthSession();
    redirectToLogin();
  }

  function onTableClick(event) {
    const actionBtn = event.target.closest("button[data-action]");
    if (actionBtn) {
      const action = actionBtn.dataset.action;
      const agentId = actionBtn.dataset.id;
      const agent = state.agents.find((item) => item.id === agentId);
      if (!agent) {
        return;
      }

      if (action === "verify") {
        runModerationAction(agentId, "verify");
      }

      if (action === "unverify") {
        runModerationAction(agentId, "unverify");
      }

      if (action === "ban") {
        runModerationAction(agentId, "ban");
      }

      if (action === "unban") {
        runModerationAction(agentId, "unban");
      }

      return;
    }

    const row = event.target.closest("tr[data-row-id]");
    if (!row) {
      return;
    }

    state.selectedAgentId = row.dataset.rowId;
    renderAgentsTable();
  }

  function bootstrap() {
    const savedApiBase = localStorage.getItem("cashio_admin_api_base");
    el.apiBaseUrl.value = normalizeApiBase(savedApiBase || el.apiBaseUrl.value);
    updateApiBaseFromInput();

    const savedToken = localStorage.getItem("cashio_admin_token") || "";
    setToken(savedToken);

    if (!savedToken) {
      redirectToLogin();
      return;
    }

    if (!state.tokenPayload || state.tokenPayload.role !== "admin") {
      localStorage.removeItem("cashio_admin_token");
      localStorage.removeItem("cashio_admin_refresh_token");
      redirectToLogin();
      return;
    }

    el.totalAgents.textContent = "0";
    el.verifiedAgents.textContent = "0";
    el.pendingAgents.textContent = "0";
    el.bannedAgents.textContent = "0";
    renderAgentsTable();
    renderTransactionsTable();
    renderReports();
    renderDashboardOverview();

    setActivePage(resolvePage(window.location.hash.replace("#", "")), false);

    el.apiBaseUrl.addEventListener("change", () => {
      updateApiBaseFromInput();
      fetchHealthAndVersion();
    });
    el.refreshBtn.addEventListener("click", fetchAgents);
    el.logoutBtn.addEventListener("click", logout);
    el.agentSearch.addEventListener("input", applyFilters);
    el.statusFilter.addEventListener("change", applyFilters);
    el.agentsTbody.addEventListener("click", onTableClick);
    if (el.txSearch) {
      el.txSearch.addEventListener("input", applyTransactionFilters);
    }
    if (el.txStatusFilter) {
      el.txStatusFilter.addEventListener("change", applyTransactionFilters);
    }
    if (el.txRefreshBtn) {
      el.txRefreshBtn.addEventListener("click", fetchTransactions);
    }
    if (el.transactionsTbody) {
      el.transactionsTbody.addEventListener("click", onTransactionTableClick);
    }
    if (el.txDetailCloseBtn) {
      el.txDetailCloseBtn.addEventListener("click", closeTxDetailModal);
    }
    if (el.txDetailModal) {
      el.txDetailModal.addEventListener("click", (event) => {
        const target = event.target;
        if (!(target instanceof HTMLElement)) {
          return;
        }
        if (target.dataset && target.dataset.closeModal === "true") {
          closeTxDetailModal();
        }
      });
    }
    if (el.reportRefreshBtn) {
      el.reportRefreshBtn.addEventListener("click", fetchReportTransactions);
    }
    el.navItems.forEach((item) => {
      item.addEventListener("click", () => {
        setActivePage(item.dataset.page, true);
      });
    });
    window.addEventListener("hashchange", () => {
      setActivePage(resolvePage(window.location.hash.replace("#", "")), false);
    });

    fetchHealthAndVersion();
    if (savedToken) {
      fetchAgents();
      fetchDashboardOverview();
    }
  }

  bootstrap();
});
