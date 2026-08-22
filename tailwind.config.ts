import type { Config } from "tailwindcss";

export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        bg: "#F4F6F8",
        surface: "#FFFFFF",
        sidebar: { DEFAULT: "#111827", hover: "#1F2937" },
        brand: { DEFAULT: "#0F4C5C", light: "#15616F" },
        accent: "#2563EB",
        success: { DEFAULT: "#16A34A", bg: "#ECFDF3" },
        warning: { DEFAULT: "#D97706", bg: "#FFFAEB" },
        critical: { DEFAULT: "#DC2626", bg: "#FEF2F2" },
        text: { primary: "#111827", secondary: "#6B7280" },
        border: { DEFAULT: "#E5E7EB" },
      },
      fontFamily: {
        sans: ["Inter", "-apple-system", "BlinkMacSystemFont", "Segoe UI", "sans-serif"],
        mono: ["IBM Plex Mono", "ui-monospace", "monospace"],
      },
      fontSize: { "2xs": ["0.6875rem", { lineHeight: "1rem" }] },
      borderRadius: { DEFAULT: "6px", sm: "4px", md: "6px", lg: "8px" },
      boxShadow: {
        subtle: "0 1px 2px 0 rgba(17, 24, 39, 0.05)",
        card: "0 1px 3px 0 rgba(17, 24, 39, 0.08)",
        panel: "0 4px 12px 0 rgba(17, 24, 39, 0.10)",
      },
      spacing: { 18: "4.5rem", 60: "15rem" },
    },
  },
  plugins: [],
} satisfies Config;
