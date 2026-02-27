function svg(bg: string, path: string): string {
	const markup = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 144 144">
  <rect width="144" height="144" rx="18" fill="${bg}"/>
  <g fill="white" transform="translate(72,72)">${path}</g>
</svg>`;
	return `data:image/svg+xml,${encodeURIComponent(markup)}`;
}

// Green — play triangle
export const ICON_START = svg(
	"#16a34a",
	`<polygon points="-22,-28 26,0 -22,28" />`
);

// Red — stop square
export const ICON_STOP = svg(
	"#dc2626",
	`<rect x="-24" y="-24" width="48" height="48" rx="4"/>`
);

// Blue — skip forward (bar + triangle)
export const ICON_NEXT = svg(
	"#2563eb",
	`<polygon points="-28,-28 16,0 -28,28"/>
   <rect x="18" y="-28" width="10" height="56" rx="3"/>`
);

// Blue — skip backward (bar + triangle)
export const ICON_PREVIOUS = svg(
	"#2563eb",
	`<polygon points="28,-28 -16,0 28,28"/>
   <rect x="-28" y="-28" width="10" height="56" rx="3"/>`
);

// Gray — pulse/status circle
export const ICON_STATUS = svg(
	"#4b5563",
	`<circle cx="0" cy="0" r="26" opacity="0.4"/>
   <circle cx="0" cy="0" r="16"/>`
);

// Lila — vote up arrow
export const ICON_VOTE_UP = svg(
	"#7c3aed",
	`<polygon points="0,-30 26,10 -26,10"/>`
);

// Lila — vote down arrow
export const ICON_VOTE_DOWN = svg(
	"#7c3aed",
	`<polygon points="0,30 26,-10 -26,-10"/>`
);

// Lila — vote display (star outline)
export function iconVote(rating: number): string {
	return svg(
		"#7c3aed",
		`<text x="0" y="12" text-anchor="middle" font-size="52" font-family="sans-serif" font-weight="bold" fill="white">${rating}</text>`
	);
}
