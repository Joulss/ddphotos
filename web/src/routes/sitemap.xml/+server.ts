export const prerender = true;

import type { RequestHandler } from '@sveltejs/kit';

export const GET: RequestHandler = async ({ fetch }) => {
	const res = await fetch('/albums/sitemap.xml');
	const body = await res.text();

	return new Response(body, {
		headers: { 'Content-Type': 'application/xml' }
	});
};
