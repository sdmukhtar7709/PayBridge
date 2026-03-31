const apiBaseInput = document.getElementById('apiBaseInput');
const loginForm = document.getElementById('loginForm');
const loginSubmit = document.getElementById('loginSubmit');
const loginStatus = document.getElementById('loginStatus');

function normalizeApiBase(url) {
    const fallback = 'http://localhost:4000';
    const value = (url || '').trim() || fallback;
    return value.endsWith('/') ? value.slice(0, -1) : value;
}

function decodeJwtPayload(token) {
    try {
        const parts = token.split('.');
        if (parts.length < 2) {
            return null;
        }

        const payload = parts[1].replace(/-/g, '+').replace(/_/g, '/');
        const padded = payload + '==='.slice((payload.length + 3) % 4);
        return JSON.parse(atob(padded));
    } catch {
        return null;
    }
}

function setStatus(target, message, type) {
    target.textContent = message || '';
    target.classList.remove('error', 'success');
    if (type) {
        target.classList.add(type);
    }
}

async function postJson(path, body) {
    const apiBase = normalizeApiBase(apiBaseInput.value);
    apiBaseInput.value = apiBase;
    localStorage.setItem('cashio_admin_api_base', apiBase);

    const response = await fetch(`${apiBase}${path}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(body),
    });

    let data = null;
    try {
        data = await response.json();
    } catch {
        data = null;
    }

    if (!response.ok) {
        const message = (data && (data.error?.message || data.error || data.message)) || `HTTP ${response.status}`;
        throw new Error(message);
    }

    return data;
}

async function loginAdminSession(email, password) {
    return postJson('/auth/login-with-refresh', { email, password });
}

loginForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    setStatus(loginStatus, '');

    const email = document.getElementById('loginEmail').value.trim();
    const password = document.getElementById('loginPassword').value;

    if (!email || !password) {
        setStatus(loginStatus, 'Email and password are required.', 'error');
        return;
    }

    loginSubmit.disabled = true;
    try {
        const session = await loginAdminSession(email, password);
        if (!session || !session.accessToken) {
            throw new Error('Login response missing access token');
        }

        const payload = decodeJwtPayload(session.accessToken);
        if (!payload || payload.role !== 'admin') {
            localStorage.removeItem('cashio_admin_token');
            localStorage.removeItem('cashio_admin_refresh_token');
            setStatus(loginStatus, 'Login is valid but account is not admin role.', 'error');
            return;
        }

        localStorage.setItem('cashio_admin_token', session.accessToken);
        if (session.refreshToken) {
            localStorage.setItem('cashio_admin_refresh_token', session.refreshToken);
        }

        setStatus(loginStatus, 'Login successful. Redirecting...', 'success');
        window.location.href = '../index.html';
    } catch (error) {
        setStatus(loginStatus, `Login failed: ${error.message}`, 'error');
    } finally {
        loginSubmit.disabled = false;
    }
});

const savedApiBase = localStorage.getItem('cashio_admin_api_base');
apiBaseInput.value = normalizeApiBase(savedApiBase || apiBaseInput.value);