import { error } from '@sveltejs/kit';
import type { AlbumIndex, AlbumSummary } from '$lib/types';

export async function load({ params, fetch }) {
	const [albumRes, albumsRes] = await Promise.all([
		fetch(`/albums/${params.slug}/index.json`),
		fetch('/albums/albums.json')
	]);
	if (!albumRes.ok) {
		error(albumRes.status, `Album "${params.slug}" not found`);
	}
	const album: AlbumIndex = await albumRes.json();
	const albumMeta = albumsRes.ok
		? (await albumsRes.json() as AlbumSummary[]).find((a) => a.slug === params.slug)
		: null;
	const photoIndex = params.index ? parseInt(params.index) - 1 : null;
	return { album, slug: params.slug, dateSpan: albumMeta?.dateSpan ?? '', description: albumMeta?.description ?? '', photoIndex };
}
