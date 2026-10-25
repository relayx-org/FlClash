'use strict';

(() => {
 let login = null;
 let broadcast = null;
 window.ipingReadPreferences = () => { try { return localStorage.getItem('iping.ui.v1') || '{}'; } catch (_) { return '{}'; } };
 window.ipingWritePreferences = value => { try { localStorage.setItem('iping.ui.v1', value); } catch (_) {} };
 async function fetchJson(path, options = {}) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 18000);
  try {
   const response = await fetch(path, { credentials: 'same-origin', ...options, signal: controller.signal });
   const result = await response.json();
   if (!response.ok || !result.ok) throw new Error(result.error || 'request_failed');
   return result.data ?? null;
  } finally { clearTimeout(timeout); }
 }
 window.ipingRequest = async (method, args) => JSON.stringify(await fetchJson('/api/' + encodeURIComponent(method), {
  method: 'POST', headers: { 'Content-Type': 'application/json' }, body: args
 }));
	const request = (method, args = {}) => window.ipingRequest(method, JSON.stringify(args)).then(JSON.parse);
	function clearLogin(current) {
		clearTimeout(current.timeout);
		clearInterval(current.closedTimer);
		if (login === current) login = null;
	}
	async function receive(data) {
		const current = login;
		if (!current || !data || data.type !== 'iping-login' || data.state !== current.state || !/^[A-Za-z0-9_-]{43}$/.test(data.code || '')) return;
		clearLogin(current);
		try {
			await request('complete_login', { code: data.code, state: data.state });
			current.popup.close();
			await request('sync');
			current.resolve(null);
		} catch (error) { current.reject(error); }
	}
	window.addEventListener('message', event => {
		if (event.origin !== location.origin) return;
		const data = event.data;
		receive(data);
	});
	if (typeof BroadcastChannel !== 'undefined') {
		broadcast = new BroadcastChannel('iping-login');
		broadcast.onmessage = event => receive(event.data);
	}
	window.ipingCancelSignIn = () => {
		if (!login) return;
		const current = login;
		clearLogin(current);
		current.popup.close();
		request('cancel_login').catch(() => {});
		current.resolve(null);
	};
	window.ipingSignIn = register => new Promise((resolve, reject) => {
		if (login) return reject(new Error('A login is already in progress.'));
		const popup = window.open('about:blank', 'iping-openwrt-login');
		if (!popup) return reject(new Error('Allow pop-ups for this router to sign in.'));
		const current = { popup, resolve, reject };
		login = current;
		current.timeout = setTimeout(window.ipingCancelSignIn, 5 * 60 * 1000);
		current.closedTimer = setInterval(() => { if (popup.closed) window.ipingCancelSignIn(); }, 500);
		request('begin_login', { redirect_uri: new URL('/iping-login.html', location.origin).href }).then(data => {
			if (login !== current) return;
			current.state = data.state;
			let url = data.url;
			if (register) {
				const authorize = new URL(url);
				const registration = new URL('/handler/sign-up', authorize.origin);
				registration.searchParams.set('after_auth_return_to', authorize.pathname + authorize.search);
				url = registration.href;
			}
			popup.location.replace(url);
		}).catch(error => { clearLogin(current); popup.close(); reject(error); });
	});
	window.ipingOpen = url => window.open(url, '_blank', 'noopener,noreferrer');
	window.ipingDownload = (name, content) => {
		const url = URL.createObjectURL(new Blob([content], { type: 'text/plain;charset=utf-8' }));
		const link = document.createElement('a');
		link.href = url;
		link.download = name;
		link.click();
		setTimeout(() => URL.revokeObjectURL(url), 1000);
	};
	window.addEventListener('pagehide', () => {
		window.ipingCancelSignIn();
		broadcast?.close();
	});
})();
