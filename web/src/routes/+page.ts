import { error } from '@sveltejs/kit';
import type { AlbumSummary } from '$lib/types';

export async function load({ fetch }) {
	const response = await fetch('/albums/albums.json');
	if (!response.ok) {
		error(response.status, 'Failed to load albums');
	}
	const albums: AlbumSummary[] = await response.json();
	return { albums };
}
