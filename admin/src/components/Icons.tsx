import type { SVGProps } from "react";

/* Minimal, consistent line icons — 1.6px stroke, rounded caps, 20x20 grid.
   Hand-drawn rather than pulled from an icon-pack, so the whole set reads
   as one deliberate family instead of an assorted grab-bag. */
const base = {
  width: 20,
  height: 20,
  viewBox: "0 0 20 20",
  fill: "none",
  stroke: "currentColor",
  strokeWidth: 1.6,
  strokeLinecap: "round" as const,
  strokeLinejoin: "round" as const,
};

export const IconDashboard = (p: SVGProps<SVGSVGElement>) => (
  <svg {...base} {...p}>
    <rect x="2.5" y="2.5" width="6.5" height="6.5" rx="1.4" />
    <rect x="11" y="2.5" width="6.5" height="9.5" rx="1.4" />
    <rect x="2.5" y="11.5" width="6.5" height="6" rx="1.4" />
    <rect x="11" y="14.5" width="6.5" height="3" rx="1.2" />
  </svg>
);

export const IconChat = (p: SVGProps<SVGSVGElement>) => (
  <svg {...base} {...p}>
    <path d="M3 4.5h14a1 1 0 0 1 1 1V13a1 1 0 0 1-1 1H8l-4 3.2V14H3a1 1 0 0 1-1-1V5.5a1 1 0 0 1 1-1Z" />
    <path d="M6.5 8h7M6.5 10.8h4.5" />
  </svg>
);

export const IconCalendar = (p: SVGProps<SVGSVGElement>) => (
  <svg {...base} {...p}>
    <rect x="2.5" y="4" width="15" height="13.5" rx="1.6" />
    <path d="M2.5 8h15M6.5 2v4M13.5 2v4" />
  </svg>
);

export const IconUsers = (p: SVGProps<SVGSVGElement>) => (
  <svg {...base} {...p}>
    <circle cx="7.2" cy="7" r="2.8" />
    <path d="M2 17c0-3 2.3-5 5.2-5s5.2 2 5.2 5" />
    <circle cx="14.6" cy="6.4" r="2.1" />
    <path d="M13 12.3c2.4.1 4.3 1.9 4.3 4.7" />
  </svg>
);

export const IconLeaf = (p: SVGProps<SVGSVGElement>) => (
  <svg {...base} {...p}>
    <path d="M4 16C2.5 9 7 3 17 3c1 8-4.5 13.5-13 13Z" />
    <path d="M4.5 15.5 11 9" />
  </svg>
);

export const IconTag = (p: SVGProps<SVGSVGElement>) => (
  <svg {...base} {...p}>
    <path d="M10.5 2.5H16a1 1 0 0 1 1 1v5.5a1.5 1.5 0 0 1-.44 1.06l-7 7a1.5 1.5 0 0 1-2.12 0l-5.5-5.5a1.5 1.5 0 0 1 0-2.12l7-7a1.5 1.5 0 0 1 1.06-.44Z" />
    <circle cx="13.2" cy="6.8" r="1.15" fill="currentColor" stroke="none" />
  </svg>
);

export const IconClose = (p: SVGProps<SVGSVGElement>) => (
  <svg {...base} width={18} height={18} {...p}>
    <path d="M5 5l10 10M15 5 5 15" />
  </svg>
);

export const IconSpark = (p: SVGProps<SVGSVGElement>) => (
  <svg {...base} width={16} height={16} {...p}>
    <path d="M9 2.5l1.3 4.2L14.5 8l-4.2 1.3L9 13.5l-1.3-4.2L3.5 8l4.2-1.3L9 2.5Z" fill="currentColor" stroke="none" />
  </svg>
);

export const IconSend = (p: SVGProps<SVGSVGElement>) => (
  <svg {...base} width={16} height={16} {...p}>
    <path d="M17 3 2.5 9l5.7 2.1L10 17l7-14Z" />
    <path d="M8.2 11.1 17 3" />
  </svg>
);

export const IconArrowLeft = (p: SVGProps<SVGSVGElement>) => (
  <svg {...base} width={16} height={16} {...p}>
    <path d="M12.5 4 6 10l6.5 6" />
  </svg>
);

export const IconChevronRight = (p: SVGProps<SVGSVGElement>) => (
  <svg {...base} width={15} height={15} {...p}>
    <path d="M7.5 4 13 10l-5.5 6" />
  </svg>
);

export const IconChevronDown = (p: SVGProps<SVGSVGElement>) => (
  <svg {...base} width={15} height={15} {...p}>
    <path d="M4 7.5 10 13l6-5.5" />
  </svg>
);

export const IconEye = (p: SVGProps<SVGSVGElement>) => (
  <svg {...base} width={18} height={18} {...p}>
    <path d="M1.5 10S4.5 4 10 4s8.5 6 8.5 6-3 6-8.5 6-8.5-6-8.5-6Z" />
    <circle cx="10" cy="10" r="2.4" />
  </svg>
);

export const IconEyeOff = (p: SVGProps<SVGSVGElement>) => (
  <svg {...base} width={18} height={18} {...p}>
    <path d="M2.5 2.5l15 15" />
    <path d="M8.3 4.3C8.85 4.1 9.42 4 10 4c5.5 0 8.5 6 8.5 6a15 15 0 0 1-2.6 3.4M5.6 5.6C3.2 7.1 1.5 10 1.5 10s3 6 8.5 6c1.02 0 1.96-.2 2.8-.55" />
    <path d="M7.9 8c-.25.34-.4.76-.4 1.2a2.4 2.4 0 0 0 2.4 2.4c.5 0 .96-.16 1.32-.44" />
  </svg>
);
