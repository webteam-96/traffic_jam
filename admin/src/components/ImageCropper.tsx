import { useEffect, useRef, useState } from "react";

/**
 * The app draws Jay's portrait in a 100x100 circle
 * (about_jay_kotecha_screen.dart — BoxShape.circle + ClipOval), so the crop is
 * square with a circular preview: what falls outside the circle is what the
 * app clips away.
 */
export const APP_PORTRAIT_LOGICAL_PX = 100;

/**
 * Exported at 4x the app's logical size. Android tops out around 4x device
 * pixel ratio, so 400px keeps the portrait sharp on the densest screens while
 * a cropped JPEG at this size lands around 30-60 KB — small enough that the
 * old "image too large" ceiling stops being something anyone can hit.
 */
export const EXPORT_PX = APP_PORTRAIT_LOGICAL_PX * 4;

/** On-screen size of the cropping stage. */
const STAGE_PX = 320;

interface Props {
  file: File;
  onCancel: () => void;
  /** Receives a square, already-resized JPEG data URI — nothing left to do app-side. */
  onCropped: (dataUri: string) => void;
}

export function ImageCropper({ file, onCancel, onCropped }: Props) {
  const [image, setImage] = useState<HTMLImageElement | null>(null);
  const [zoom, setZoom] = useState(1);
  const [offset, setOffset] = useState({ x: 0, y: 0 });
  const [error, setError] = useState<string | null>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const dragging = useRef<{ x: number; y: number } | null>(null);

  useEffect(() => {
    const url = URL.createObjectURL(file);
    const img = new Image();
    img.onload = () => {
      setImage(img);
      // Start at "cover": the smaller side fills the stage, so there is never
      // a blank edge inside the crop no matter the source aspect ratio.
      setZoom(1);
      setOffset({ x: 0, y: 0 });
      URL.revokeObjectURL(url);
    };
    img.onerror = () => {
      setError("That file couldn't be read as an image.");
      URL.revokeObjectURL(url);
    };
    img.src = url;
  }, [file]);

  // Scale that makes the image exactly cover the square stage.
  const baseScale = image ? Math.max(STAGE_PX / image.width, STAGE_PX / image.height) : 1;
  const scale = baseScale * zoom;

  /** Keeps the image covering the stage, so panning can't expose empty space. */
  const clamp = (next: { x: number; y: number }, atScale: number) => {
    if (!image) return next;
    const limitX = Math.max(0, (image.width * atScale - STAGE_PX) / 2);
    const limitY = Math.max(0, (image.height * atScale - STAGE_PX) / 2);
    return {
      x: Math.min(limitX, Math.max(-limitX, next.x)),
      y: Math.min(limitY, Math.max(-limitY, next.y)),
    };
  };

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas || !image) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    ctx.clearRect(0, 0, STAGE_PX, STAGE_PX);
    ctx.save();
    const w = image.width * scale;
    const h = image.height * scale;
    ctx.drawImage(image, (STAGE_PX - w) / 2 + offset.x, (STAGE_PX - h) / 2 + offset.y, w, h);
    ctx.restore();

    // Dim everything the circle will clip, so the admin sees the app's view.
    ctx.save();
    ctx.fillStyle = "rgba(12, 10, 24, 0.62)";
    ctx.beginPath();
    ctx.rect(0, 0, STAGE_PX, STAGE_PX);
    ctx.arc(STAGE_PX / 2, STAGE_PX / 2, STAGE_PX / 2, 0, Math.PI * 2);
    ctx.fill("evenodd");
    ctx.strokeStyle = "rgba(255, 255, 255, 0.7)";
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.arc(STAGE_PX / 2, STAGE_PX / 2, STAGE_PX / 2 - 0.5, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
  }, [image, scale, offset]);

  const apply = () => {
    if (!image) return;
    const out = document.createElement("canvas");
    out.width = EXPORT_PX;
    out.height = EXPORT_PX;
    const ctx = out.getContext("2d");
    if (!ctx) return;

    // Same geometry as the preview, scaled from the stage up to the export
    // size — so what the admin lined up is exactly what gets saved.
    const ratio = EXPORT_PX / STAGE_PX;
    const w = image.width * scale * ratio;
    const h = image.height * scale * ratio;
    ctx.drawImage(
      image,
      (EXPORT_PX - w) / 2 + offset.x * ratio,
      (EXPORT_PX - h) / 2 + offset.y * ratio,
      w,
      h,
    );

    // JPEG, not PNG: a photograph at quality 0.9 is several times smaller and
    // the circle is fully opaque, so there is no transparency to preserve.
    onCropped(out.toDataURL("image/jpeg", 0.9));
  };

  return (
    <>
      <div className="drawer-backdrop" onClick={onCancel} />
      <div className="drawer" style={{ width: 400 }}>
        <div className="drawer__head">
          <h2 style={{ fontSize: 17 }}>Position the photo</h2>
        </div>
        <div className="drawer__body">
          {error ? (
            <p style={{ color: "var(--critical, #b3261e)" }}>{error}</p>
          ) : (
            <>
              <p style={{ fontSize: 13, color: "var(--text-secondary)", marginTop: 0 }}>
                The app shows this in a circle. Drag to move, use the slider to zoom — anything
                dimmed is cropped away.
              </p>
              <canvas
                ref={canvasRef}
                width={STAGE_PX}
                height={STAGE_PX}
                style={{
                  width: STAGE_PX,
                  height: STAGE_PX,
                  borderRadius: 8,
                  background: "var(--surface-alt)",
                  cursor: dragging.current ? "grabbing" : "grab",
                  touchAction: "none",
                }}
                onPointerDown={(e) => {
                  dragging.current = { x: e.clientX - offset.x, y: e.clientY - offset.y };
                  e.currentTarget.setPointerCapture(e.pointerId);
                }}
                onPointerMove={(e) => {
                  if (!dragging.current) return;
                  setOffset(
                    clamp({ x: e.clientX - dragging.current.x, y: e.clientY - dragging.current.y }, scale),
                  );
                }}
                onPointerUp={() => {
                  dragging.current = null;
                }}
              />
              <div className="field" style={{ marginTop: 14 }}>
                <label>Zoom</label>
                <input
                  type="range"
                  min={1}
                  max={4}
                  step={0.01}
                  value={zoom}
                  onChange={(e) => {
                    const next = Number(e.target.value);
                    setZoom(next);
                    setOffset((o) => clamp(o, baseScale * next));
                  }}
                />
              </div>
              <div style={{ fontSize: 12, color: "var(--text-tertiary)", marginBottom: 12 }}>
                Saved at {EXPORT_PX}×{EXPORT_PX} — 4× the app's {APP_PORTRAIT_LOGICAL_PX}px circle, so
                it stays sharp on high-density screens.
              </div>
              <div style={{ display: "flex", gap: 10 }}>
                <button className="btn btn--primary" onClick={apply} disabled={!image}>
                  Use this crop
                </button>
                <button className="btn" onClick={onCancel}>
                  Cancel
                </button>
              </div>
            </>
          )}
        </div>
      </div>
    </>
  );
}
