// Shared by popover_controller.js (click-triggered facet panels) and
// hovercard_controller.js (hover/focus-triggered price-table cards): clamps a
// popover's position under its anchor to the viewport, flipping above when
// there's no room below.
export function clampToViewport(anchorRect, boxRect, { margin = 8, gap = 6 } = {}) {
  const left = Math.max(margin, Math.min(anchorRect.left, window.innerWidth - boxRect.width - margin))
  const fitsBelow = anchorRect.bottom + gap + boxRect.height <= window.innerHeight - margin
  const top = fitsBelow ? anchorRect.bottom + gap : Math.max(margin, anchorRect.top - gap - boxRect.height)
  return { left, top }
}
