'use strict';

(function() {
	const params = new URLSearchParams(window.location.hash.slice(1));
	window.history.replaceState(null, '', window.location.pathname);
	const state = params.get('state');
	const code = params.get('code');
	const chinese = navigator.language.toLowerCase().startsWith('zh');
	const status = document.getElementById('status');
	if (Array.from(params.keys()).length !== 2 || !/^[A-Za-z0-9_-]{43}$/.test(state || '') || !/^[A-Za-z0-9_-]{43}$/.test(code || '')) {
		status.textContent = chinese ? '登录请求无效，请返回路由器重新登录。' : 'Invalid login. Return to the router and sign in again.';
		return;
	}
	const message = { type: 'iping-login', code: code, state: state };
	if (window.opener)
		window.opener.postMessage(message, window.location.origin);
	if (typeof BroadcastChannel !== 'undefined') {
		const channel = new BroadcastChannel('iping-login');
		channel.postMessage(message);
		window.setTimeout(function() { channel.close(); }, 1000);
	}
	status.textContent = chinese ? '授权已返回路由器，请回到原来的 iPing 页面。此标签页可以关闭。' :
		'Authorization returned to the router. Go back to the original iPing page. You may close this tab.';
})();
